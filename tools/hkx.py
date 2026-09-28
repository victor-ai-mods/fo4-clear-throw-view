"""
Havok packfile (hk_2014.1.0-r1, 64-bit, little endian) — чтение и перезапись.

Файл: заголовок 64 байта (+ padding предикатов), затем заголовки секций по 64 байта:
    tag[20], absoluteDataStart, localFixupsOffset, globalFixupsOffset, virtualFixupsOffset,
    exportsOffset, importsOffset, endOffset (все смещения — от absoluteDataStart), 16 байт padding.
Секции: __classnames__ (подпись u32, 0x09, имя\\0 …), __types__ (пустая), __data__.
Фиксапы __data__:
    local   (src, dst)                — указатель внутри секции: по src лежит адрес dst
    global  (src, dstSection, dst)    — указатель в другую секцию (в клипах — тоже в __data__)
    virtual (src, classSection, nameOffset) — по src начинается объект класса с этим именем
Списки фиксапов завершаются 0xFF-заполнением до кратности 16.

Перезапись — «вклейкой»: заменить диапазон байт __data__ другими байтами (другой длины) и
сдвинуть все смещения за ним. Объекты и буферы массивов лежат в секции подряд, поэтому
этого достаточно, если длина вклейки кратна 16 (буферы выровнены по 16).
"""

import struct


class Packfile:
    def __init__(self, raw):
        self.raw = bytearray(raw)
        self.nsec, = struct.unpack_from('<i', raw, 20)
        pad, = struct.unpack_from('<h', raw, 62)
        self.sec_hdr_start = 64 + pad
        self.sections = {}
        for i in range(self.nsec):
            off = self.sec_hdr_start + 64 * i
            tag = raw[off:off + 19].split(b'\0')[0].decode()
            vals = list(struct.unpack_from('<7i', raw, off + 20))
            self.sections[tag] = (i, off, vals)
        ds, lf, gf, vf, ex, im, end = self.sections['__data__'][2]
        self.data_start = ds
        self.data = bytearray(raw[ds:ds + lf])          # сами объекты — до таблицы фиксапов
        self.local = self._pairs(raw[ds + lf:ds + gf], 2)
        self.glob = self._pairs(raw[ds + gf:ds + vf], 3)
        self.virt = self._pairs(raw[ds + vf:ds + ex], 3)
        cs = self.sections['__classnames__'][2][0]
        self.classnames = {}
        for s, sec, name_off in self.virt:
            self.classnames[s] = raw[cs + name_off:].split(b'\0')[0].decode()

    @staticmethod
    def _pairs(buf, n):
        out = []
        step = 4 * n
        for p in range(0, len(buf) - step + 1, step):
            v = struct.unpack_from('<%di' % n, buf, p)
            if v[0] == -1:
                continue
            out.append(list(v))
        return out

    # --- чтение ---
    def objects(self, cls=None):
        return [(s, c) for s, c in sorted(self.classnames.items()) if cls is None or c == cls]

    def ptr(self, src):
        """Куда указывает указатель по смещению src (или None)."""
        for s, d in self.local:
            if s == src:
                return d
        for s, sec, d in self.glob:
            if s == src:
                return d
        return None

    def array(self, off):
        """hkArray по смещению off: (адрес буфера, size)."""
        size, = struct.unpack_from('<i', self.data, off + 8)
        return self.ptr(off), size

    def cstring(self, off):
        return bytes(self.data[off:self.data.index(b'\0', off)]).decode('latin1')

    def string_ptr(self, off):
        p = self.ptr(off)
        return None if p is None else self.cstring(p)

    # --- вклейка ---
    def splice(self, start, end, new_bytes):
        """Заменить data[start:end] на new_bytes; смещения > start (и == end) сдвигаются."""
        delta = len(new_bytes) - (end - start)
        assert delta % 16 == 0, 'длина вклейки должна сохранять выравнивание 16'

        def fix(o):
            return o + delta if o >= end else o

        for lst in (self.local,):
            for e in lst:
                e[0] = fix(e[0]); e[1] = fix(e[1])
        for e in self.glob:
            e[0] = fix(e[0]); e[2] = fix(e[2])
        for e in self.virt:
            e[0] = fix(e[0])
        self.classnames = {fix(s): c for s, c in self.classnames.items()}
        self.data[start:end] = new_bytes
        return delta

    def set_array_size(self, off, size):
        struct.pack_into('<i', self.data, off + 8, size)
        struct.pack_into('<I', self.data, off + 12, size | 0x80000000)

    # --- запись ---
    @staticmethod
    def _table(rows, n):
        b = bytearray()
        for r in rows:
            b += struct.pack('<%di' % n, *r)
        while len(b) % 16:
            b += b'\xff'
        return b

    def build(self):
        raw = self.raw
        ds = self.data_start
        idx, hoff, vals = self.sections['__data__']
        loc = self._table(self.local, 2)
        glo = self._table(self.glob, 3)
        vir = self._table(self.virt, 3)
        lf = len(self.data)
        gf = lf + len(loc)
        vf = gf + len(glo)
        ex = vf + len(vir)
        body = bytes(self.data) + loc + glo + vir
        old_end = vals[6]
        out = bytearray(raw[:ds]) + body + raw[ds + old_end:]
        struct.pack_into('<7i', out, hoff + 20, ds, lf, gf, vf, ex, ex, ex)
        # секции после __data__ (в клипах их нет, но на всякий случай) — сдвинуть
        shift = len(body) - old_end
        for tag, (i, off, v) in self.sections.items():
            if v[0] > ds:
                struct.pack_into('<i', out, off + 20, v[0] + shift)
        return bytes(out)
