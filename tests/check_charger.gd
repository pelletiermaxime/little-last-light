extends SceneTree

var failures := 0
var scene: Node2D
var path := "/tmp/little-last-light-charger-%d.json" % OS.get_process_id()


func _initialize() -> void:
	call_deferred("check")


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func fixture() -> Node2D:
	scene._clear_enemies()
	var enemy = scene.encounters.CHARGER_SCENE.instantiate()
	enemy.target = scene.lantern
	enemy.max_health = 4.0
	scene.add_child(enemy)
	enemy.position = Vector2(100, 300)
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	scene.lantern.position = Vector2(250, 300)
	scene.lantern.health = 100.0
	return enemy


func check() -> void:
	scene = load("res://main.tscn").instantiate()
	scene.save_path = path
	root.add_child(scene)
	await process_frame
	scene.continue_to_preparation()
	scene.start_run()
	scene.set_process(false)
	scene.lantern.set_process(false)
	scene.lantern.set_physics_process(false)
	scene._set_turrets_active(false)
	var enemy = fixture()
	expect(enemy.approach_speed < scene.lantern.move_speed, "Only the telegraphed charge outruns the lantern")
	scene.lantern.position = Vector2(500, 300)
	enemy._process(0.5)
	expect(enemy.position.is_equal_approx(Vector2(130, 300)) and enemy.state == enemy.State.APPROACH, "Far charger approaches slowly")
	enemy = fixture()
	enemy._process(0.1)
	expect(enemy.state == enemy.State.WARNING and enemy.position == Vector2(100, 300), "Nearby charger stops to warn")
	scene.lantern.position = Vector2(100, 500)
	enemy._process(0.4)
	expect(is_equal_approx(Vector2.RIGHT.angle_to(enemy.heading), deg_to_rad(36.0)), "Early warning tracks at the limited 90-degree turn rate")
	var locked_heading: Vector2 = enemy.heading
	scene.lantern.position = Vector2(0, 500)
	enemy._process(0.3)
	expect(enemy.state == enemy.State.WARNING and enemy.position == Vector2(100, 300), "Warning allows the full reaction time")
	expect(enemy.heading.is_equal_approx(locked_heading), "Final warning stays locked after another dodge")
	enemy._process(0.2)
	expect(enemy.heading.is_equal_approx(locked_heading) and enemy.position.x > 100, "Charge follows final locked aim")
	enemy._process(0.7)
	expect(enemy.state == enemy.State.RECOVERY and scene.lantern.health == 100.0, "A dodged charge ends in harmless recovery")
	var resting: Vector2 = enemy.position
	enemy._process(0.6)
	expect(enemy.position == resting and enemy.state == enemy.State.RECOVERY, "Recovery exposes a stationary target")
	enemy._process(0.4)
	expect(enemy.state == enemy.State.APPROACH, "Recovery eventually allows another approach")
	# Swept collision must hit even when a single frame crosses the lantern.
	enemy = fixture()
	enemy._process(0.1)
	enemy._process(1.7)
	expect(is_equal_approx(scene.lantern.health, 88.0), "Long-frame charge deals exactly one 12-health hit")
	expect(enemy.position.is_equal_approx(Vector2(230, 300)), "Hit stops at contact rather than tunneling through")
	enemy._process(0.2)
	expect(scene.lantern.health == 88.0, "Recovery does not deal repeated contact damage")
	# Spawned on top of the lantern still gives a warning and cannot tunnel away.
	enemy = fixture()
	enemy.position = scene.lantern.position
	enemy._process(0.5)
	expect(scene.lantern.health == 100.0, "Warning itself is harmless even while touching")
	enemy._process(0.8)
	expect(scene.lantern.health == 88.0 and enemy.position == scene.lantern.position, "Overlapping charge hits once in place")
	for fps in [30, 60, 144]:
		enemy = fixture()
		enemy._process(0.5)
		scene.lantern.position = Vector2(250, 500)
		for frame in range(fps * 2):
			enemy._process(1.0 / fps)
		expect(enemy.position.distance_to(Vector2(366, 300)) < 0.1, "Charge distance is consistent across frame rates")
		expect(scene.lantern.health == 100.0, "Sidestep avoids damage across frame rates")
		enemy = fixture()
		for frame in range(fps * 2):
			enemy._process(1.0 / fps)
		expect(scene.lantern.health == 88.0, "Charge damage is independent of frame rate")
	# Crossing the tracking/lock boundary on one frame must not add extra tracking.
	enemy = fixture()
	enemy._process(0.1)
	scene.lantern.position = Vector2(100, 500)
	enemy._process(0.7)
	expect(is_equal_approx(Vector2.RIGHT.angle_to(enemy.heading), deg_to_rad(36.0)), "Long warning frame only turns during its tracking portion")
	expect(enemy.state == enemy.State.WARNING, "Long frame retains the remaining locked warning")
	# Turrets use the existing enemies group and take_damage contract.
	enemy = fixture()
	var turret = scene.get_node("Turret")
	turret.position = enemy.position + Vector2(40, 0)
	turret.cooldown = 0.0
	turret._process(0.1)
	expect(is_equal_approx(enemy.health, 2.5), "Existing turret can target and damage a charger")
	enemy.take_damage(3.0)
	expect(enemy.is_queued_for_deletion(), "Chargers die through the shared damage method")
	# The actual paused scene tree must freeze each state, then resume processing.
	for phase in range(4):
		enemy = fixture()
		enemy.state = phase
		enemy.state_remaining = 2.0
		enemy.heading = Vector2.RIGHT
		scene.lantern.position = Vector2(1000, 1000)
		enemy.process_mode = Node.PROCESS_MODE_INHERIT
		var screen = scene.get_node("PauseScreen")
		screen.pause()
		var before: Array = [enemy.position, enemy.state, enemy.state_remaining, scene.lantern.health]
		for frame in range(4):
			await process_frame
		expect(before == [enemy.position, enemy.state, enemy.state_remaining, scene.lantern.health], "Pause freezes every charger state")
		screen.resume()
		for frame in range(4):
			await process_frame
		expect(before != [enemy.position, enemy.state, enemy.state_remaining, scene.lantern.health], "Resume restores charger processing")
	# Sparse schedule is independent of brightness and restarts with the run.
	scene._clear_enemies()
	scene.lantern.elapsed = 19.9
	scene._process(0.0)
	expect(get_nodes_in_group("chargers").is_empty(), "No charger before 20 seconds")
	scene.lantern.elapsed = 20.0
	scene._process(0.0)
	expect(get_nodes_in_group("chargers").size() == 1, "First charger appears at 20 seconds")
	expect(scene.encounters.current_charger_interval() == 4.0, "Charger cadence starts at four seconds")
	scene.lantern.brightness = 2
	scene.lantern.elapsed = 23.9
	scene._process(0.0)
	expect(get_nodes_in_group("chargers").size() == 1, "High brightness does not accelerate charger cadence")
	for attempt in range(10):
		scene.encounters._spawn_charger()
	expect(get_nodes_in_group("chargers").size() == 8, "At most eight chargers coexist")
	scene.lantern.elapsed = 70.0
	expect(is_equal_approx(scene.encounters.current_charger_interval(), 6.5), "Gathering uses half the pressure spawn frequency")
	for elapsed in [140.0, 620.0]:
		scene.lantern.elapsed = elapsed
		expect(is_equal_approx(scene.encounters.current_charger_interval(), 2.5 - 0.5 * clampf((elapsed - 120.0) / 480.0, 0.0, 1.0)), "Pressure accelerates toward a two-second late cadence")
	scene.end_run(true)
	expect(get_nodes_in_group("chargers").is_empty(), "End Run clears charger membership immediately")
	scene.encounters._spawn_charger()
	expect(get_nodes_in_group("chargers").is_empty(), "Preparation cannot spawn chargers")
	scene.continue_to_preparation()
	scene.start_run()
	expect(scene.encounters.next_charger_time == 20.0, "Fresh run resets introduction time")
	enemy = fixture()
	scene.lantern.health = 10.0
	enemy._process(2.0)
	expect(scene.phase == scene.Phase.RESULTS, "Fatal charge uses normal defeat cleanup")
	scene.free()
	DirAccess.remove_absolute(path)
	if failures == 0:
		print("PASS: charger approach, tracking then locked warning, dodge, recovery, swept single hit, frame rates, turret damage, pause, spawn ramp, cleanup")
	quit(1 if failures else 0)
