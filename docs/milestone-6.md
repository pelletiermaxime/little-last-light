# Milestone 6: enemies you can dodge

This lesson describes **M6 as it shipped**, rather than the current game. [Browse the complete milestone source](https://github.com/pelletiermaxime/little-last-light/tree/milestone-6). The short excerpts below come from that tag; full files remain available through the links.

## What changed

Basic enemies now move at a fixed **85 pixels per second**, compared with the lantern's **220**, and turn at **75 degrees per second**. A half-turn takes at least 2.4 seconds. Their eyes face their travel direction, making their commitment visible.

Enemy speed no longer increases with elapsed time. Difficulty from different movement patterns and bosses is the future direction. Reaching and defeating a final boss at 15:00 is a planned objective; M6 does not implement that encounter or a victory timer.

## The idea to learn: facing the target and travelling toward it are different

An enemy remembers a unit vector called `heading`. Each frame, it calculates the direction it wants to face, but limits how far it can turn:

[enemy.gd, excerpt](https://github.com/pelletiermaxime/little-last-light/blob/milestone-6/enemy.gd#L38)

```gdscript
	var desired := global_position.direction_to(target.global_position)
	# Initialize on the first movement, after Main has set the spawn position.
	if heading.is_zero_approx():
		heading = desired
	var max_turn := maxf(0.0, turn_speed) * delta
	heading = heading.rotated(clampf(heading.angle_to(desired), -max_turn, max_turn)).normalized()
	var movement := heading * speed * delta
```

`angle_to()` measures the signed turn needed. `clampf()` limits it to the angular speed multiplied by elapsed frame time. `rotated()` applies the turn; `normalized()` keeps heading at length one, so it does not accidentally change movement speed.

Multiplying both rotation and movement by `delta` makes the behavior similar across frame rates. At 60 FPS, an enemy can turn about 1.25 degrees in one frame.

The first heading points toward the lantern. It initializes on the first movement update because Main sets the spawn position after adding the node. To see slow steering, sidestep an enemy already approaching; walking straight away does not require it to turn.

## A curved path needs a real contact check

Distance alone no longer tells us whether an enemy will hit: it could pass beside the lantern. The helper checks the movement segment against the contact circle:

[enemy.gd, excerpt](https://github.com/pelletiermaxime/little-last-light/blob/milestone-6/enemy.gd#L54)

```gdscript
func _first_contact_fraction(movement: Vector2) -> float:
	# Intersect this frame's movement segment with the contact circle. Checking
	# only the endpoint could skip right through the lantern on a long frame.
	var entry := Geometry2D.segment_intersects_circle(
		global_position, global_position + movement,
		target.global_position, CONTACT_DISTANCE
	)
	return entry if entry >= 0.0 else 1.0
```

A hit returns the fraction of movement before contact. A miss becomes 1, so the enemy completes its step. Damage applies only to the part of the frame after arrival. This avoids both missed crossings and damage from a nearby pass that never touches.

This is a geometric segment check, not an Area2D conversion or a full continuous simulation of both moving bodies.

## Other controls included in M6

- Pause freezes movement, combat, time, and income. Its UI keeps processing so Resume works.
- End Run uses the same banking and saving path as death, then returns to preparation.
- Reset Layout refunds purchased turrets and restores the free starter.
- Desktop preparation gains Quit Game, which shares normal window-close saving.
- Desktop startup is maximized.

The important distinction is that pause leaves the phase RUNNING; preparation is a different phase. Pausing cannot unlock construction or refunds.

## Try it and understand the limitation

Run past an enemy and watch its eyes and curved pursuit. Try baiting it through turret coverage rather than only running away.

At the chosen slow turn rate, an enemy that overshoots can orbit a nearby stationary lantern. A 20-second diagnostic reproduced this. Fresh enemies still approach and hit stationary targets; guaranteed recapture after a dodge remains future tuning.

Tests check angular limits, recovery at distance, trajectories at 30/60/144 FPS, escape speed, real contact, near misses, and fresh approaches. Separate checks cover pause, End Run, refund safety, and save/reopen.

## Full source when you need it

Read [enemy.gd](https://github.com/pelletiermaxime/little-last-light/blob/milestone-6/enemy.gd), [pause_screen.gd](https://github.com/pelletiermaxime/little-last-light/blob/milestone-6/pause_screen.gd), [build_controller.gd](https://github.com/pelletiermaxime/little-last-light/blob/milestone-6/build_controller.gd), and [tests/check_enemy_movement.gd](https://github.com/pelletiermaxime/little-last-light/blob/milestone-6/tests/check_enemy_movement.gd). The shorter feature references are [pause](pause-screen.md) and [layout refunds](reset-layout.md).
