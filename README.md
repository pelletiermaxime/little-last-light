# Little Last Light

A small Godot learning project: defend a mobile lantern with fixed, automatically firing turrets.

## Run the project

Open `project.godot` in Godot and press F6 for the current scene or F5 for the project. Developed with Godot 4.7.2 using the Compatibility renderer.

- WASD or arrow keys: move the lantern.
- Space: cycle brightness, energy generation, and enemy spawn rate.
- The turret stays in place and shoots nearby enemies.

Start in **Preparation**. Click an existing turret to move it for free, or build with **B**. Extra turrets cost **20, 30, 40, 50… energy**. Left-click to confirm a valid position; **Escape** cancels. Controls live in a separate right sidebar. The entire arena is buildable except for its edge margin and occupied turret positions. Click **Start run** or press **Enter** when ready; the arena keeps the same bounds during combat.

During a run, construction is locked and enemies spawn faster over time. Newly spawned enemies need one additional turret hit every 30 seconds; their health bars show remaining health. Enemies touching the lantern drain health. At zero health, enemies clear and your earnings are banked for preparation. Turrets and unspent energy carry into the next run.

Progress saves locally to `user://progress-v1.json` after purchases, moves, defeat, every five seconds during combat, and on a normal desktop close. Reopening returns to preparation with saved energy and turret positions. Turret upgrades are future work.

## Learn and explore

- [First milestone walkthrough](docs/milestone-1.md)
- [Health, defeat, and restart walkthrough](docs/milestone-2.md)
- [Turret placement walkthrough](docs/milestone-3.md)
- [Run progression and saving walkthrough](docs/milestone-4.md)
- [Design concept](docs/concept.html) — open this HTML file in a browser.
- [Playable browser demo](https://pelletiermaxime.github.io/little-last-light-demo/) — separately published export; may lag behind this source.

## Export

Linux and Web presets are included in `export_presets.cfg`. Install matching Godot export templates and create the `export` folder before exporting through Project → Export. Generated builds and Godot caches are excluded from Git.
