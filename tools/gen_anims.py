"""
Генератор клипов позы «оружие опущено» (gun down), опущенной ниже ванильной.

Мод на время удержания броска включает ванильную позу gun down (ActionGunDown). В ней оружие
прижато к груди, но всё ещё закрывает точку падения гранаты. Здесь в клипах этой позы
(WPNIdleGunDown.hkx — стоя, WPNRunGunDown.hkx — в движении; от первого лица, для обычного
тела и силовой брони, из игры и DLC) кость COM опускается на DROP единиц по оси Z корня. На
COM висят корпус, руки и оружие, а камера (Camera) — отдельная кость от Root, поэтому руки с
оружием уходят вниз относительно взгляда. Меняются только числа высоты COM — длина файлов
та же, всё остальное в клипах байт в байт ванильное.

Клипы берутся из архивов игры (в репозитории их нет — это файлы Bethesda).

    python tools/gen_anims.py [--drop 25]

Выход: build/anims/Meshes/... (пути как в Data) и build/anims.txt (список путей).
"""

import argparse
import os
import re
import struct
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from hkanim import open_clip

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAME = os.environ.get('FO4_PATH', r'D:\Games\Fallout 4')
ARCHIVES = ['Fallout4 - Animations.ba2', 'DLCRobot - Main.ba2', 'DLCCoast - Main.ba2', 'DLCNukaWorld - Main.ba2']
# У DLC силовой брони папка — "1stPerson" без подчёркивания.
PATTERN = re.compile(r'1stPerson\\.*\\WPN(Idle|Run)GunDown\.hkx$', re.I)
BONE_COM = 1          # индекс COM в скелетах 1-го лица (обычном и силовой брони): Root, COM, Pelvis…
AXIS_UP = 2
DEFAULT_DROP = 25.0   # подобрано в игре 2026-09-28: траектория видна целиком и стоя, и на ходу


def ba2_clips(path):
    with open(path, 'rb') as f:
        magic, ver, typ, n, nameoff = struct.unpack('<4sI4sIQ', f.read(24))
        assert typ == b'GNRL', typ
        recs = [struct.unpack('<I4sIIQIII', f.read(36)) for _ in range(n)]
        f.seek(nameoff)
        names = []
        for _ in range(n):
            ln, = struct.unpack('<H', f.read(2))
            names.append(f.read(ln).decode('latin1'))
        for name, r in zip(names, recs):
            if PATTERN.search(name):
                f.seek(r[4])
                data = f.read(r[5] or r[6])
                yield name, zlib.decompress(data) if r[5] else data


def lower(raw, drop):
    pf, anim, track_to_bone = open_clip(raw)
    if anim is None:
        raise ValueError('неизвестный формат клипа')
    track = track_to_bone.index(BONE_COM)
    last = anim.n_frames - 1
    before = [anim.translation(track, f)[AXIS_UP] for f in (0, last)]
    if not anim.shift(track, AXIS_UP, -drop):
        raise ValueError('высота COM в клипе не хранится')
    out = pf.build()
    _, check, _ = open_clip(out)
    after = [check.translation(track, f)[AXIS_UP] for f in (0, last)]
    assert all(abs(a - (b - drop)) < 0.05 for a, b in zip(after, before)), (before, after)
    assert len(out) == len(raw)
    return out, '%s, COM z %.2f -> %.2f' % (type(anim).__name__, before[0], after[0])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--drop', type=float, default=DEFAULT_DROP)
    args = ap.parse_args()
    out_dir = os.path.join(ROOT, 'build', 'anims')
    names = []
    for arc in ARCHIVES:
        path = os.path.join(GAME, 'Data', arc)
        if not os.path.exists(path):
            print('нет %s — пропущено' % arc)
            continue
        for name, raw in ba2_clips(path):
            out, note = lower(raw, args.drop)
            dst = os.path.join(out_dir, name)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            with open(dst, 'wb') as f:
                f.write(out)
            names.append(name)
            print('  %-95s %s' % (name, note))
    with open(os.path.join(ROOT, 'build', 'anims.txt'), 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(names) + '\n')
    print('%d клипов -> %s' % (len(names), os.path.relpath(out_dir, ROOT)))


if __name__ == '__main__':
    main()
