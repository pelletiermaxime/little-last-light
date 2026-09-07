# Sniper visual study

The chosen **Watchlight** is now playable. For a fresh, funded local playtest
with two Watchlights, one basic turret and one slow turret, run:

```sh
godot --path . --script res://previews/launch_watchlight_playtest.gd
```

This uses a temporary save and disables leaderboard requests. Add
`-- --capture-watchlight` to capture placement/combat screenshots and exit.
In the normal game, click Watchlight in the placement toolbar or press
**R3 / right-stick click** on a controller. Turret purchases have no keyboard shortcut.

Run from the project directory:

```sh
godot --path . --script res://previews/launch_sniper_gallery.gd
```

The gallery shows Lenskeeper, Needle of Dawn, and Watchlight side by side at
gameplay size and 4× detail. Existing basic and slowing turrets provide a reference.
Both scales resize together to fit smaller windows; 1× is exact at 1152 × 760.

All variants share one 4.5-second clock and the same 0.12-second single-target
flash. Click **Fire together** (Space), **Pause / Resume** (P), or **Slow motion**.
Pause first, then fire to hold the shot for inspection. Targets are visual dummies;
the preview does not simulate damage, range, or target selection.

The reusable `sniper_visual.gd` draws the three appearances; `sniper_turret.gd`
now drives the Watchlight in combat. The gallery still compares all three designs.
The launcher never loads game progress and uses temporary display preferences.

For reproducible ready/firing screenshots, add `-- --capture-snipers` to the
launch command with a graphical display available. It writes
`/tmp/lll-snipers-ready.png` and `/tmp/lll-snipers-firing.png`, then exits.
