# Little Last Light

A small Godot learning project: defend a mobile lantern with fixed, automatically firing turrets.

## Run the project

Open `project.godot` in Godot and press F6 for the current scene or F5 for the project. Developed with Godot 4.7.2 using the Compatibility renderer.

- WASD or arrow keys: move the lantern.
- Space: cycle brightness, energy generation, and enemy spawn rate.
- During a run, click Low / Medium / High in the sidebar to select brightness directly.
- The turret stays in place and shoots nearby enemies.

DualSense / gamepad controls: **left stick or D-pad** moves the lantern during a run and a visible cursor during preparation. **Cross** cycles brightness during a run; during preparation it selects a turret or confirms placement. **Square** buys a turret, **Circle** cancels placement, and **Options** starts the run. These use Godot's standard gamepad mapping (A, X, B, and Start on Xbox-style controllers). Keyboard and mouse remain supported. Restart the running scene after changing input bindings; previously exported builds must be exported again to include changes.

Start in **Preparation**. Click an existing turret to move it for free, or build with **B**. Extra turrets cost **20, 30, 40, 50… energy**. Left-click to confirm a valid position; **Escape** cancels. Controls live in a separate right sidebar. The entire arena is buildable except for its edge margin and occupied turret positions. Click **Start run** or press **Enter** when ready; the arena keeps the same bounds during combat.

During a run, construction is locked and enemies spawn faster over time. Newly spawned enemies need one additional turret hit every 30 seconds; their health bars show remaining health. Enemies touching the lantern drain health. At zero health, enemies clear and your earnings are banked for preparation. Turrets and unspent energy carry into the next run.

Progress saves locally to `user://progress-v1.json` after purchases, moves, defeat, every five seconds during combat, and on a normal desktop close. Reopening returns to preparation with saved energy and turret positions. Turret upgrades are future work.

## Online leaderboard

The preparation sidebar offers to publish a new survival record with a username. Publication is optional; failed attempts can be retried, and records are separate for every game version. Saved energy and turret layouts continue across versions. The Nuxt website and Convex backend live in [`leaderboard/`](leaderboard/README.md), including setup, deployment, and verification instructions. Online publishing requires configuring this game's own backend and website URLs; unconfigured builds keep records locally.

## Learn and explore

- [First milestone walkthrough](docs/milestone-1.md)
- [Health, defeat, and restart walkthrough](docs/milestone-2.md)
- [Turret placement walkthrough](docs/milestone-3.md)
- [Run progression and saving walkthrough](docs/milestone-4.md)
- [Clarity, brightness feedback, and run recap walkthrough](docs/milestone-5.md)
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
