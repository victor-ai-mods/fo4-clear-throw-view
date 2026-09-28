"""
Клипы Havok 2014 (Fallout 4): распаковка и сдвиг позиции кости прямо в данных.

Поддержаны два формата, в которых лежат клипы рук от первого лица:

hkaSplineCompressedAnimation (64-bit): hkaAnimation (0x38 байт: vtable, refcount, type, duration,
numberOfTransformTracks, numberOfFloatTracks, extractedMotion, annotationTracks), затем
    0x38 numFrames, 0x3C numBlocks, 0x40 maxFramesPerBlock, 0x44 maskAndQuantizationSize,
    0x48 blockDuration, 0x4C blockInverseDuration, 0x50 frameDuration,
    0x58 blockOffsets[], 0x68 floatBlockOffsets[], 0x78 transformOffsets[], 0x88 floatOffsets[],
    0x98 data[] (u8), 0xA8 endian.
  Блок: маски (4 байта на трек: quantization, position, rotation, scale), затем данные треков
  подряд. Байт квантования: биты 0–1 — позиция (0 = 8 бит, 1 = 16 бит), 2–5 — поворот,
  6–7 — масштаб. Байт позиции/масштаба: биты 0–2 — ось X/Y/Z статична, 4–6 — ось сплайном.
  Байт поворота: биты 0–3 — статичен, 4–7 — сплайн. Сплайн: numItems (u16), degree (u8), узлы
  (numItems + degree + 2 байта), выравнивание, для каждой оси сплайна min/max (float) или
  значение статичной оси, затем numItems + 1 контрольных точек (квантованные 8/16 бит).
  Проверено на 79 ванильных клипах: разбор блока кончается ровно на floatBlockOffsets,
  смещения костей совпадают с эталонной позой скелета.

hkaLosslessCompressedAnimation (64-bit): после hkaAnimation
    0x38 dynamicTranslations[] (float, кадр за кадром), 0x48 staticTranslations[] (float),
    0x58 коды смещений (4 x i16 на трек: x, y, z, 0), 0x68 dynamicRotations[] (16 байт),
    0x78 staticRotations[] (16 байт), 0x88 коды поворотов (i16 на трек), 0x98 / 0xA8 масштаб
    dynamic / static, 0xB8 коды масштаба (4 x i16), 0xD8 numFrames.
  Код: биты 0–1 — тип (0 — значение по умолчанию, 1 — статичное, 2 — динамическое), остальные —
  индекс. Динамическое значение кадра f: dynamic[f * (len(dynamic) / numFrames) + индекс].
"""

import math
import struct

from hkx import Packfile

ROT_SIZE = {0: 4, 1: 5, 2: 6, 3: 3, 4: 2, 5: 16}   # POLAR32, THREECOMP40, THREECOMP48, THREECOMP24, STRAIGHT16, UNCOMPRESSED
ROT_ALIGN = {0: 4, 1: 1, 2: 2, 3: 1, 4: 2, 5: 4}
IDENTITY = (0.0, 0.0, 0.0, 1.0)

SPLINE = 'hkaSplineCompressedAnimation'
LOSSLESS = 'hkaLosslessCompressedAnimation'


def align(pos, a):
    return (pos + a - 1) // a * a


# --- кватернионы (для проверок распаковки) ---

def _insert_w(vals, shift, invert):
    x, y, z = vals
    w = math.sqrt(max(0.0, 1.0 - x * x - y * y - z * z))
    if invert:
        w = -w
    q = [x, y, z]
    q.insert(shift, w)
    return tuple(q)


def read_quat(buf, pos, qtype):
    if qtype == 2:          # THREECOMP48
        s0, s1, s2 = struct.unpack_from('<3H', buf, pos)
        frac = 0.000043161
        vals = [((s & 0x7FFF) - 16383) * frac for s in (s0, s1, s2)]
        shift = ((s1 >> 14) & 2) | ((s0 >> 15) & 1)
        return _insert_w(vals, shift, (s2 >> 15) & 1)
    if qtype == 1:          # THREECOMP40
        v = int.from_bytes(buf[pos:pos + 5], 'little')
        frac = 0.000345436
        vals = [(((v >> (12 * i)) & 0xFFF) - 2047) * frac for i in range(3)]
        return _insert_w(vals, (v >> 36) & 3, (v >> 38) & 1)
    if qtype == 5:
        return struct.unpack_from('<4f', buf, pos)
    raise NotImplementedError('квантование поворота %d' % qtype)


# --- B-сплайн ---

def _find_span(n, p, u, knots):
    if u >= knots[n + 1]:
        return n
    low, high = p, n + 1
    mid = (low + high) // 2
    while u < knots[mid] or u >= knots[mid + 1]:
        if u < knots[mid]:
            high = mid
        else:
            low = mid
        mid = (low + high) // 2
    return mid


def eval_spline(u, degree, knots, ctrl):
    """Алгоритм де Бура; ctrl — список кортежей."""
    n = len(ctrl) - 1
    p = degree
    k = _find_span(n, p, u, knots)
    d = [list(ctrl[j + k - p]) for j in range(p + 1)]
    for r in range(1, p + 1):
        for j in range(p, r - 1, -1):
            i = j + k - p
            den = knots[i + p - r + 1] - knots[i]
            a = 0.0 if den == 0 else (u - knots[i]) / den
            d[j] = [(1 - a) * x0 + a * x1 for x0, x1 in zip(d[j - 1], d[j])]
    return tuple(d[p])


# --- сплайн: разбор блока ---

def _read_vec(buf, pos, types, qbits, default):
    """Позиция/масштаб: (pos, f(кадр) -> (x, y, z), info). info['offs'][ось] — где лежат числа оси:
    ('s', lo, hi) для сплайна, ('c', off) для статичной, None — значение по умолчанию."""
    static = [(types >> i) & 1 for i in range(3)]
    spline = [(types >> (4 + i)) & 1 for i in range(3)]
    offs = [None, None, None]
    if any(spline):
        n_items, degree = struct.unpack_from('<HB', buf, pos)
        pos += 3
        knots = list(buf[pos:pos + n_items + degree + 2])
        pos = align(pos + n_items + degree + 2, 4)
        ranges = []
        for i in range(3):
            if spline[i]:
                lo, hi = struct.unpack_from('<2f', buf, pos)
                offs[i] = ('s', pos, pos + 4)
                pos += 8
                ranges.append(('s', lo, hi))
            elif static[i]:
                v, = struct.unpack_from('<f', buf, pos)
                offs[i] = ('c', pos)
                pos += 4
                ranges.append(('c', v))
            else:
                ranges.append(('c', default))
        size, maxv = (1, 255.0) if qbits == 0 else (2, 65535.0)
        ctrl = []
        for _ in range(n_items + 1):
            pt = []
            for r in ranges:
                if r[0] == 's':
                    q = buf[pos] if size == 1 else struct.unpack_from('<H', buf, pos)[0]
                    pos += size
                    pt.append(r[1] + (r[2] - r[1]) * q / maxv)
                else:
                    pt.append(r[1])
            ctrl.append(tuple(pt))
        pos = align(pos, 4)
        return pos, (lambda f: eval_spline(f, degree, knots, ctrl)), dict(kind='spline', offs=offs)
    vals = []
    for i in range(3):
        if static[i]:
            v, = struct.unpack_from('<f', buf, pos)
            offs[i] = ('c', pos)
            pos += 4
            vals.append(v)
        else:
            vals.append(default)
    vals = tuple(vals)
    return pos, (lambda f: vals), dict(kind='static', offs=offs)


def _read_rot(buf, pos, types, qtype):
    if types & 0xF0:
        n_items, degree = struct.unpack_from('<HB', buf, pos)
        pos += 3
        knots = list(buf[pos:pos + n_items + degree + 2])
        pos = align(pos + n_items + degree + 2, ROT_ALIGN[qtype])
        ctrl = []
        for _ in range(n_items + 1):
            ctrl.append(read_quat(buf, pos, qtype))
            pos += ROT_SIZE[qtype]
        pos = align(pos, 4)

        def ev(f):
            q = eval_spline(f, degree, knots, ctrl)
            n = math.sqrt(sum(c * c for c in q)) or 1.0
            return tuple(c / n for c in q)
        return pos, ev
    if types & 0x0F:
        pos = align(pos, ROT_ALIGN[qtype])
        q = read_quat(buf, pos, qtype)
        pos = align(pos + ROT_SIZE[qtype], 4)
        return pos, (lambda f: q)
    return pos, (lambda f: IDENTITY)


class SplineAnim:
    def __init__(self, pf, off):
        d = pf.data
        self.pf, self.off = pf, off
        self.n_tracks, = struct.unpack_from('<i', d, off + 24)
        self.n_frames, self.n_blocks, self.max_fpb, self.mask_size = struct.unpack_from('<4i', d, off + 0x38)
        bo, n = pf.array(off + 0x58)
        self.block_offsets = struct.unpack_from('<%dI' % n, d, bo)
        fo, n = pf.array(off + 0x68)
        self.float_block_offsets = struct.unpack_from('<%dI' % n, d, fo)
        self.data_buf, _ = pf.array(off + 0x98)
        self.blocks = [self._read_block(b) for b in range(self.n_blocks)]

    def _read_block(self, b):
        d = self.pf.data
        base = self.data_buf + self.block_offsets[b]
        pos = base + align(self.mask_size, 4)
        tracks = []
        for t in range(self.n_tracks):
            q, pt, rt, st = d[base + 4 * t:base + 4 * t + 4]
            pos, tr, ti = _read_vec(d, pos, pt, q & 3, 0.0)
            pos, rot = _read_rot(d, pos, rt, (q >> 2) & 0xF)
            pos, sc, _ = _read_vec(d, pos, st, (q >> 6) & 3, 1.0)
            tracks.append(dict(t=tr, r=rot, s=sc, ti=ti))
        # Разбор сошёлся, только если данные трансформаций кончились там, где начинаются float-треки.
        assert pos - base == self.float_block_offsets[b], ('блок %d: %d != %d' % (b, pos - base, self.float_block_offsets[b]))
        return tracks

    def translation(self, track, frame):
        b = min(frame // (self.max_fpb - 1), self.n_blocks - 1)
        return self.blocks[b][track]['t'](frame - b * (self.max_fpb - 1))

    def shift(self, track, axis, delta):
        """Сдвинуть ось позиции трека на delta во всех блоках. False — ось не хранится."""
        for blk in self.blocks:
            o = blk[track]['ti']['offs'][axis]
            if o is None:
                return False
        for blk in self.blocks:
            for p in blk[track]['ti']['offs'][axis][1:]:
                v, = struct.unpack_from('<f', self.pf.data, p)
                struct.pack_into('<f', self.pf.data, p, v + delta)
        return True


class LosslessAnim:
    def __init__(self, pf, off):
        d = pf.data
        self.pf, self.off = pf, off
        self.dyn, n_dyn = pf.array(off + 0x38)
        self.static, _ = pf.array(off + 0x48)
        codes_buf, n_codes = pf.array(off + 0x58)
        self.n_frames, = struct.unpack_from('<i', d, off + 0xD8)
        assert n_dyn % self.n_frames == 0, (n_dyn, self.n_frames)
        self.stride = n_dyn // self.n_frames
        self.codes = [struct.unpack_from('<3h', d, codes_buf + 8 * t) for t in range(n_codes)]

    def _value_offsets(self, track, axis):
        code = self.codes[track][axis]
        kind, idx = code & 3, code >> 2
        if kind == 2:
            return [self.dyn + 4 * (f * self.stride + idx) for f in range(self.n_frames)]
        if kind == 1:
            # Статичное значение может быть общим для нескольких осей — тогда сдвигать нельзя.
            users = sum(1 for c in self.codes for v in c if v & 3 == 1 and v >> 2 == idx)
            return [self.static + 4 * idx] if users == 1 else None
        return None

    def translation(self, track, frame):
        out = []
        for axis in range(3):
            code = self.codes[track][axis]
            kind, idx = code & 3, code >> 2
            if kind == 2:
                p = self.dyn + 4 * (frame * self.stride + idx)
            elif kind == 1:
                p = self.static + 4 * idx
            else:
                out.append(0.0)
                continue
            out.append(struct.unpack_from('<f', self.pf.data, p)[0])
        return tuple(out)

    def shift(self, track, axis, delta):
        offs = self._value_offsets(track, axis)
        if not offs:
            return False
        for p in offs:
            v, = struct.unpack_from('<f', self.pf.data, p)
            struct.pack_into('<f', self.pf.data, p, v + delta)
        return True


def open_clip(raw):
    """(Packfile, анимация, [трек -> кость]) или (Packfile, None, None) для неизвестного формата."""
    pf = Packfile(raw)
    objs = dict((c, s) for s, c in pf.objects())
    if SPLINE in objs:
        anim = SplineAnim(pf, objs[SPLINE])
    elif LOSSLESS in objs:
        anim = LosslessAnim(pf, objs[LOSSLESS])
    else:
        return pf, None, None
    tb, nt = pf.array(objs['hkaAnimationBinding'] + 32)
    return pf, anim, list(struct.unpack_from('<%dh' % nt, pf.data, tb))
