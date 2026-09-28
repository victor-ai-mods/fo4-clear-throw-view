# Clear Throw View

A Fallout 4 mod: while you hold the throw key, your hands and weapon are hidden, so they don't cover the
grenade trajectory - you see exactly where the grenade or mine will land. On release the hands come back and
you see the throw as usual. A short press still bashes as usual.

Русское описание и сборка - [README.ru.md](README.ru.md).

## How it works

- The throw key is the game's **Melee** control (Alt by default, RB on a gamepad): a short press bashes,
  holding it longer than `fThrowDelay` (0.3 s) throws. The mod hides the first-person hands and weapon
  (vanilla `Game.ShowFirstPersonGeometry`) when the press becomes a throw, so bashing is not affected, and
  shows them again on release - the throw animation only starts on release, so you see all of it.
- Only when a grenade or mine is equipped. The hands also come back when a menu opens, on game load and when
  the mod is turned off in MCM.
- **Separate throw and bash keys** (optional): `fThrowDelay` is set to 0 in memory (not in your ini), so the
  throw key throws even on a short press, and bash moves to a key of your choice (`ActionMelee`).
- Version 1.0 holstered the weapon instead; the game cancelled throws released during the holster animation.
  Hiding the hands has no such problems.

## Requirements

- Fallout 4 Script Extender (F4SE), with its scripts
- Mod Configuration Menu (MCM)
- Garden of Eden Papyrus Script Extender

Tested on game version 1.10.163 (pre-Next-Gen).

## Settings (MCM - Clear Throw View)

Hide hands while aiming a throw; separate throw and bash keys and the bash key; log (`Data\ClearThrowView\ClearThrowView.log`).

## Building

See [README.ru.md](README.ru.md#сборка). Everything is generated: `tools/gen_esp.py` (the ESP),
`tools/gen_mcm.py` (MCM config and translations), PapyrusCompiler (the script), `tools/deploy.py` (into the
game), `tools/gen_cover.py` (Nexus images from two screenshots).

## License

The Unlicense - public domain. Made with Claude Code.
