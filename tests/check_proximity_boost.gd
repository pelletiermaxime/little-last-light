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
	var path := "/tmp/lll-boost-%d.json" % OS.get_process_id()
	scene.save_path = path
	root.add_child(scene)
	scene.set_process(false)
	var lantern = scene.lantern
	lantern.set_process(false)
	lantern.set_physics_process(false)
	var turret = scene.get_node("Turret")
	lantern.position = turret.position
	expect(not turret.in_boost_range(), "Preparation cannot boost turrets")
	scene.start_run()
	scene._set_turrets_active(false)
	lantern.position = Vector2(300, 300)
	turret.position = lantern.position + Vector2(110, 0)
	expect(turret.in_boost_range(), "Exact 110-pixel boundary is included immediately")
	turret.position.x += 0.1
	expect(not turret.in_boost_range(), "Outside the boundary is unboosted")
	turret.position = lantern.position + Vector2(80, 0)
	var second = scene.TURRET_SCENE.instantiate()
	scene.add_child(second)
	second.position = lantern.position + Vector2(-80, 0)
	second.process_mode = Node.PROCESS_MODE_DISABLED
	var pulse = scene.PULSE_TURRET_SCENE.instantiate()
	scene.add_child(pulse)
	pulse.position = lantern.position + Vector2(0, 80)
	pulse.process_mode = Node.PROCESS_MODE_DISABLED
	expect(turret.in_boost_range() and second.in_boost_range(), "Every nearby damage turret benefits")
	expect(not pulse.in_boost_range(), "Slow turrets are excluded")
	pulse.cooldown = 2.0
	pulse._process(0.5)
	expect(pulse.cooldown == 1.5, "Slow turret timing remains unchanged")
	scene.encounters._spawn_enemy()
	var enemy = get_nodes_in_group("enemies")[0]
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	enemy.position = turret.position + Vector2(40, 0)
	enemy.health = 100.0
	enemy.max_health = 100.0
	turret.cooldown = 0.0
	turret._process(0.0)
	expect(is_equal_approx(enemy.health, 98.5) and turret.boosted, "Boost fires 50% more damage and activates its visual")
	turret._process(0.9)
	expect(is_equal_approx(enemy.health, 98.5) and is_equal_approx(turret.cooldown, 0.15), "Boost advances 1.5 seconds of firing work per second")
	turret._process(0.11)
	expect(is_equal_approx(enemy.health, 97.0) and turret.fire_interval == 1.5, "Boost fires sooner without changing base upgrades")
	lantern.position = turret.position + Vector2(150, 0)
	turret._process(0.5)
	expect(not turret.boosted and is_equal_approx(turret.cooldown, 1.0), "Leaving range immediately restores normal cooldown progress")
	lantern.position = turret.position + Vector2(90, 0)
	Input.action_press("move_left")
	lantern._physics_process(0.1)
	Input.action_release("move_left")
	expect(turret.in_boost_range(), "Movement inside the aura keeps the boost")
	lantern._process(5.0)
	var hp: float = lantern.health
	lantern.take_damage(3.0)
	expect(lantern.health == hp - 3.0, "Standing near towers gives no damage absorption")
	turret.process_mode = Node.PROCESS_MODE_INHERIT
	turret._process(0.0)
	scene.get_node("PauseScreen").pause()
	var before: float = turret.cooldown
	for frame in range(4):
		await process_frame
	expect(turret.cooldown == before, "Pausing freezes boosted fire cycles")
	scene.get_node("PauseScreen").resume()
	scene.end_run(true)
	expect(not turret.boosted and not turret.in_boost_range(), "Ending clears boost and visuals")
	scene.continue_to_preparation()
	scene.start_run()
	expect(turret.cooldown == 0.0, "New runs start with a fresh fire cycle")
	scene.free()
	DirAccess.remove_absolute(path)
	if failures == 0:
		print("PASS: boost boundary, multiple towers, slow exclusion, actual shots, movement, full damage, pause and reset")
	quit(1 if failures else 0)
