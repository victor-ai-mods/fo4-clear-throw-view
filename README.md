# Clear Throw View

A Fallout 4 mod: while you hold the throw key, your weapon is holstered, so neither the weapon nor your
hands hide the grenade trajectory - you see exactly where the grenade or mine will land. After the throw
the weapon is drawn again. A short press still bashes as usual.

Русское описание и сборка - [README.ru.md](README.ru.md).

## How it works

- The throw key is the game's **Melee** control (Alt by default, RB on a gamepad): a short press bashes,
  holding it longer than `fThrowDelay` (0.3 s) throws. The mod holsters the weapon when the press becomes a
  throw, so bashing is not affected. With the weapon holstered the game throws without drawing it again.
- Only when a grenade or mine is equipped. Rapid presses in a row are left to the game: the weapon is
  holstered only on the first press after a 1 s pause, otherwise holstering would interrupt the throws.
- If you release the key while the holster animation is still playing, the game cancels the throw; the mod
  notices that the grenade is still in your inventory and throws it (`ActionThrow`).
- **Separate throw and bash keys** (optional): `fThrowDelay` is set to 0 in memory (not in your ini), so the
  throw key throws even on a short press, and bash moves to a key of your choice (`ActionMelee`).

## Requirements

- Fallout 4 Script Extender (F4SE), with its scripts
- Mod Configuration Menu (MCM)
- Garden of Eden Papyrus Script Extender

Tested on game version 1.10.163 (pre-Next-Gen).

## Settings (MCM - Clear Throw View)

Holster the weapon when throwing; draw it after the throw and after how many seconds; separate throw and
bash keys and the bash key; log (`Data\ClearThrowView\ClearThrowView.log`).

## Building

See [README.ru.md](README.ru.md#сборка). Everything is generated: `tools/gen_esp.py` (the ESP),
`tools/gen_mcm.py` (MCM config and translations), PapyrusCompiler (the script), `tools/deploy.py` (into the
game), `tools/gen_cover.py` (Nexus images from two screenshots).

## License

The Unlicense - public domain. Made with Claude Code.
