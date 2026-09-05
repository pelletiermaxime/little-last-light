# Milestone 8: bait and dodge a charger

This lesson describes the approved **M8** checkpoint, preserved by the [`milestone-8` tag](https://github.com/pelletiermaxime/little-last-light/tree/milestone-8). M8 adds one enemy pattern, without implementing the planned final boss.

## What changed

Round purple enemies still pursue slowly. The new amber diamond approaches at 60 pixels/second, stops to warn, charges straight ahead, then rests. The lantern is faster than its approach; the brief, clearly warned charge is the exception.

The first charger spawns at 20 seconds. Arrivals start eight seconds apart, gradually reaching five seconds apart at two minutes, with at most four alive at once. Brightness continues to affect basic enemies rather than shortening this cadence. Chargers start with at least three health, or one more than a new basic enemy at that time, so turrets can still kill them before an attack.

## The idea to learn: one state at a time

```text
APPROACH → WARNING → CHARGING → RECOVERY → APPROACH
```

`charger.gd` extends `enemy.gd`: it reuses health, turret targeting through the enemies group, damage handling, and swept contact geometry. It replaces movement and drawing. This lets the existing turret shoot a charger without knowing its attack pattern.

The four states give each phase a single job:

| State | Behavior | Visible cue |
| --- | --- | --- |
| Approach | Move toward the lantern at 60 px/s | Amber pointed body |
| Warning | Track slowly for 0.5 seconds, then lock for 0.4 seconds | Dashed tracking lane becomes bright and solid when locked |
| Charging | Move along the locked heading at 380 px/s for 0.7 seconds | Short bright trail |
| Recovery | Stop for 1 second | Dim body |

## Why the warning is fair

The approach updates `heading` toward the lantern. WARNING turns toward it at at most 90 degrees per second for the first half-second. The final 0.4 seconds lock that heading: the bright solid lane shows where the charge will actually travel. CHARGING never adjusts direction. An early sidestep allows some correction; moving after the lock is reliable but leaves less reaction time.

```gdscript
state = State.WARNING
state_remaining = warning_duration
```

`state_remaining` counts down using `delta`. Long frames are split at state boundaries, and rotation uses only the part before the lock. Time spent warning is not also counted as charge movement. The paused scene tree freezes this script naturally, including its timer; no separate pause timer is needed.

## A charge hits once

Each charge step uses the inherited segment/circle helper. Checking only the final position could miss a fast enemy crossing the lantern between frames. A hit stops at contact, deals 12 health, and immediately enters recovery. Warning and recovery themselves do not damage the lantern, giving a clear chance to escape.

The intended tactic is to bait a lane through turret coverage, step sideways, and let the turrets fire while the charger rests. A missed charge travels about 266 pixels. It can cross the arena edge and approach again afterward; boundary behavior and overall difficulty remain playtest tuning.

## Try it and understand the checks

Survive until 00:20, then watch for the amber diamond. The dashed lane can follow you; when it turns solid, sidestep the committed route. Stop briefly during its dim recovery to see the opening. Pause during a warning and confirm the ring resumes where it stopped. This tuning responds to the first playtest finding too few chargers and too much time to dodge; charge speed and damage remain unchanged.

The new headless check exercises limited tracking, the final aim lock, long frames crossing the lock boundary, dodging, recovery, single-hit swept contact, initial overlap, 30/60/144-FPS behavior, turret damage, pause/resume in all four states, the spawn ramp/cap, and defeat/End Run cleanup. All eleven gameplay suites pass with temporary saves.

## Where to look

- [charger.gd](https://github.com/pelletiermaxime/little-last-light/blob/milestone-8/charger.gd): state transitions, charge contact, visual cues.
- [main.gd](https://github.com/pelletiermaxime/little-last-light/blob/milestone-8/main.gd): introduction time and spawn cap.
- [tests/check_charger.gd](https://github.com/pelletiermaxime/little-last-light/blob/milestone-8/tests/check_charger.gd): isolated gameplay scenarios.

These links preserve the historical source even when later milestones change the files.

M8 also labels editor playtests `dev`, keeps their best times separate, and prevents publishing development scores to release leaderboards. Energy and turret progress still save. Exported releases retain their stamped numbered version. The milestone includes the shortened earlier learning docs and removal of the unsupported arrow from the leaderboard link.
