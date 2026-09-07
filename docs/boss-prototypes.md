# Ten-minute boss playtests

Three alternatives for issue #2. Normal runs retain their existing encounters;
the practice launcher opts into one candidate. Its default is **Rainkeeper at 1:00**.

Run from this checkout with Godot:

```sh
godot --path . --script tests/launch_prototype_boss.gd
godot --path . --script tests/launch_prototype_boss.gd -- --boss=tidekeeper
godot --path . --script tests/launch_prototype_boss.gd -- --boss=wickwatcher
```

Close the previous practice window before trying another candidate. Each launch
opens preparation with six level-four damage/fire-rate turrets, 85 HP, and 1,000
energy to arrange or change the defense. Start normally; the selected boss arrives
after one minute of run time, and again on each retry. Progress uses a per-process
temporary practice save and leaderboard publishing is disabled. Ordinary enemies,
the five-minute Drencher and the fifteen-minute Snuffer keep their normal schedules.
For later timing tests, append `--arrival=600`; `--arrival=0` skips the minute wait.
An early arrival uses early-game swarm pressure, not simulated ten-minute balance.

## Candidates

- **Rainkeeper:** a fixed ripple marks your position for 1.2 seconds. Leave before
  the filled pool deals damage for two seconds, then return to boost turrets during
  its recovery. The outlined footprint stays in place and never tracks you.
- **Tidekeeper:** an edge warning has two gold markers around a wide opening.
  Move toward that opening, then cross the slow droplet front. Horizontal and
  vertical fronts alternate; only one front is active at once. The warning allows
  time to reach the gap from your position when it appears.
- **Wickwatcher:** High fills its three-segment charge quickly, Medium slowly,
  and Low drains it. Once the dashed rush line appears, the direction is locked:
  step aside. It opens its shell for two seconds afterward. Low does not make it
  invulnerable, and changing brightness cannot cancel an already warned rush.

All have 900 provisional HP, three seconds of protected arrival, and partial
susceptibility to pulse slows while drifting. They have no passive contact damage;
the Wickwatcher's rush hits once. Defeating a prototype clears its attacks and
continues the run, without a prototype reward or victory. The Snuffer retains HUD
priority and is still the victory condition.

For each candidate, check whether the tell is understandable within two cycles,
whether returning to turret boost range feels rewarding, and whether swarm pressure
creates interesting choices or unavoidable damage. Compare Low/Medium/High and a
mixed slow-turret layout. Also try edges, a narrow window, pause/retry, and an
undefeated Drencher. Health and timing are initial tuning values; the user playtest
will determine which idea to keep.
