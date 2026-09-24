"""
Генератор `ClearThrowView.esp`.

Единственный мастер — `Fallout4.esm`. ESL-флаг (ESPFE): файл остаётся .esp, но не
занимает слот из 254; условие — все свои FormID в диапазоне 0x800..0xFFF.

    QUST  CTV_Quest   — Start Game Enabled, скрипт CTV:ThrowQuest (вся логика);
                        0x800 зашит в MCM (keybinds.json: "ClearThrowView.esp|800")

Шаблон QUST.DNAM — тот же, что в Explosives Cycler / Survival AutoMedic.

    python tools/gen_esp.py [--out build/ClearThrowView.esp]
"""

import argparse
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from esp_writer import PROP_OBJECT, TES4_LIGHT, Record, Script, build_plugin, vmad, zstring

PLUGIN_NAME = 'ClearThrowView.esp'

FID_QUEST = 0x01000800
NEXT_OBJECT_ID = 0x00000801

AACT_SHEATH = 0x00046BAF        # ActionSheath (Fallout4.esm)
AACT_MELEE = 0x00004A59         # ActionMelee — удар прикладом
AACT_THROW = 0x00004E32         # ActionThrow — бросок гранаты (повтор сорвавшегося броска)

SCRIPT_QUEST = 'CTV:ThrowQuest'


def build_qust():
    r = Record(b'QUST', FID_QUEST, 'CTV_Quest')
    s = Script(SCRIPT_QUEST)
    s.prop('ActionSheath', PROP_OBJECT, AACT_SHEATH)
    s.prop('ActionMelee', PROP_OBJECT, AACT_MELEE)
    s.prop('ActionThrow', PROP_OBJECT, AACT_THROW)
    r.add(b'VMAD', vmad([s]))
    r.add(b'FULL', zstring('Clear Throw View'))
    # 0x0111 = Start Game Enabled | 0x10 | Run Once — как у AM_Quest / QuickAid.
    r.add(b'DNAM', struct.pack('<HBBII', 0x0111, 0, 0x5E, 0, 0))
    r.add(b'NEXT', b'')
    r.add(b'ANAM', struct.pack('<I', 0))            # алиасов нет
    return r


def check(path):
    from esm import Plugin
    plugin = Plugin(path)
    assert plugin.masters == ['Fallout4.esm'], 'мастера: %r' % (plugin.masters,)
    with open(path, 'rb') as f:
        assert f.read(12)[8:12] == (TES4_LIGHT).to_bytes(4, 'little'), 'нет ESL-флага'
    counts = {sig.decode(): sum(1 for _ in plugin.records(sig)) for sig in (b'QUST',)}
    assert counts == {'QUST': 1}, counts
    print('  проверка: мастер один, записи %s' % counts)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default=None)
    args = ap.parse_args()
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out_path = args.out or os.path.join(root, 'build', PLUGIN_NAME)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)

    groups = [
        (b'QUST', [build_qust()]),
    ]
    blob = build_plugin(['Fallout4.esm'], groups, NEXT_OBJECT_ID, flags=TES4_LIGHT)
    with open(out_path, 'wb') as f:
        f.write(blob)
    print('%s: %d байт' % (out_path, len(blob)))
    check(out_path)


if __name__ == '__main__':
    main()
