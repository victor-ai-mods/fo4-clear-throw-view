"""
Генератор MCM и переводов.

Выход (в mod/, откуда их раскладывает tools/deploy.py):
    MCM/Config/ClearThrowView/config.json    — страница, все тексты токенами $CTV_*
    MCM/Config/ClearThrowView/keybinds.json  — клавиша удара -> CTV:ThrowQuest.Bash
    MCM/Config/ClearThrowView/settings.ini   — значения по умолчанию
    Interface/Translations/ClearThrowView_{en,ru}.txt — UTF-16 LE с BOM, TAB, CRLF

Новый язык — ещё один словарь в STRINGS (и файл перевода появится сам).

    python tools/gen_mcm.py
"""

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'mod')
MOD = 'ClearThrowView'
QUEST = 'ClearThrowView.esp|800'
SCRIPT = 'CTV:ThrowQuest'

STRINGS = {
    'en': {
        'MOD_NAME': 'Clear Throw View',
        'ABOUT': 'While you hold the throw key, your weapon is holstered so that neither the weapon nor your hands '
                 'hide the grenade trajectory. After the throw the weapon is drawn again. '
                 'A short press still bashes as usual.',
        'SEC_MAIN': 'Throwing',
        'ENABLED': 'Holster the weapon when throwing',
        'ENABLED_HELP': 'Only when a grenade or mine is equipped. The weapon is holstered as soon as the press '
                        'becomes a throw, so a short press still bashes.',
        'REDRAW': 'Draw the weapon after the throw',
        'REDRAW_HELP': 'Draw the weapon again after the throw, if the mod holstered it.',
        'REDRAW_DELAY': 'Draw after, s',
        'REDRAW_DELAY_HELP': 'Time after releasing the throw key. Too short a delay can interrupt the throw animation.',
        'SEC_SPLIT': 'Separate throw and bash keys',
        'SPLIT': 'Throw key only throws',
        'SPLIT_HELP': 'The throw key throws at once, even on a short press, and does not bash. '
                      'Bash with the key below. Takes effect immediately.',
        'BASH_KEY': 'Bash key',
        'BASH_KEY_HELP': 'Bash (melee attack with the weapon). Meant for the separate keys mode, but works in any mode.',
        'SEC_DEBUG': 'Troubleshooting',
        'LOG': 'Log',
        'LOG_HELP': 'Write Data\\ClearThrowView\\ClearThrowView.log.',
    },
    'ru': {
        'MOD_NAME': 'Clear Throw View',
        'ABOUT': 'Пока удерживается клавиша броска, оружие убрано в кобуру, и ни оружие, ни руки не закрывают '
                 'траекторию гранаты. После броска оружие достаётся обратно. '
                 'Короткое нажатие, как и раньше, — удар прикладом.',
        'SEC_MAIN': 'Бросок',
        'ENABLED': 'Убирать оружие при броске',
        'ENABLED_HELP': 'Только если экипирована граната или мина. Оружие убирается, когда нажатие становится '
                        'броском, поэтому короткое нажатие — по-прежнему удар.',
        'REDRAW': 'Доставать оружие после броска',
        'REDRAW_HELP': 'После броска снова достать оружие, если его убрал мод.',
        'REDRAW_DELAY': 'Доставать через, с',
        'REDRAW_DELAY_HELP': 'Время после отпускания клавиши броска. Слишком короткая задержка может прервать анимацию броска.',
        'SEC_SPLIT': 'Раздельные клавиши броска и удара',
        'SPLIT': 'Клавиша броска только бросает',
        'SPLIT_HELP': 'Клавиша броска бросает сразу, даже при коротком нажатии, и не бьёт прикладом. '
                      'Удар — клавишей ниже. Применяется сразу.',
        'BASH_KEY': 'Клавиша удара',
        'BASH_KEY_HELP': 'Удар прикладом (атака оружием в ближнем бою). Нужна для раздельных клавиш, но работает в любом режиме.',
        'SEC_DEBUG': 'Диагностика',
        'LOG': 'Лог',
        'LOG_HELP': 'Писать Data\\ClearThrowView\\ClearThrowView.log.',
    },
}

HOTKEYS = [
    ('BashHotkey', 'BASH_KEY', 'Bash'),
]

SETTINGS = [
    ('bEnabled', 1),
    ('bRedraw', 1),
    ('bSplitKeys', 0),
    ('bLog', 0),
]
SETTINGS_FLOAT = [
    ('fRedrawDelay', 1.0),
]


def t(key):
    return '$CTV_' + key


def call(function):
    return {'type': 'CallFunction', 'form': QUEST, 'scriptName': SCRIPT,
            'function': function, 'params': []}


def switcher(setting, key):
    return {'id': setting + ':Main', 'type': 'switcher', 'text': t(key), 'help': t(key + '_HELP'),
            'valueOptions': {'sourceType': 'ModSettingBool'}}


def slider(setting, key, lo, hi, step):
    return {'id': setting + ':Main', 'type': 'slider', 'text': t(key), 'help': t(key + '_HELP'),
            'valueOptions': {'min': lo, 'max': hi, 'step': step, 'sourceType': 'ModSettingFloat'}}


def config():
    content = [
        {'type': 'text', 'text': t('ABOUT')},
        {'type': 'spacer'},
        {'type': 'section', 'text': t('SEC_MAIN')},
        switcher('bEnabled', 'ENABLED'),
        switcher('bRedraw', 'REDRAW'),
        slider('fRedrawDelay', 'REDRAW_DELAY', 0.1, 3.0, 0.1),
        {'type': 'spacer'},
        {'type': 'section', 'text': t('SEC_SPLIT')},
        switcher('bSplitKeys', 'SPLIT'),
    ]
    for hid, key, _ in HOTKEYS:
        content.append({'id': hid, 'type': 'hotkey', 'text': t(key), 'help': t(key + '_HELP')})
    content += [
        {'type': 'spacer'},
        {'type': 'section', 'text': t('SEC_DEBUG')},
        switcher('bLog', 'LOG'),
    ]
    return {
        'modName': MOD,
        'displayName': t('MOD_NAME'),
        'minMcmVersion': 2,
        'pluginRequirements': ['ClearThrowView.esp'],
        # Без pages: настройки видны сразу по клику на имя мода (как в Explosives Cycler).
        'content': content,
    }


def keybinds():
    return {'modName': MOD, 'keybinds': [
        {'id': hid, 'desc': t(key), 'action': call(function)} for hid, key, function in HOTKEYS]}


def write_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8', newline='\r\n') as f:
        json.dump(data, f, ensure_ascii=False, indent=4)
        f.write('\n')


def main():
    cfg_dir = os.path.join(OUT, 'MCM', 'Config', MOD)
    write_json(os.path.join(cfg_dir, 'config.json'), config())
    write_json(os.path.join(cfg_dir, 'keybinds.json'), keybinds())
    with open(os.path.join(cfg_dir, 'settings.ini'), 'w', encoding='ascii', newline='\r\n') as f:
        f.write('[Main]\n' + ''.join('%s=%d\n' % kv for kv in SETTINGS) +
                ''.join('%s=%.1f\n' % kv for kv in SETTINGS_FLOAT))

    keys = set(STRINGS['en'])
    tr_dir = os.path.join(OUT, 'Interface', 'Translations')
    os.makedirs(tr_dir, exist_ok=True)
    for lang, table in STRINGS.items():
        assert set(table) == keys, '%s: ключи не совпадают с en: %s' % (lang, keys ^ set(table))
        for k, v in table.items():
            assert '\t' not in v and '\n' not in v, (lang, k)
            if k.endswith('_HELP') and len(v) > 165:
                print('  ! %s %s: подсказка %d символов (> 165 — мелкий шрифт)' % (lang, k, len(v)))
        text = ''.join('%s\t%s\r\n' % (t(k), v) for k, v in table.items())
        with open(os.path.join(tr_dir, '%s_%s.txt' % (MOD, lang)), 'wb') as f:
            f.write(b'\xff\xfe' + text.encode('utf-16-le'))
    print('MCM: %s, переводы: %s' % (os.path.relpath(cfg_dir, ROOT), ', '.join(STRINGS)))


if __name__ == '__main__':
    main()
