# Milestone 11: The Drencher

At 5:00, a large water creature arrives to turn familiar paths into hazardous ground. This is the first intermediate boss; defeating it continues the run toward the planned 15-minute final encounter.

## Current tuning values

- 700 HP, versus 11 HP for a basic enemy at five minutes.
- Body radius 34 pixels, speed 78 pixels/second, turning 30 degrees/second.
- Spawns once per run at the farthest inset corner and waits three seconds inside a blue warning ring.
- Touching its larger body deals 20 damage/second.
- Leaves a puddle every 24 pixels of travel. Each has a 25-pixel radius, a 0.6-second harmless warning, and an eight-second total lifetime.
- Water deals 8 damage/second while touching the lantern. Overlapping puddles do not multiply that damage. Water does not damage turrets.

These values are a first playtest, not settled balance. The intended choice is to lead the boss through turret coverage while preserving a dry escape path. There is no water-spit attack, movement slowdown, or additional boss reward yet.

## Reusing enemy behavior

`water_boss.gd` extends the existing enemy script, so it joins the same enemy group and uses the same health and turret-damage interface. The shared contact distance is now an exported property: ordinary enemies keep 20 pixels, while the boss uses 44 to account for its larger body and the lantern radius.

The boss also reuses committed steering and swept contact detection. Its body drawing stays cached on a rotating child canvas item, preserving M10's drawing optimization.

Main checks the elapsed run time and a `boss_spawned` flag. The flag stays true after death so the boss cannot repeatedly respawn, and resets when a new run begins. The HUD reads the boss's health and shows its arrival, active health bar, and defeat state.

## Water belongs to the encounter

`water_trail.gd` is a child of the boss. Puddle positions are stored in world coordinates, so they stay behind while their parent moves. Distance-based placement prevents a stationary boss from stacking puddles. The list is bounded at 64 entries.

Each puddle tracks age. Damage uses only the part of an update after its warning and before expiration; overlapping puddles use the largest exposure instead of adding damage. The trail fades during its last two seconds.

Normal scene-tree pause freezes the boss and its trail. Boss death disables and removes the trail. Ending a run clears hazards and enemies immediately, preventing queued objects from damaging the next run.

## Verification

All 16 Godot regression suites passed. The new boss check covers the configured spawn-time boundary, single spawn, arrival delay, trail placement, warning/expiry, non-stacking damage, larger contact radius, turret hits, pause, death cleanup, and a fresh run. A rendered preview was inspected using a temporary save.

Start with [water_boss.gd](https://github.com/pelletiermaxime/little-last-light/blob/milestone-11/water_boss.gd), [water_trail.gd](https://github.com/pelletiermaxime/little-last-light/blob/milestone-11/water_trail.gd), and [tests/check_boss.gd](https://github.com/pelletiermaxime/little-last-light/blob/milestone-11/tests/check_boss.gd). These source links are pinned to milestone-11 so later changes do not alter this lesson.
