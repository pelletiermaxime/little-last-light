# Milestone 6: enemies you can dodge

Starting point: commit `5661c12`, after M5 and the publishing workflow. Approved milestone snapshot: tag `milestone-6`.

## Design decision

The lantern should stay much faster than enemies. Basic enemies should follow you, but commit to their travel direction enough that a sudden sidestep buys space. Future difficulty should come from enemies with different movement patterns, combinations of threats, and bosses that are harder to kill.

The long-term objective is to **reach a final boss at 15:00 and defeat it to win**. Reaching the timestamp alone is not a victory. The final boss, encounter schedule, victory screen, and associated rewards are future work; M6 does not spawn a boss or end the run at fifteen minutes. Early runs can still end quickly, with persistent preparation helping the player reach farther later.

This is our design direction, not a claim about how Vampire Survivors implements its enemies.

## What changed

| Behavior | Before M6 | M6 |
| --- | --- | --- |
| Enemy speed | 100 initially, plus 3 per elapsed second, capped at 320 | Constant 85 |
| Lantern speed | 220 | 220 |
| Direction changes | Immediately points at the lantern | Turns at most 75 degrees per second |
| Open-space retreat | Eventually impossible against faster arrivals | Lantern travels about 2.6 times faster |
| Enemy eyes | Fixed orientation | Face the current movement heading |

The intended threat is being surrounded or choosing a poor route through enemy groups. We accept that good movement may produce much longer runs. We are not adding a replacement timer that makes escape impossible.

Existing spawn-rate and enemy-health scaling remain temporary, unchanged tuning. This milestone does not balance fifteen minutes of play or implement the future enemy roster. Contact damage, turret damage and costs, brightness income, save schema, and arena size remain unchanged.

## Steering, step by step

An enemy now remembers a `heading`: a unit Vector2 that describes where it is currently moving. `desired` is the direction from the enemy to the lantern's latest position. These are deliberately different after a sudden dodge.

Each frame:

1. Work out the desired direction with `direction_to()`.
2. Measure the signed angle from heading to desired with `angle_to()`.
3. Limit that turn to `turn_speed * delta`.
4. Rotate heading by that limited angle and normalize it.
5. Move along heading at `speed * delta`.

`turn_speed` is measured in radians per second. `TAU` is one full turn; the default is `5.0 * PI / 12.0`, allowing 75 degrees per second: 1.25 degrees on a 60-FPS frame, or about 0.521 degrees on a 144-FPS frame. Turning 180 degrees requires at least 2.4 seconds rather than happening instantly. The target keeps moving, so an actual chase can take longer to line up.

This caps angular speed rather than applying a fixed per-frame interpolation amount. Both turning and movement use `delta`, keeping pursuit similar across frame rates. The curved trajectory is approximated by short movement segments, so different frame rates need not produce bit-identical positions.

The first heading is initialized on the first movement update, not in `_ready()`. Main currently sets the enemy's position after adding it to the scene; initializing earlier would point it from the wrong location. After that, heading is retained between frames. Losing the target or receiving a nonpositive delta skips movement safely.

Known limitation at the chosen 75 degrees/second: an enemy with an awkward heading after overshooting can orbit a nearby stationary lantern. The final regression run reproduced this over a 20-second simulation. Fresh enemies initialize their heading toward the lantern and still reach a stationary target from every tested approach. We retain the chosen slow steering for this milestone; guaranteed recapture after a dodge remains future tuning. The old arbitrary-heading capture assertion assumed faster steering and is no longer a promise of this design.

Godot provides the vector operations used here: [Vector2 documentation](https://docs.godotengine.org/en/stable/classes/class_vector2.html).

## Contact still has to be real

The old movement always pointed directly at the lantern, so distance divided by speed could tell us when contact occurred. That shortcut is no longer valid: an enemy can be close while moving sideways and miss completely.

`_first_contact_fraction()` asks Godot's built-in `Geometry2D.segment_intersects_circle()` whether this frame's actual movement crosses the lantern's contact circle. A value from 0 to 1 describes where along the movement it first touches; Godot returns -1 when it misses. Our helper converts a miss to 1, meaning complete the whole move with no contact time left.

If contact is reached, the enemy stops at that point and damage applies only for the remainder of the frame. For example, an enemy starting 100 pixels from the lantern at speed 100 reaches the 20-pixel contact boundary after 0.8 seconds. On a deliberately long two-second test step, only the remaining 1.2 seconds deal damage: 18 health at 15 damage per second.

This swept check prevents the enemy passing through the lantern between two endpoint checks. Existing overlap still deals damage immediately, with the small contact tolerance retained for floating-point rounding. The segment checks enemy movement against the lantern's current position; this is not a full continuous collision simulation of both moving bodies. It preserves our existing contact model while making curved pursuit safe to use.

No manual quadratic solver is needed: [Godot's segment/circle helper](https://docs.godotengine.org/en/4.4/classes/class_geometry2d.html#class-geometry2d-method-segment-intersects-circle) handles the intersection calculation. This remains a geometric contact test, not an Area2D physics-body conversion.

## Visible direction

The eyes are drawn slightly ahead along `heading`, with left/right offsets from its perpendicular vector. Their placement shows the same direction used for movement, rather than pointing at the target before the body has turned. Health bars stay upright because we rotate the drawing offsets instead of the whole node.

## Tests and playtest

The final validation covers nine Godot regression suites and five Python release-version tests. Earlier native renders verified the directional eyes and pause layout; final platform exports are handled by the publishing workflow. Tests and captures use isolated profiles rather than the player's real save.

`tests/check_enemy_movement.gd` checks initial heading, bounded turns, recovery after a reversal, curved sidesteps, normalized heading, 30/60/144-FPS consistency, open-space escape, long-frame contact, near misses, existing overlap, fresh-spawn contact from twelve approach angles, and unchanged enemy speed at and beyond 15:00. It uses an isolated temporary save.

The old difficulty test intentionally asserted that late enemies outran the lantern. M6 replaces that requirement with the opposite: retreat opens distance without damage. Its fractional-arrival damage assertion remains. The 72-angle health test now resets heading for each independent approach, because teleporting an existing enemy must not accidentally carry the previous trial's steering into a new trial. All the other contact, economy, saving, HUD, and controller regression checks remain relevant.

To playtest, start on Low brightness and move away from one enemy in open space. Then make a sharp side-step as another approaches, or pass alongside one with a little clearance. Watch its eyes and curved pursuit. Stop moving briefly to verify that enemies can still reach you. Compare the route you want to take with the areas your fixed turrets cover.

## Run and preparation controls included in M6

- Desktop starts maximized (`window/size/mode=2`), with the temporary resize workarounds removed.
- Escape, P, or Options opens the pause screen. Resume preserves the live run. End Run banks and saves earnings, clears enemies, unpauses, and returns to preparation with a RUN ENDED recap.
- Death and voluntary ending share `Main.end_run(voluntary)`. Its phase guard prevents double banking; the session-only `last_run.voluntary` field selects the recap heading without changing the save schema.
- Reset Layout refunds purchased turrets and restores the free starter. See [the refund lesson](reset-layout.md).
- Desktop preparation has Quit Game, sharing `Main.quit_game()` with normal window close. It saves before quitting; an ordinary write failure keeps the window open. The existing malformed-save protection still allows closing without overwriting that file. Browser builds hide this button.

The [pause lesson](pause-screen.md) preserves the full pause script. The `milestone-6` Git tag preserves every other file exactly as shipped, for example `git show milestone-6:main.gd`.

## Code snapshots

The complete changed enemy script and movement regression test are preserved below so later enemy types do not erase the learning reference. Main's tuning change is simply removing `ENEMY_SPEED_GAIN_PER_SECOND` and `MAX_ENEMY_SPEED`, with `current_enemy_speed()` now returning `BASE_ENEMY_SPEED` (85) for every spawn.


<details>
<summary>enemy.gd — complete M6 snapshot</summary>

```gdscript
extends Node2D

const CONTACT_DISTANCE: float = 20.0
const CONTACT_TOLERANCE: float = 0.1

@export var speed: float = 85.0
# 75 degrees per second: a half-turn takes 2.4 seconds.
@export var turn_speed: float = 5.0 * PI / 12.0
@export var contact_damage_per_second: float = 15.0
@export var max_health: float = 1.0

var health: float

var target: Node2D
var heading: Vector2 = Vector2.ZERO


func _ready() -> void:
	health = max_health
	add_to_group("enemies")
	queue_redraw()
	

func _process(delta: float) -> void:
	if not is_instance_valid(target) or delta <= 0.0:
		return

	var distance: float = global_position.distance_to(target.global_position)

	# Contact damage scales with time, so frame rate does not change its strength.
	# Movement can stop a fraction of a pixel outside the intended distance.
	if distance <= CONTACT_DISTANCE + CONTACT_TOLERANCE:
		target.take_damage(contact_damage_per_second * delta)
		return
	if speed <= 0.0:
		return

	var desired := global_position.direction_to(target.global_position)
	# Initialize on the first movement, after Main has set the spawn position.
	if heading.is_zero_approx():
		heading = desired
	var max_turn := maxf(0.0, turn_speed) * delta
	heading = heading.rotated(clampf(heading.angle_to(desired), -max_turn, max_turn)).normalized()
	var movement := heading * speed * delta
	var fraction := _first_contact_fraction(movement)
	global_position += movement * fraction
	# Only the part of the frame spent touching the lantern deals damage.
	# A curved approach may miss it entirely, even when it is very close.
	if fraction < 1.0:
		target.take_damage(contact_damage_per_second * delta * (1.0 - fraction))
	queue_redraw()


func _first_contact_fraction(movement: Vector2) -> float:
	# Intersect this frame's movement segment with the contact circle. Checking
	# only the endpoint could skip right through the lantern on a long frame.
	var entry := Geometry2D.segment_intersects_circle(
		global_position, global_position + movement,
		target.global_position, CONTACT_DISTANCE
	)
	return entry if entry >= 0.0 else 1.0


func take_damage(amount: float) -> void:
	if health <= 0.0 or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	if health <= 0.0:
		queue_free()
	queue_redraw()


func _draw() -> void:
	# Eyes face the direction of travel, making pursuit commitment visible.
	var forward := heading if not heading.is_zero_approx() else Vector2.UP
	var side := forward.orthogonal()
	draw_circle(Vector2.ZERO, 10.0, Color("#826caa"))
	draw_circle(forward * 4.0 - side * 3.0, 2.0, Color("#ffe0a3"))
	draw_circle(forward * 4.0 + side * 3.0, 2.0, Color("#ffe0a3"))
	if max_health > 1.0:
		draw_rect(Rect2(-12, -18, 24, 3), Color("#35414e"))
		draw_rect(Rect2(-12, -18, 24 * health / max_health, 3), Color("#efb17b"))
```

</details>

<details>
<summary>tests/check_enemy_movement.gd — complete M6 snapshot</summary>

```gdscript
extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("check")


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func check() -> void:
	var scene = load("res://main.tscn").instantiate()
	var path := "/tmp/little-last-light-steering-%d.json" % OS.get_process_id()
	scene.save_path = path
	root.add_child(scene)
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	scene.start_run()
	scene._set_turrets_active(false)
	var lantern = scene.lantern
	for elapsed in [0.0, 30.0, 300.0, 899.0, 900.0, 1800.0]:
		lantern.elapsed = elapsed
		expect(scene.current_enemy_speed() == 85.0, "Time never accelerates basic enemies")
		expect(lantern.move_speed > scene.current_enemy_speed() * 2.0, "Lantern has a large speed advantage")
	lantern.elapsed = 0.0
	scene._spawn_enemy()
	var enemy = get_nodes_in_group("enemies")[0]
	var default_turn_speed: float = enemy.turn_speed
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	lantern.position = Vector2(500, 300)
	enemy.position = Vector2(100, 300)
	enemy._process(0.1)
	expect(enemy.heading.is_equal_approx(Vector2.RIGHT), "First heading uses final spawn position")
	expect(enemy.position.is_equal_approx(Vector2(108.5, 300)), "Straight pursuit uses configured speed")
	# Abruptly cross behind it. Heading must keep some forward commitment.
	lantern.position = Vector2(-500, 300)
	enemy._process(0.1)
	expect(enemy.heading.x > 0.0, "Enemy does not instantly reverse toward a dodge")
	expect(absf(Vector2.RIGHT.angle_to(enemy.heading)) <= enemy.turn_speed * 0.1 + 0.0001, "Turning obeys the angular limit")
	for frame in range(240):
		enemy._process(1.0 / 60.0)
	expect(enemy.heading.dot(enemy.position.direction_to(lantern.position)) > 0.99, "Enemy eventually resumes pursuit")
	# Compare a sidestep across common frame rates, with a fixed target.
	var endpoints: Array[Vector2] = []
	for fps in [30, 60, 144]:
		enemy.position = Vector2(100, 300)
		enemy.heading = Vector2.RIGHT
		lantern.position = Vector2(100, -1000)
		for frame in range(fps):
			enemy._process(1.0 / fps)
		endpoints.append(enemy.position)
		expect(enemy.position.x > 108.0, "Sidestep produces a curved path rather than direct homing")
		expect(enemy.heading.is_normalized(), "Steering preserves unit heading and speed")
	expect(endpoints[0].distance_to(endpoints[2]) < 4.0, "30 and 144 FPS trajectories stay close")
	# Open space: player escapes, without needing enemies to miss real contact.
	for fps in [30, 60, 144]:
		lantern.health = 100.0
		lantern.position = Vector2(200, 300)
		enemy.position = Vector2(170, 300)
		enemy.heading = Vector2.RIGHT
		for frame in range(fps * 2):
			lantern.position.x += lantern.move_speed / fps
			enemy._process(1.0 / fps)
		expect(lantern.health == 100.0, "Retreat is safe across frame rates")
		expect(lantern.position.distance_to(enemy.position) > 260.0, "Retreat opens a substantial gap")
	# Keep a fixed heading to isolate swept contact geometry from steering.
	enemy.speed = 100.0
	enemy.turn_speed = 0.0
	lantern.position = Vector2(300, 300)
	lantern.health = 100.0
	enemy.position = Vector2(200, 300)
	enemy.heading = Vector2.RIGHT
	enemy._process(2.0)
	expect(enemy.position.is_equal_approx(Vector2(280, 300)), "Long frame stops at first contact instead of tunneling")
	expect(is_equal_approx(lantern.health, 82.0), "Only 1.2 seconds after arrival count as contact")
	lantern.health = 100.0
	enemy.position = Vector2(270, 300)
	enemy.heading = Vector2.UP
	enemy._process(0.5)
	expect(lantern.health == 100.0, "Nearby movement that misses the circle deals no damage")
	enemy.position = Vector2(200, 320.5)
	enemy.heading = Vector2.RIGHT
	enemy._process(2.0)
	expect(lantern.health == 100.0, "A close parallel pass does not create a false hit")
	enemy.position = lantern.position
	enemy._process(0.2)
	expect(is_equal_approx(lantern.health, 97.0), "Existing overlap still deals time-based damage")
	# Fresh pursuers face the target and must hit a stationary lantern.
	# After a dodge, slow steering can orbit a nearby target; see M6's limitations.
	enemy.speed = scene.current_enemy_speed()
	enemy.turn_speed = default_turn_speed
	for angle in range(0, 360, 30):
		lantern.health = 100.0
		enemy.position = lantern.position + Vector2.from_angle(deg_to_rad(angle)) * 50.0
		enemy.heading = Vector2.ZERO
		for frame in range(120):
			enemy._process(1.0 / 60.0)
		expect(lantern.health < 99.0, "Fresh pursuer reaches a stationary target from every approach")
	scene.free()
	DirAccess.remove_absolute(path)
	if failures == 0:
		print("PASS: fixed speed, steering commitment, curved pursuit, frame rates, escape, swept contact, stationary capture")
	quit(1 if failures else 0)
```

</details>

