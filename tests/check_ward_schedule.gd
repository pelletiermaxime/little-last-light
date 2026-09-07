extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("check")


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func check() -> void:
	var scene = load("res://main.tscn").instantiate()
	var path := "/tmp/little-last-light-ward-%d.json" % OS.get_process_id()
	scene.save_path = path
	root.add_child(scene)
	scene.start_run()
	scene.set_process(false)
	scene._set_turrets_active(false)
	var lantern = scene.lantern
	lantern.set_process(false)
	lantern.set_physics_process(false)
	for fps in [30, 60, 144]:
		lantern.reset_ward()
		for frame in range(fps):
			lantern.update_ward(1.0 / fps, false)
		expect(not lantern.ward_active(), "No protection before 1.25 seconds")
		for frame in range(fps * 3):
			lantern.update_ward(1.0 / fps, false)
		expect(is_equal_approx(lantern.ward_charge, 8.0), "Formation and charge independent of frame rate")
	lantern.health = 25.0
	lantern.take_damage(3.0)
	expect(lantern.health == 25.0 and lantern.ward_charge == 5.0, "Ward absorbs a small leak")
	lantern.update_ward(2.9, false)
	expect(lantern.ward_charge == 5.0, "Absorbed damage delays recharge")
	lantern.update_ward(0.6, false)
	expect(is_equal_approx(lantern.ward_charge, 7.0), "Only time beyond delay recharges")
	lantern.take_damage(12.0)
	expect(lantern.health == 20.0 and lantern.ward_broken, "Charger-sized hit breaks ward and spills through")
	lantern.take_damage(-10)
	expect(lantern.health == 20.0 and lantern.ward_charge == 0.0, "Negative damage grants no protection")
	lantern.update_ward(0.1, true)
	lantern.update_ward(1.3, false)
	expect(not lantern.ward_active(), "Movement toggle cannot bypass recent damage delay")
	lantern.update_ward(4.0, false)
	expect(lantern.ward_charge == 8.0, "Settled ward recovers after safe delay")
	# Real input path: drift does not move, meaningful intent removes protection even at an edge.
	var origin: Vector2 = lantern.position
	Input.action_press("move_right", 0.15)
	lantern._physics_process(0.1)
	expect(lantern.position == origin and lantern.ward_charge == 8.0, "Controller drift stays inside shared movement deadzone")
	Input.action_press("move_right", 1.0)
	lantern._physics_process(0.1)
	Input.action_release("move_right")
	expect(lantern.position.x > origin.x and lantern.ward_charge == 0.0, "Movement removes entire reserve")
	for attempt in range(10):
		lantern.update_ward(0.1, true)
		lantern.update_ward(1.25, false)
	expect(lantern.ward_charge == 0.0, "Repeated exact formation toggles never refill")
	lantern.update_ward(2.0, false)
	var trail = load("res://water_trail.gd").new()
	trail.target = lantern
	scene.add_child(trail)
	trail.set_process(false)
	trail.leave_puddle(lantern.global_position)
	trail._process(2.6)
	expect(is_equal_approx(lantern.health, 12.0) and lantern.ward_charge == 0.0, "Two seconds of active puddle exceeds full ward by eight HP")
	lantern.update_ward(1.0, true)
	lantern.position += Vector2(100, 0)
	trail._process(1.0)
	expect(is_equal_approx(lantern.health, 12.0), "Relocating escapes puddle exposure")
	for stage in [0.5, 4.0, 8.0]:
		lantern.reset_ward()
		lantern.update_ward(stage, false)
		if stage == 8.0:
			lantern.take_damage(8.0)
		lantern.set_physics_process(true)
		scene.get_node("PauseScreen").pause()
		var before: Array = [lantern.ward_settle_time, lantern.ward_charge, lantern.ward_damage_delay]
		for frame in range(4):
			await process_frame
		expect(before == [lantern.ward_settle_time, lantern.ward_charge, lantern.ward_damage_delay], "Tree pause freezes formation and charge")
		scene.get_node("PauseScreen").resume()
		lantern.set_physics_process(false)
	lantern.take_damage(1000)
	expect(not lantern.running and lantern.ward_charge == 0.0, "Defeat clears ward")
	scene.continue_to_preparation()
	scene.start_run()
	expect(lantern.ward_settle_time == 0.0 and lantern.ward_damage_delay == 0.0, "Restart clears all ward clocks")
	var schedule = scene.ENCOUNTER_SCHEDULE
	for base in [0.0, 60.0, 240.0, 840.0]:
		expect(schedule.period(base + 19.99) == "Gathering", "Gathering boundary")
		expect(schedule.chargers_enabled(base + 20.0), "Pressure begins with chargers")
		expect(schedule.period(base + 39.99) == "Pressure", "Full pressure duration")
		expect(not schedule.chargers_enabled(base + 40.0), "Recovery stops new chargers")
		expect(schedule.pursuer_rate_multiplier(base + 40.0) == 0.25, "Recovery quarters pursuer rate")
	for time in [100.0, 299.0, 899.0]:
		scene.lantern.elapsed = time
		var previous := INF
		for brightness in range(3):
			lantern.brightness = brightness
			expect(scene.current_spawn_interval() < previous, "Brightness always increases pursuer pressure")
			previous = scene.current_spawn_interval()
	scene._clear_enemies()
	for time in [20.0, 40.0, 60.0, 80.0]:
		lantern.elapsed = time
		scene._process(0.0)
		var expected := 2 if time == 80.0 else 1
		expect(get_nodes_in_group("chargers").size() == expected, "Pressure starts one charger; recovery and gathering accumulate no debt")
	scene._clear_enemies()
	lantern.elapsed = 299.99
	scene._process(0.0)
	expect(not scene.boss_spawned, "Drencher does not arrive early")
	lantern.elapsed = 300.0
	scene._process(0.0)
	expect(scene.boss_spawned and get_nodes_in_group("bosses").size() == 1, "Drencher preserved at five minutes")
	scene._clear_enemies()
	lantern.elapsed = 900.0
	scene.spawn_progress = 1.0
	scene._process(1.0)
	scene._spawn_charger()
	expect(get_nodes_in_group("enemies").is_empty() and scene.current_spawn_interval() == INF, "Final encounter owns ordinary spawn boundary")
	scene.free()
	DirAccess.remove_absolute(path)
	if failures == 0:
		print("PASS: ward frame rates, leaks, overflow, recharge, drift, toggles, puddle dodge, pause/reset and encounter boundaries")
	quit(1 if failures else 0)
