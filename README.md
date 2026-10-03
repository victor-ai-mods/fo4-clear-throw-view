# Clear Throw View

A Fallout 4 mod: while you hold the throw key, your weapon is holstered, so neither the weapon nor your
hands hide the grenade trajectory - you see exactly where the grenade or mine will land. After the throw
the weapon is drawn again. A short press still bashes as usual.

Nexus Mods: [Clear Throw View](https://www.nexusmods.com/fallout4/mods/109411). Русское описание и сборка -
[README.ru.md](README.ru.md).

> **Versions.** The main (recommended) version is **1.0.0** - the Nexus main file, code on branch
> [`1.x`](https://github.com/victor-ai-mods/fo4-clear-throw-view/tree/1.x). It is described below.
> **This branch (`main`, same as `2.x`) holds the experimental 2.0.0** - the Nexus optional file; see
> [Experimental 2.0.0](#experimental-200-this-branch) at the end.

## How it works (1.0.0)

- The throw key is the game's **Melee** control (Alt by default, RB on a gamepad): a short press bashes,
  holding it longer than `fThrowDelay` (0.3 s) throws. The mod holsters the weapon when the press becomes a
  throw, so bashing is not affected. With the weapon holstered the game throws without drawing it again.
- Only when a grenade or mine is equipped. Rapid presses in a row are left to the game: the weapon is
  holstered only on the first press after a 1 s pause, otherwise holstering would interrupt the throws.
- If you release the key while the holster animation is still playing, the game cancels the throw; the mod
  notices that the grenade is still in your inventory and throws it (`ActionThrow`).
- The weapon is drawn again a set time after the throw, if the mod holstered it.
- **Separate throw and bash keys** (optional): `fThrowDelay` is set to 0 in memory (not in your ini), so the
  throw key throws even on a short press, and bash moves to a key of your choice (`ActionMelee`).
- Known quirk: a press right after the previous throw ends sometimes makes the game draw the weapon instead
  of throwing (game behavior; press again).

## Requirements

- Fallout 4 Script Extender (F4SE), with its scripts
- Mod Configuration Menu (MCM)
- Garden of Eden Papyrus Script Extender

Tested on game version 1.10.163 (pre-Next-Gen); users report 1.0.0 also works on the Anniversary Edition
(1.11.x).

Not compatible with [Melee And Throw](https://www.nexusmods.com/fallout4/mods/63639): it unbinds the game's
Melee control, so this mod never sees the throw key. Use this mod's separate keys option instead.

## Settings (MCM - Clear Throw View)

Holster the weapon when throwing; draw it after the throw and after how many seconds; separate throw and
bash keys and the bash key; log (`Data\ClearThrowView\ClearThrowView.log`).

## Building 1.0.0

Check out branch `1.x` and see its README.ru.md. Everything is generated: `tools/gen_esp.py` (the ESP),
`tools/gen_mcm.py` (MCM config and translations), PapyrusCompiler (the script), `tools/deploy.py` (into the
game), `tools/gen_cover.py` (Nexus images from two screenshots).

## Experimental 2.0.0 (this branch)

Instead of holstering, 2.0.0 **lowers** the weapon: when the press becomes a throw, the mod puts it into the
vanilla "gun down" pose (`PlayIdleAction(ActionGunDown)`, the pose used near walls or when aiming at a
friendly). The throw animation only starts on release and brings the weapon back up, so nothing is
holstered or drawn and throws are not cancelled.

- In the vanilla pose the weapon still covers the landing point, so 2.0.0 ships its own gun-down clips
  (`WPNIdleGunDown.hkx`, `WPNRunGunDown.hkx`; all weapon types, normal body and power armor, base game and
  DLC - 120 clips). `tools/gen_anims.py` takes them from the game archives and lowers the `COM` bone by 25
  units (the arms and the weapon hang from it, the camera doesn't); nothing else in the clips changes.
- Melee weapons have no gun-down pose; the mod leaves them alone.
- MCM: lower the weapon while aiming a throw; separate throw and bash keys and the bash key; log.
- Known problems reported by users: the weapon lowers by itself and becomes invisible after a few seconds
  of idling; on the Anniversary Edition the trajectory disappeared and the key only bashed. The clips also
  conflict with other mods that replace the same animations, and the weapon goes lower whenever the game
  lowers it on its own.

Building this branch: see [README.ru.md](README.ru.md#сборка). In addition to the 1.0 tools,
`tools/gen_anims.py` builds the gun-down clips from the game archives (`tools/hkx.py` and `tools/hkanim.py`
read and patch Havok 2014 packfiles and spline / lossless animations).

## License

The Unlicense - public domain. Made with Claude Code.
