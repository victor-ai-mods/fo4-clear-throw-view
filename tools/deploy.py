"""
Раскладка собранного мода по игре.

  python tools/deploy.py            — esp, .pex, файлы из mod/, клипы из build/anims в Data, включить плагин
  python tools/deploy.py --remove   — снять плагин и убрать файлы мода

`Plugins.txt` в этой установке живёт в ДВУХ местах (игра читает
`%LOCALAPPDATA%\\Fallout4\\Plugins.txt`) — правятся оба. Всё, что перезаписывается,
сначала уезжает в `<игра>\\Backup`.
"""

import argparse
import datetime
import os
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAME = os.environ.get('FO4_PATH', r'D:\Games\Fallout 4')
DATA = os.path.join(GAME, 'Data')
PLUGIN = 'ClearThrowView.esp'
SCRIPTS = ['ThrowQuest.pex']
MOD_FILES = os.path.join(ROOT, 'mod')           # пути внутри — как от Data

PLUGIN_LISTS = [
    os.path.join(os.environ['LOCALAPPDATA'], 'Fallout4', 'Plugins.txt'),
    os.path.join(GAME, 'fallout4', 'Plugins.txt'),
]


def backup(path):
    if not os.path.exists(path):
        return None
    stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
    target_dir = os.path.join(GAME, 'Backup')
    os.makedirs(target_dir, exist_ok=True)
    target = os.path.join(target_dir, '%s.%s.bak' % (os.path.basename(path), stamp))
    shutil.copy2(path, target)
    return target


def copy(src, dst):
    saved = backup(dst)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copy2(src, dst)
    print('  %s%s' % (dst, ('  (старый -> %s)' % os.path.basename(saved)) if saved else ''))


def set_enabled(enabled):
    for path in PLUGIN_LISTS:
        if not os.path.exists(path):
            print('  нет %s — пропущено' % path)
            continue
        with open(path, encoding='utf-8-sig') as f:
            lines = f.read().splitlines()
        kept = [ln for ln in lines if ln.lstrip('*').strip().lower() != PLUGIN.lower()]
        if enabled:
            kept.append('*' + PLUGIN)
        if kept != lines:
            backup(path)
            with open(path, 'w', encoding='utf-8', newline='\n') as f:
                f.write('\n'.join(kept) + '\n')
        print('  %s: %s' % (path, 'включён' if enabled else 'выключен'))


def mod_files():
    out = []
    for base, _, names in os.walk(MOD_FILES):
        for name in names:
            out.append(os.path.relpath(os.path.join(base, name), MOD_FILES))
    return sorted(out)


def anim_files():
    """Клипы из tools/gen_anims.py (build/anims.txt — пути от Data)."""
    listing = os.path.join(ROOT, 'build', 'anims.txt')
    if not os.path.exists(listing):
        return []
    with open(listing, encoding='utf-8') as f:
        return [ln.strip() for ln in f if ln.strip()]


def script_paths():
    return [(os.path.join(ROOT, 'build', 'scripts', 'CTV', n),
             os.path.join(DATA, 'Scripts', 'CTV', n)) for n in SCRIPTS]


def install():
    print('Файлы:')
    copy(os.path.join(ROOT, 'build', PLUGIN), os.path.join(DATA, PLUGIN))
    for src, dst in script_paths():
        copy(src, dst)
    for rel in mod_files():
        copy(os.path.join(MOD_FILES, rel), os.path.join(DATA, rel))
    # Клипы — без резервных копий: их 120, и они пересобираются из архивов игры.
    anims = anim_files()
    for rel in anims:
        dst = os.path.join(DATA, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copyfile(os.path.join(ROOT, 'build', 'anims', rel), dst)
    print('  клипов позы gun down: %d (Data/Meshes/Actors/...)' % len(anims))
    print('Порядок загрузки:')
    set_enabled(True)


def remove():
    print('Порядок загрузки:')
    set_enabled(False)
    print('Файлы:')
    paths = ([os.path.join(DATA, PLUGIN)] + [dst for _, dst in script_paths()] +
             [os.path.join(DATA, rel) for rel in mod_files()])
    for path in paths:
        if os.path.exists(path):
            backup(path)
            os.remove(path)
            print('  удалён %s' % path)
    removed = 0
    for rel in anim_files():
        path = os.path.join(DATA, rel)
        if os.path.exists(path):
            os.remove(path)
            removed += 1
    print('  удалено клипов: %d' % removed)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--remove', action='store_true')
    args = ap.parse_args()
    if args.remove:
        remove()
    else:
        install()
        print('\nesp и .pex подхватываются только при запуске игры.')


if __name__ == '__main__':
    main()
