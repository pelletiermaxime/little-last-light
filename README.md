# Little Last Light

A small Godot learning project: defend a mobile lantern with fixed, automatically firing turrets.

## Run the project

Open `project.godot` in Godot and press F6 for the current scene or F5 for the project. Developed with Godot 4.7.2 using the Compatibility renderer.

- WASD or arrow keys: move the lantern.
- Space: cycle brightness, energy generation, and enemy spawn rate.
- The turret stays in place and shoots nearby enemies.

Enemies in contact drain health. At zero health, the run pauses: click **Try again** or press **R** to restart. Turret purchases and upgrades are planned additions.

## Learn and explore

- [First milestone walkthrough](docs/milestone-1.md)
- [Health, defeat, and restart walkthrough](docs/milestone-2.md)
- [Design concept](docs/concept.html) — open this HTML file in a browser.
- [Playable browser demo](https://pelletiermaxime.github.io/little-last-light-demo/) — separately published export; may lag behind this source.

## Export

Linux and Web presets are included in `export_presets.cfg`. Install matching Godot export templates and create the `export` folder before exporting through Project → Export. Generated builds and Godot caches are excluded from Git.
