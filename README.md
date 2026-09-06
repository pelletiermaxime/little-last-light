# Little Last Light

A small Godot learning project: defend a mobile lantern with fixed, automatically firing turrets.

## Run the project

Open `project.godot` in Godot and press F6 for the current scene or F5 for the project. Developed with Godot 4.7.2 using the Compatibility renderer.

- WASD or arrow keys: move the lantern.
- Space: cycle brightness, energy generation, and enemy spawn rate.
- During a run, click the small brightness indicator along the bottom to cycle Low / Medium / High. Its three segments and energy rate show the current setting.
- The turret stays in place and shoots nearby enemies.
- During a run, **Escape / P / controller Options** pauses or resumes. The pause screen's **Resume** button also works with mouse or controller focus. Movement, combat, the timer, and earnings freeze; Escape still cancels turret placement during preparation.

**Controller:** prompts automatically switch to PlayStation, Xbox, or generic position icons when you use a controller, and back to keyboard prompts when you use the keyboard/mouse. Menus use the left stick or D-pad to select, Cross/A to confirm, and Circle/B to go back. In placement, the left stick moves the cursor and the D-pad selects toolbar buttons; move the stick to return to the arena. Square/X buys a turret, Cross/A selects or places it, Circle/B cancels, Triangle/Y hides or shows the controls, and R1/RB sells the selected purchased turret. Options/Menu starts or pauses a run. During combat, Cross/A cycles brightness. Upgrades and layout refunds are selected from their buttons, avoiding accidental purchases through shoulder shortcuts. Unknown pads use button-position icons. Username entry still uses the keyboard.

Start in **Preparation** with a compact card over the full arena. Choose **Place turrets**, **Buy upgrades**, or **Start run**. In placement mode, click an existing turret to move it for free, or build with **B**. Extra turrets cost **20, 30, 40, 50… energy**. Left-click to confirm a valid position; **Escape** cancels. The arena fills the window. The transparent placement card sits vertically on the left. Click through its background to place turrets, or press Tab to hide the controls and reach spots underneath buttons. Click **Start run** or press **Enter** when ready; the arena keeps the same bounds during combat.

During a run, construction is locked and enemies spawn faster over time. Newly spawned enemies need one additional turret hit every 30 seconds; their health bars show remaining health. Enemies touching the lantern drain health. At zero health, enemies clear and your earnings are banked. A dedicated results screen shows survival time, earned energy, and your best. Its Leaderboard button opens rankings and record publishing on separate tabs; Continue stays visible on every page. Rankings use Previous/Next buttons with three entries per page, so no menu needs scrolling. Continue returns to preparation. Turrets and unspent energy carry into the next run.

M6 basic enemies move at a fixed **85 pixels/second**, versus the lantern's **220**, and turn at **75 degrees/second** instead of instantly changing direction (2.4 seconds for a half-turn). Their eyes face their travel direction. Open space lets you escape; sharp dodges make pursuers curve around. Enemy speed no longer rises over time. Existing spawn and health scaling are temporary tuning, pending a roster of enemies with different movement patterns.

**Water boss:** The Drencher arrives once at 5:00, with 700 HP and a three-second warning. It slowly pursues the lantern and leaves temporary water puddles. Fresh puddles warn for 0.6 seconds, then deal 8 damage/second while touching the lantern; overlapping puddles do not stack damage. Defeat it with your turrets to clear the water and continue the run.

**Long-term run goal:** survive until a final boss arrives at **15:00**, then defeat it to win. Future difficulty should come from enemy patterns, combinations, and tougher bosses while preserving the lantern's movement advantage. The boss, victory flow, and encounter schedule are planned, not implemented in M6.

Progress saves locally to `user://progress-v1.json` after purchases, upgrades, sales, moves, defeat, every five seconds during combat, and on a normal desktop close. Reopening restores energy, turret positions, paid purchase prices, and global upgrade levels. Existing saves migrate automatically.

**End Run** on the pause screen banks and saves all earned energy and opens the results screen. Continue returns to preparation. Desktop preparation also has **Quit Game**, which saves before closing. The desktop game starts maximized.

**Global upgrades** in preparation affect every existing and future turret. Damage gains +1 per level (60, 120, 240, 480 energy); fire rate gains +25% of its original rate per level (50, 100, 200, 400 energy). Each has four levels. Use the buttons or **G / F**; with a controller, select an upgrade and confirm. Menu cards fit shorter windows without scrollbars; U opens the upgrades view.

**Sell selected turret** refunds its original purchase price: select a purchased turret as if moving it, then use the button, **X**, or controller **R1 / RB**. The free starter cannot be sold. New-turret prices still depend on how many you currently own.

**Reset layout** refunds the actual recorded cost of all purchased turrets, restores one free starter to its original position, and saves. Use its button or **R**; with a controller, select the refund button and confirm. Global upgrades, records, and other earned energy remain intact. Upgrading, selling, and resetting are available only in preparation, never during a paused run.

## Online leaderboard

The in-game Records view and results screen show the current version's published leaderboard. Editor runs use `dev` as a normal leaderboard version: you can publish records, view rankings, and retry failed requests just like a release. Development scores remain separate from release scores. The All versions link opens the website to browse every version.

The results screen offers to publish a new survival record with a username; pending offers remain available through **Records** in preparation. New records include earned energy, defense investment, and a turret-layout diagram with upgrade levels. Publication is optional; failed attempts can be retried, and records are separate for every game version. Saved energy and turret layouts continue across versions. The Nuxt website and Convex backend live in [`leaderboard/`](leaderboard/README.md), including setup, deployment, and verification instructions. Online publishing requires configuring this game's own backend and website URLs; unconfigured builds keep records locally.

## Learn and explore

- [Reset layout and refund arithmetic](docs/reset-layout.md)

- [Pause screen and scene-tree processing](docs/pause-screen.md)

- [First milestone walkthrough](docs/milestone-1.md)
- [Health, defeat, and restart walkthrough](docs/milestone-2.md)
- [Turret placement walkthrough](docs/milestone-3.md)
- [Run progression and saving walkthrough](docs/milestone-4.md)
- [Clarity, brightness feedback, and run recap walkthrough](docs/milestone-5.md)
- [Slower enemies and committed pursuit walkthrough](docs/milestone-6.md)
- [Versioned online leaderboard walkthrough](docs/milestone-7.md)
- [Charging enemy walkthrough](docs/milestone-8.md)
- [Upgrades, selling, and run results (M9)](docs/milestone-9.md)
- [Swarm performance and leaderboard run details (M10)](docs/milestone-10.md)
- [The Drencher water boss (M11)](docs/milestone-11.md)
- [Full arena and preparation cards (M12)](docs/milestone-12.md)
- [Sound effects and settings (M13)](docs/milestone-13.md)
- [Audio and display settings](docs/settings.md)
- [Editing menu scenes and the shared Theme](docs/menu-scenes.md)
- [Design concept](docs/concept.html) — open this HTML file in a browser.
- [Playable browser demo](https://pelletiermaxime.github.io/little-last-light-demo/) — automatically published from successful `main` builds.

## Export

Linux, Windows, and Web presets are included in `export_presets.cfg`. Install matching Godot 4.7.2 export templates and create the `export` folder before exporting through Project → Export. Generated builds and Godot caches are excluded from Git.

### Automated builds and publishing

`.github/workflows/publish.yml` builds all three platforms on pushes to `main` and `feat/**` branches, and on pull requests to `main`. A push to `main` also deploys the browser game to [the public demo repository's Pages site](https://pelletiermaxime.github.io/little-last-light-demo/) and publishes Windows and Linux x86_64 archives, plus SHA-256 checksums, in [Releases](https://github.com/pelletiermaxime/little-last-light/releases). Feature branches only upload build artifacts, so the pipeline can be tested before merging. The source repository stays private; only the web export is copied to the demo repository.

Godot and the three required release templates are cached by engine version, runner OS, and architecture. A cache hit skips the download and installation steps. The first run, a Godot version change, or an evicted cache requires a fresh download; the game itself is rebuilt every run.

**Deployment setup:** The public `pelletiermaxime/little-last-light-demo` repository serves Pages from `main`, at `/`. A write-enabled deploy key on that repository has its private key stored in this source repository's `PAGES_DEPLOY_KEY` Actions secret. This key is restricted to the demo repository and used only in the `pages` job on `main`. Keep the `github-pages` environment open to `main` deployments. Publishing preserves the demo README and replaces the exported site files; GitHub then builds the public Pages site. Desktop releases use the source repository's built-in `GITHUB_TOKEN`. Pages does not need to be enabled on this private repository.

### Automatic versions and changelog

`scripts/prepare-release.py` starts at `0.0.1` and increments the patch version from existing `vMAJOR.MINOR.PATCH` Git tags: `v0.0.1`, `v0.0.2`, and so on. These tags are the published version history. `config/version` in `project.godot` is the minimum version; raise it manually when you want a new minor or major series, such as `0.1.0`. The script stamps the selected version into the build's project settings and a `version.txt` included in each platform export. It does not commit automatic version edits back to `main`, so there is no extra build loop. Local builds also stamp the working copy's project version.

Releases use the version as both name and tag, point to the exact source commit, and contain a changelog of non-merge commits since the previous version (all history for the first version), with a comparison link. Rebuilding an already tagged commit reuses its version and replaces its release assets instead of consuming another number. Build-only branches do not create tags or consume versions. The old `build-*` release remains available but does not affect version numbering.

Pull requests only build and upload artifacts; they do not publish. You can also use **Actions → Build and publish game → Run workflow** on `main` to publish manually. Other branches only build. Pages and release publication run independently after a successful build, so a Pages deployment error does not prevent desktop downloads from publishing. The Pages job publishes the public repository commit; final site deployment runs in the public repository's Pages workflow.

The Web preset has threads disabled, allowing it to run on Pages without custom cross-origin isolation headers. Desktop downloads are unsigned. Extract the Windows zip and run `little-last-light.exe`; extract the Linux tarball and run `./little-last-light.x86_64` (the archive preserves executable permissions).

To reproduce the build locally on Linux, install Godot 4.7.2, its matching export templates, Python 3, `zip`, and `tar`, then run `bash scripts/build-release.sh`. Fetch the repository tags first to calculate the current version. Set `GODOT_BIN` if the executable has another name. The script imports assets before exporting and writes the site to `export/web`, release archives to `export/downloads`, and version/changelog metadata to `export/release`. When upgrading Godot, update `GODOT_VERSION` in the workflow and use matching local templates.

**Lantern health:** start with 25 HP. Preparation offers four permanent +15 HP upgrades (40, 80, 160, 320 energy), up to 85 HP. Buy with the Lantern HP button, H, or controller R3. Every run starts at your upgraded maximum; resetting the turret layout preserves health upgrades.
