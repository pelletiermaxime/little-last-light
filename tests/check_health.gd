extends SceneTree

var deaths: int = 0

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var scene = load("res://main.tscn").instantiate()
	var test_path := "/tmp/little-last-light-health-%d.json" % OS.get_process_id()
	scene.save_path = test_path
	root.add_child(scene)
	current_scene = scene
	scene.continue_to_preparation()
	scene.start_run()
	var lantern = scene.get_node("Lantern")
	scene.set_process(false)
	lantern.set_process(false)
	scene.get_node("Turret").set_process(false)
	lantern.died.connect(func(): deaths += 1)
	scene.encounters._spawn_enemy()
	var enemy = get_nodes_in_group("enemies")[0]
	enemy.set_process(false)
	# Approach naturally from many angles; teleporting into contact misses rounding bugs.
	var missed_contacts := 0
	for angle in range(0, 360, 5):
		lantern.health = 100.0
		# Each angle represents a fresh approach, not a teleport with old steering.
		enemy.heading = Vector2.ZERO
		enemy.global_position = lantern.global_position + Vector2.from_angle(deg_to_rad(angle)) * 100.0
		for frame in range(180):
			enemy._process(1.0 / 60.0)
		if lantern.health >= 99.0:
			missed_contacts += 1
	if missed_contacts > 0:
		printerr("FAIL: enemies reached the edge but did not damage the lantern from %d / 72 angles" % missed_contacts)
		quit(1)
		return
	lantern.health = 100.0
	enemy.heading = Vector2.ZERO
	enemy.global_position = lantern.global_position + Vector2(100, 0)
	enemy._process(0.5)
	assert(lantern.health == 100.0, "No damage outside contact range")
	enemy.global_position = lantern.global_position
	enemy._process(0.5)
	assert(lantern.health == 92.5, "Contact damage uses elapsed time")
	lantern.take_damage(-10)
	assert(lantern.health == 92.5, "Negative damage ignored")
	lantern.set_process(true)
	scene.set_process(true)
	lantern.take_damage(1000)
	lantern.take_damage(1000)
	assert(lantern.health == 0 and deaths == 1, "Death emits once and health clamps")
	assert(scene.phase == scene.Phase.RESULTS and not lantern.running, "Death opens results")
	var energy: float = lantern.energy
	var progress: float = scene.encounters.spawn_progress
	await process_frame
	await process_frame
	assert(lantern.energy == energy and scene.encounters.spawn_progress == progress, "Run freezes")
	scene.get_node("ResultsScreen").continue_button.pressed.emit()
	scene.get_node("BuildController").start_button.pressed.emit()
	assert(not paused and scene.phase == scene.Phase.RUNNING, "Start begins a fresh run")
	assert(current_scene.lantern.health == current_scene.lantern.max_health, "Restart restores health")
	assert(current_scene.lantern.energy < 1.0 and get_nodes_in_group("enemies").is_empty(), "Fresh run state")
	print("PASS: 72 contact approaches, damage, death, preparation freeze, fresh run")
	scene.free()
	DirAccess.remove_absolute(test_path)
	quit()
