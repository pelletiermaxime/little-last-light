# Swarm performance improvements

Implemented on `feat/enemy-performance`, based on `6caa163`, in the isolated worktree:

`/home/maximep/.codex/worktrees/2a2c/little-last-light`

## Findings and changes

The reported drop from 144 FPS to below 30 FPS was not reproduced on a graphical display here. Code inspection found avoidable costs that grow with enemy and turret counts, and the headless benchmark confirms a substantial reduction in CPU frame time after removing them.

- **Basic enemies:** previously rebuilt three circles and their health bar every movement frame. The body now uses cached drawing commands on a child canvas item, whose rotation follows the heading. The upright health bar redraws when damage changes it. Chargers retain their distinct animated warning and diamond.
- **Turrets:** previously rebuilt their range circle and body every frame and searched all enemies every frame when idle. They now redraw when a shot begins or ends, poll for targets every 0.1 seconds while idle, and compare squared distances. Target choice and firing cooldown remain the same. A newly reachable enemy can now wait up to 0.1 seconds for acquisition, subject to frame duration.
- **Contact damage:** previously refreshed the entire HUD for each individual hit. Damage still applies immediately, while the existing 10 Hz HUD update displays accumulated changes. Death still immediately updates the preparation screen.

Enemy speed, steering, swept contact detection, spawn pressure, health progression, and population are unchanged. The spawn interval eventually reaches 0.12 seconds (about 8.3 basic enemies per second), so long runs can contain considerably more enemies than are visually distinguishable in an overlapping crowd. Work still grows with population; this change does not impose an enemy cap.

## Measured results

Godot 4.7.2, headless, fixed simulation timestep of 1/144 second. Each population receives 30 warmup frames and 240 measured frames, with a moving lantern, five-minute enemy health, the starter turret, and 24 additional out-of-range turrets. Contact damage is disabled for the benchmark swarm. The benchmark includes scene processing and canvas draw callbacks, but excludes real GPU rendering, browser overhead, and display presentation.

| Basic enemies | Before median frame time | After median frame time | Before p95 | After p95 |
| --- | ---: | ---: | ---: | ---: |
| 100 | 0.899 ms | 0.108 ms | 1.068 ms | 0.449 ms |
| 500 | 3.584 ms | 0.497 ms | 3.793 ms | 2.158 ms |
| 1,000 | 6.759 ms | 0.995 ms | 7.201 ms | 4.307 ms |

These single-run measurements show roughly 85–88% lower median CPU frame time in this workload. They are not rendered FPS predictions. Polling frames remain more expensive than intervening frames, as the p95 results show.

At 1,000 enemies, instrumented enemy and extra-turret redraw callbacks fell from 243,213 to 1 across the 240 measured frames. The optimized count also includes the new enemy body children. Cached visuals still render; this counts drawing-command rebuilds rather than GPU draw calls.

## Validation and reproduction

All 12 `tests/check_*.gd` scripts passed, covering building, chargers, controllers, difficulty, enemy movement, health, HUD, leaderboard state, pause, performance, layout reset, and runs/saves. `git diff --check` passed.

The new `tests/check_performance.gd` verifies cached drawings during movement, heading alignment, health-bar redraws on damage, idle search frequency, target acquisition, shot expiry, immediate accumulated damage, normal HUD refresh cadence, and immediate death UI updates. The existing build script discovers this check automatically.

Run the CPU benchmark from this worktree:

```sh
godot --headless --path . --script tests/benchmark_swarm.gd --fixed-fps 144
```

Run the same benchmark with rendering on a machine with an accessible display:

```sh
godot --path . --script tests/benchmark_swarm.gd --fixed-fps 144 --disable-vsync --windowed --resolution 1280x720
```

Run the performance regression check:

```sh
godot --headless --path . --script tests/check_performance.gd
```

The benchmark uses a process-specific temporary save path and does not load the player's progress. A graphical run was attempted here, but the available X11 display rejected access and no Wayland display was available. A long rendered run on the affected desktop or browser remains necessary to establish the actual FPS improvement and check whether any additional rendering bottleneck remains.
