# Clear Throw View

A Fallout 4 mod: while you hold the throw key, your weapon is lowered, so it doesn't cover the grenade
trajectory - you see exactly where the grenade or mine will land. On release you see the throw as usual and
the weapon comes back up. A short press still bashes as usual.

Русское описание и сборка - [README.ru.md](README.ru.md).

## How it works

- The throw key is the game's **Melee** control (Alt by default, RB on a gamepad): a short press bashes,
  holding it longer than `fThrowDelay` (0.3 s) throws. When the press becomes a throw, the mod puts the weapon
  into the vanilla "gun down" pose (`PlayIdleAction(ActionGunDown)`, the pose used near walls or when aiming at
  a friendly). The throw animation only starts on release and brings the weapon back up.
- In the vanilla pose the weapon still covers the landing point, so the mod ships its own gun-down clips
  (`WPNIdleGunDown.hkx`, `WPNRunGunDown.hkx`; all weapon types, normal body and power armor, base game and
  DLC - 120 clips). `tools/gen_anims.py` takes them from the game archives and lowers the `COM` bone by 25
  units (the arms and the weapon hang from it, the camera doesn't); nothing else in the clips changes. Side
  effect: when the game lowers the weapon on its own, it goes lower too.
- Melee weapons have no gun-down pose; the mod leaves them alone - in the vanilla throw they are pulled back
  and don't cover the trajectory.
- Only when a grenade or mine is equipped and the weapon is drawn.
- **Separate throw and bash keys** (optional): `fThrowDelay` is set to 0 in memory (not in your ini), so the
  throw key throws even on a short press, and bash moves to a key of your choice (`ActionMelee`).
- History: 1.0 holstered the weapon (the game cancelled throws released during the holster animation); 1.1
  hid the hands while aiming (worked, but looked like an animation glitch).

## Requirements

- Fallout 4 Script Extender (F4SE), with its scripts
- Mod Configuration Menu (MCM)
- Garden of Eden Papyrus Script Extender

Tested on game version 1.10.163 (pre-Next-Gen).

## Settings (MCM - Clear Throw View)

Lower the weapon while aiming a throw; separate throw and bash keys and the bash key; log (`Data\ClearThrowView\ClearThrowView.log`).

## Building

See [README.ru.md](README.ru.md#сборка). Everything is generated: `tools/gen_esp.py` (the ESP),
`tools/gen_mcm.py` (MCM config and translations), `tools/gen_anims.py` (the gun-down clips, from the game
archives; `tools/hkx.py` and `tools/hkanim.py` read and patch Havok 2014 packfiles and spline / lossless
animations), PapyrusCompiler (the script), `tools/deploy.py` (into the
game), `tools/gen_cover.py` (Nexus images from two screenshots).

## License

The Unlicense - public domain. Made with Claude Code.
