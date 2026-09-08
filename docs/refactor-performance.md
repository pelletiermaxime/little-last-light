# Code structure and browser performance

## Result

The game code is organized by domain, with scene/script pairs kept together.
Main now coordinates the run lifecycle instead of also implementing persistence
and encounter scheduling. Browser rendering was measured and optimized after
the structural refactor.

In the matched browser stress test, 1,000 pursuers, 25 total turrets, the Drencher
and the Rainkeeper improved from **33.3 ms median frame time to 16.7 ms**:
approximately **30 FPS to 60 FPS**. Median draw calls fell from **4,366 to 369**.
The p95 frame time improved from **49.4 ms to 18.0 ms**.

This is a substantial improvement, but **not a guarantee of a locked 60 FPS**.
The final run still had 16 of 360 frames above 18 ms. Full-screen/high-DPI
rendering, the final boss, long sessions, spawning and autosave need separate
measurements in the browser where remaining hitches occur.

The refactor does not change the release version or publishing configuration.

## Where code belongs

| Location | Responsibility |
| --- | --- |
| `main.gd` / `main.tscn` | Run transitions, upgrades, rewards and scene coordination |
| `enemies/` | Pursuer and charger scripts/scenes; shared pursuer texture atlas |
| `turrets/` | Basic, pulse, Watchlight, Ember Pot, Sentinel and sniper visuals |
| `bosses/` | Drencher, Rainkeeper and Snuffer |
| `hazards/` | Enemy droplets and water trails |
| `screens/` | Preparation, pause, results, settings and leaderboard screens |
| `ui/` | HUD, brightness indicator, FPS counter and shared UI styling |
| `game/` | Encounter director/schedule, progress store, building and pickups |
| `tests/` | Gameplay regression checks and repeatable performance harnesses |

Shared application services—audio, display settings and input controls—remain
at the root with the lantern and project entry point. Existing scene child names
and script UIDs are preserved. Resource paths, test callers and documentation
links were updated for the moves.

## Refactors

- [Encounter director](../game/encounter_director.gd) owns spawn pressure, charger
  cadence, boss arrivals and their per-run state. Main calls its update explicitly,
  preserving processing order and pause behavior. Consumers use
  `scene.encounters` to inspect or drive encounters.
- [Progress store](../game/progress_store.gd) owns save/load/reset serialization,
  validation and atomic file replacement. Normal saves and explicit resets share
  one writer; repeated finite-number checks share one validator.
- Rainkeeper and Snuffer arrivals share their opposite-corner placement helper.
  The Drencher retains its distinct farthest-corner rule.
- Basic and Ember turrets share boosted cooldown advancement. Their distinct
  attack timing, targeting and damage behavior remain separate.
- Removed the obsolete sniper gallery and playtest launchers, along with the
  gallery-only alternate sniper designs. The shipped Watchlight visual is preserved.
- Main is now 383 lines, down from roughly 740. It retains run transitions where
  ordering matters rather than scattering them across utility classes.

The save format, malformed-save protection, empty-save recovery, legacy purchase
costs, current-run energy accounting and version-specific records are preserved.
Enemy movement, steering, contact damage, spawn rates, hitboxes, turret target
priorities and purchase/upgrade balance were not changed.

Applied areas: four reuse improvements (atomic writing, numeric validation,
corner placement and cooldown advancement), three structural improvements
(domain folders, persistence extraction and encounter extraction), and two
rendering improvements below.

## Rendering changes

### Cached turret ranges

Each turret has a cached `RangeIndicator` child. Boost tethers, sniper aiming,
shots and area-attack animations can redraw without rebuilding the range circle.
Changing `attack_range` invalidates the circle; moving a turret moves its cached
child automatically.

The original mixed workload rebuilt these circles about 4,100 times over 360
browser frames. The updated workload rebuilt them **zero times after warmup**.
This reduced CPU work but, on its own, did not resolve the 1,000-enemy browser
slowdown or significantly reduce GPU draw calls.

### Batched pursuer visuals

Pursuer bodies previously used three separately drawn circles, interleaved with
health bars. Cached commands avoided reconstructing the shapes, but the browser
still issued thousands of draw calls.

[The shared atlas](../enemies/pursuer_atlas.svg) contains the same purple body,
pale eyes and a white swatch for tinting health bars. Drawing the body and both
bar sections from the same texture lets Godot batch neighboring enemies.
The body still rotates with heading and health bars remain upright. The SVG is
rasterized at four times its displayed size; edge antialiasing may differ slightly
from the old procedural circles. Bosses and chargers retain their custom visuals.

## Browser measurements

Baseline: Git revision `0cf5261`. Updated build: this working tree.

Both isolated Web release exports used the current benchmark harness, the same
random seed, a **fixed simulation step of 1/60 second**, 120 warmup frames and
360 measured frames per scenario. Reported times are wall-clock frame intervals,
including browser presentation, rather than the fixed simulation delta.

Environment: Godot 4.7.2, Compatibility renderer, single-threaded Web export,
Chrome 152 in the Codex browser on Linux, Intel Arc (MTL) through Mesa/ANGLE.
The tab stayed visible. Canvas backing size was 1280 × 720, Godot's logical
viewport was 1152 × 648, and reported device pixel ratio was about 1.95.
These results are for that fixed canvas size, not a native-resolution fullscreen
canvas on a high-DPI display.

Every scenario uses the starter turret plus 24 additional turrets split evenly
between basic, pulse, sniper and Ember. The lantern follows a repeatable path.
The last scenario adds the Drencher and Rainkeeper, including their hazards.
Pursuers have high health and no contact damage so population stays fixed.

| Scenario | Before median | After median | Before p95 | After p95 | Before p99 | After p99 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 100 enemies + mixed turrets | 16.6 ms | 16.7 ms | 18.5 ms | 18.0 ms | 22.4 ms | 19.1 ms |
| 500 enemies + mixed turrets | 16.8 ms | 16.7 ms | 31.9 ms | 18.0 ms | 40.8 ms | 19.0 ms |
| 1,000 enemies + mixed turrets + bosses | 33.3 ms | 16.7 ms | 49.4 ms | 18.0 ms | 82.1 ms | 19.0 ms |

| Scenario | Before median draw calls | After median draw calls | Before frames >18 ms | After frames >18 ms |
| --- | ---: | ---: | ---: | ---: |
| 100 enemies | 675 | 278 | 30 / 360 | 17 / 360 |
| 500 enemies | 2,275 | 278 | 47 / 360 | 15 / 360 |
| 1,000 enemies + bosses | 4,366 | 369 | 360 / 360 | 16 / 360 |

18 ms is a hitch-count threshold allowing a little presentation jitter; the
strict 60 FPS frame budget is 16.67 ms. p95 means 95% of sampled frame intervals
were at or below that duration. Each table entry is a single matched run, not a
statistical confidence interval. Earlier exploratory runs with variable simulation
delta showed the same large improvement, but were not used for these tables
because the slower baseline advanced boss patterns farther.

## Remaining performance investigation

1. **Profile a real long run on the affected browser.** This harness disables
   Main's automatic spawning and five-second autosave, freezes the run clock,
   and deliberately keeps a fixed enemy population. Correlate remaining hitches
   with save times, new arrivals, population and display size.
2. **Measure the Snuffer's later phases and fullscreen/high-DPI rendering.**
   The current stress scenario includes two earlier bosses, not the final boss
   or every possible effect combination. Keep resolution and browser visibility
   recorded with results.
3. **If profiling identifies target polling spikes, consider shared spatial
   queries.** Target searches still scan the enemy group. Preserve strict versus
   inclusive range boundaries, tree-order ties, dead-target filtering and sniper
   priority if replacing those scans.
4. **If hazards become the bottleneck, cache stable puddle drawing and avoid
   replacing its array every tick.** Most puddles are visually static between
   the warning and fade phases. This remains unmodified because the measured
   dominant cost was pursuer rendering.

No enemy cap, reduced spawn pressure, disabled visual effects, lower resolution
or changed thread settings were used as a performance shortcut. Autosave's
recovery behavior remains intact.

## Validation

- Godot headless editor import/type parsing: passed.
- All **41** `tests/check_*.gd` scripts: passed.
- All **19** Python release-tool tests: passed.
- Performance regression coverage now checks all four permanent turret types:
  animation still redraws, static rings remain cached, placement preserves the
  cache, and a range change invalidates it.
- Existing coverage verifies enemy movement, damage, boss encounters, upgrades,
  saves, reset/recovery, menus, controls and leaderboard state.
- Isolated baseline and updated Web release exports: passed.
- Normal game Web release export and preparation-screen startup smoke check: passed.
- Browser measurement and visual inspection: completed.
- `git diff --check`, executable resource references and local documentation links: clean.
- Independent static reviews of extraction, paths, inheritance and rendering:
  no blocking findings.

There is no standalone GDScript lint/format command configured in this repository;
Godot import and the full executable regression suite provide parsing and behavior
checks. The unchanged leaderboard application was not retested.

## Reproduce

Run the complete game checks using the same commands as the release workflow:

```sh
rtk proxy godot --headless --editor --import
for check in tests/check_*.gd; do
  rtk proxy godot --headless --script "$check"
done
rtk proxy python3 -B -m unittest discover -s tests -p 'test_*.py'
```

For the original CPU-only swarm benchmark:

```sh
rtk proxy godot --headless --script tests/benchmark_swarm.gd --fixed-fps 144
```

For the mixed rendering workload without a browser:

```sh
rtk proxy godot --headless --fixed-fps 60 res://tests/benchmark_rendering.tscn
```

Headless times exclude real GPU rendering and display presentation. Remove
`--headless` on a machine with an available display to include native rendering.

Build comparable Web benchmarks without modifying the actual startup scene or
release version:

```sh
rtk proxy python3 scripts/build-render-benchmark.py export/perf-before --ref 0cf5261
rtk proxy python3 scripts/build-render-benchmark.py export/perf-after
rtk proxy python3 -m http.server 8067 --bind 127.0.0.1 --directory export
```

Open `http://127.0.0.1:8067/perf-before/benchmark.html`, click Start benchmark,
and keep it visible until `RENDER_BENCHMARK_COMPLETE`. Repeat with
`http://127.0.0.1:8067/perf-after/benchmark.html`. The page records environment
details, prints results and retains the last rendered frame for inspection.
Discard a run if the page reports a visibility change during measurement.
Stop the server with Ctrl+C when finished.

The exporter stages a temporary project, overlays the same current harness on
both revisions, selects that harness as the temporary startup scene, and then
exports it. This is necessary because the standard Web release template rejects
command-line scene-path overrides. Its shell uses the documented
[Engine configuration arguments](https://docs.godotengine.org/en/stable/tutorials/platform/web/html5_shell_classref.html)
to set the fixed simulation timestep. Matching Godot export templates and
Python 3.12 or newer are required; `GODOT_BIN` can select the executable.
