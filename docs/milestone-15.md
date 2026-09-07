# Milestone 15: holding a defended position

M15 adds one stationary ward and a repeating encounter schedule. Implementation
is isolated to the M15 worktree; no merge, push, deployment, source-checkout edit,
turret changes, or save-format changes are included.

## Ward tuning and behavior

| Setting | Initial value |
| --- | --- |
| Formation delay | 1.25 seconds of continuous stillness |
| Capacity | 8 damage points, independent of health upgrades |
| Recharge delay | 3 seconds after any positive incoming damage, including absorbed damage |
| Recharge rate | 4 points per second, only while settled |
| Movement deadzone | 0.25, shared by movement and ward detection |
| Full ward from a fresh stop | 3.25 seconds if no damage intervenes |
| Full recovery after breaking | 5 seconds without damage if remaining settled |

The reserve starts empty. Moving immediately discards it and resets formation;
the recent-damage timer survives movement. No activation grants free capacity.
Meaningful movement intent also removes the ward when pushing against an arena
edge. Sub-deadzone controller input causes neither movement nor interruption.

All attacks keep calling `lantern.take_damage(amount)`. It absorbs from the ward,
then applies the remainder to health. A 12-point charger hit passes four points
through a full ward. Drencher puddles deal 8 points per second: one second drains
the full reserve, continued exposure hurts health and continually postpones
recharge. Moving out of a puddle ends exposure through the existing hazard logic.
Negative damage remains ignored. Death and fresh runs clear every ward field.

Formation uses a dashed outline and a growing arc. Active capacity uses a solid
arc proportional to available protection. Broken uses a red dashed outline.
Absorption briefly flashes the ring white. A HUD label also names forming,
broken, and active capacity states so color alone never carries the meaning.
The normal health flash/audio are reserved for damage that reaches health.

## Encounter pacing and integration contract

`encounter_schedule.gd` is a pure, elapsed-time schedule:

| Each 60-second cycle | Pursuer rate multiplier | New chargers |
| --- | --- | --- |
| 0–20 seconds: Gathering | 0.65 | None |
| 20–40 seconds: Pressure | 1.0 | Existing 8-to-5-second cadence, cap four |
| 40–60 seconds: Recovery | 0.25 | None |

The first charger still arrives at 0:20. A new pressure period admits one due
charger, without catching up missed spawns. Existing enemies remain dangerous
during recovery; recovery reduces incoming pressure rather than deleting threats.
The HUD names the current period underneath energy earnings.

The existing pursuer time ramp stops increasing at 100 seconds (6x). Brightness
still produces 1/3/6 energy per second. At the capped ramp in a pressure period,
Low/Medium/High pursuer intervals are approximately 0.333/0.200/0.120 seconds.
Recovery makes each four times longer. This preserves distinct brightness risk
instead of eventually flattening all levels at one spawn floor. Existing enemy
toughness and movement speed remain unchanged.

The Drencher still spawns once at 300 seconds. There is no ten-minute boss.
`FINAL_ENCOUNTER_TIME = 900.0` is the ordinary-spawning boundary. M16 can use
`ordinary_spawns_enabled(seconds)` and the constant directly. The additional
pure functions are `period(seconds)`, `pursuer_rate_multiplier(seconds)`, and
`chargers_enabled(seconds)`.

At 15:00, normal pursuer and charger creation stops, including direct calls to
the main spawn methods. Existing enemies and any living Drencher are retained.
M16 owns retiring/replacing those enemies and the final encounter itself; this
milestone does not clear them or create a boss. Merge the final encounter hook
before ordinary spawn processing. M14's slow and turret interfaces are untouched.

Expected shared-file merge areas are `main.gd` (start/end reset, pacing and spawn
guards) and `game_hud.gd` (new ward/period labels). Preserve M14 turret configuration
and M16 final-boss/records behavior when combining changes. No ward field belongs
in the persistent save or leaderboard layout schema.

## Validation and observed results

Godot 4.7.2 imported the project without script errors. All 24 `tests/check_*.gd`
regression scripts passed across the full run and focused reruns. Two preexisting
schedule assumptions were updated: the run test now includes the Gathering-to-
Pressure multiplier, and the charger cap test directly exercises the cap rather
than assuming continuous spawning through recovery.

`tests/check_ward_schedule.gd` covers 30/60/144 FPS charging, formation delay,
small leaks, overflow, recharge delay/partial frames, negative damage, input drift,
movement, repeated stops, real puddle exposure and escape, actual tree pause in
forming/active/broken states, defeat/restart, pressure transitions, brightness
ordering, Drencher timing, and the 15:00 ordinary spawn boundary.

`tests/playtest_ward.gd` runs reproducible simulation probes with seed 15, four
damage turrets, one damage upgrade, an 85-HP initial test budget, and either a
stationary lantern or a 100-pixel orbit at 150 pixels/second. The first-minute
headless probe observed:

| Mode | Brightness | Result |
| --- | --- | --- |
| Settled | Low | 60 seconds, 85 HP, 8 ward points |
| Orbit | Low | 60 seconds, 85 HP, no ward |
| Settled | High | Defeat at 34.0 seconds |
| Orbit | High | Defeat at 51.9 seconds |

These are controlled probes, not human feel testing or claims of full-run
balance. The low-brightness defended pocket works for both playstyles; the same
defense is overwhelmed at High and movement prolongs survival. An earlier probe
with only the starter turret also showed that ward capacity cannot replace
adequate defenses. The focused damage tests establish the ward's leak handling
even where a well-covered probe takes no damage.

Native OpenGL rendering was run with display access and the forming, active, and
broken screenshots were visually inspected. The ring shapes and HUD labels are
distinct and unobstructed. Temporary captures are `/tmp/m15-ward-forming.png`,
`/tmp/m15-ward-active.png`, and `/tmp/m15-ward-broken.png`. The native harness logs
an existing settings-menu anchor warning and reports a few resources in use at
shutdown; the headless regression scripts complete successfully. Screenshot
capture is a scripted visual probe, not manual controller playtesting.

Useful commands from this worktree:

```sh
rtk proxy godot --headless --path . --script tests/check_ward_schedule.gd
rtk proxy godot --headless --path . --script tests/playtest_ward.gd
rtk proxy godot --path . --log-file /tmp/m15-render.log --rendering-method gl_compatibility --script tests/playtest_ward.gd
```

## Godot learning notes

The ward separates movement intent, formation time, protection reserve, and
damage-free time. Keeping those independent prevents a transition such as
moving-to-still from accidentally resetting a cooldown or granting protection.
`update_ward()` runs on the physics clock and only recharges the portion of a
frame after both formation and damage delay have expired. That makes long-frame
tests useful: a naive timer decrement followed by a full-frame recharge would
overfill the ward at boundaries.

Godot's scene-tree pause freezes the normal physics callback automatically. The
explicit pause guard also makes direct ward updates safe during a paused probe.
The drawing code derives the ring from ward state; it does not maintain a second
animation state machine that can drift away from gameplay.

The encounter schedule is a stateless `RefCounted` script with static functions.
Testing elapsed times immediately before and at each boundary is simpler than
waiting through a fifteen-minute run. Keeping the final encounter boundary here
lets the boss implementation coordinate timing without owning ordinary waves.

## Changed files and remaining integration work

- `lantern.gd`: ward state, movement deadzone, absorption and drawing.
- `encounter_schedule.gd` and its Godot UID: pure encounter timing interface.
- `main.gd`: ward reset and scheduled ordinary spawning.
- `game_hud.gd`: ward status and current period labels.
- `tests/check_ward_schedule.gd`: new behavioral regressions.
- `tests/check_charger.gd`, `tests/check_runs.gd`: updated schedule expectations.
- `tests/playtest_ward.gd`: controlled movement/settling and native visual probe.
- `docs/milestone-15.md`: tuning, learning notes, validation and merge contract.

Before calling the combined M14–M16 experience balanced, play a real defended
pocket with pulse turrets and the final boss. The remaining design choice is
M16's treatment of an undefeated Drencher and leftover ordinary enemies at dawn.
Neither that choice nor manual feel testing blocks integrating this isolated
ward/schedule implementation.
