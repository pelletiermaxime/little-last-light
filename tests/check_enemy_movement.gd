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
		expect(scene.encounters.current_enemy_speed() == 85.0, "Time never accelerates basic enemies")
		expect(lantern.move_speed > scene.encounters.current_enemy_speed() * 2.0, "Lantern has a large speed advantage")
	lantern.elapsed = 0.0
	scene.encounters._spawn_enemy()
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
	enemy.speed = scene.encounters.current_enemy_speed()
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
