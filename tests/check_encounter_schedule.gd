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
	var path := "/tmp/little-last-light-schedule-%d.json" % OS.get_process_id()
	scene.save_path = path
	root.add_child(scene)
	scene.start_run()
	scene.set_process(false)
	scene._set_turrets_active(false)
	var lantern = scene.lantern
	lantern.set_process(false)
	lantern.set_physics_process(false)
	var schedule = scene.encounters.ENCOUNTER_SCHEDULE
	for base in [0.0, 60.0, 240.0, 840.0]:
		expect(schedule.period(base + 19.99) == "Gathering", "Gathering boundary")
		expect(schedule.chargers_enabled(base + 20.0), "Pressure begins with chargers")
		expect(schedule.period(base + 39.99) == "Pressure", "Full pressure duration")
		expect(schedule.chargers_enabled(base + 40.0) == (base >= 300.0), "Recovery gains chargers only after five minutes")
		expect(schedule.pursuer_rate_multiplier(base + 40.0) >= 0.25 and schedule.pursuer_rate_multiplier(base + 40.0) <= 0.5, "Recovery stays below pressure while escalating")
	for time in [100.0, 299.0, 899.0]:
		scene.lantern.elapsed = time
		var previous := INF
		for brightness in range(3):
			lantern.brightness = brightness
			expect(scene.encounters.current_spawn_interval() < previous, "Brightness always increases pursuer pressure")
			previous = scene.encounters.current_spawn_interval()
	scene._clear_enemies()
	for time in [20.0, 40.0, 60.0, 80.0]:
		lantern.elapsed = time
		scene._process(0.0)
		var expected := 3 if time == 80.0 else (2 if time == 60.0 else 1)
		expect(get_nodes_in_group("chargers").size() == expected, "Gathering joins after minute one without accumulating a spawn burst")
	scene._clear_enemies()
	lantern.elapsed = 299.99
	scene._process(0.0)
	expect(not scene.encounters.boss_spawned, "Drencher does not arrive early")
	lantern.elapsed = 300.0
	scene._process(0.0)
	expect(scene.encounters.boss_spawned and get_nodes_in_group("bosses").size() == 1, "Drencher preserved at five minutes")
	scene._clear_enemies()
	lantern.elapsed = 900.0
	scene.encounters.spawn_progress = 1.0
	scene._process(1.0)
	scene.encounters._spawn_charger()
	expect(get_nodes_in_group("final_bosses").size() == 1 and get_nodes_in_group("enemies").size() >= 3 and scene.encounters.current_spawn_interval() < INF, "Final boss joins continuing ordinary pressure")
	scene.free()
	DirAccess.remove_absolute(path)
	if failures == 0:
		print("PASS: encounter boundaries, brightness pressure, charger pacing and boss arrivals")
	quit(1 if failures else 0)
