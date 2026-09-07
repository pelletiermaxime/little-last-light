# Sniper visual study

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

The reusable `sniper_visual.gd` draws the three appearances. A future combat
turret can drive its design, charge, flash, aim angle, and shot endpoint. This
preview does not add three purchasable turrets or alter the normal game scene.
The launcher never loads game progress and uses temporary display preferences.

For reproducible ready/firing screenshots, add `-- --capture-snipers` to the
launch command with a graphical display available. It writes
`/tmp/lll-snipers-ready.png` and `/tmp/lll-snipers-firing.png`, then exits.
