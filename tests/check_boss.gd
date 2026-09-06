extends SceneTree


func _initialize() -> void:
	call_deferred("check")


func check() -> void:
	var scene = load("res://main.tscn").instantiate()
	var path := "/tmp/lll-boss-test-%d.json" % OS.get_process_id()
	scene.save_path = path
	root.add_child(scene)
	scene.start_run()
	scene.set_process(false)
	scene.lantern.set_process(false)
	scene._set_turrets_active(false)
	scene.lantern.elapsed = scene.BOSS_TIME - 0.1
	scene._process(0.01)
	assert(get_nodes_in_group("bosses").is_empty())
	scene.lantern.elapsed = scene.BOSS_TIME
	scene._process(0.01)
	assert(get_nodes_in_group("bosses").size() == 1)
	var boss = get_nodes_in_group("bosses")[0]
	boss.set_process(false)
	boss.trail.set_process(false)
	assert(boss.health == 700 and boss.speed == 78 and boss.contact_distance == 44)
	scene._process(0.01)
	assert(get_nodes_in_group("bosses").size() == 1)
	var start: Vector2 = boss.position
	boss._process(2.9)
	assert(boss.position == start and boss.trail.puddles.is_empty())
	boss._process(1.1)
	assert(boss.position.distance_to(start) > 60 and boss.trail.puddles.size() >= 2)
	# Test water timing without incidental movement/contact.
	var trail = boss.trail
	trail.puddles.clear()
	trail.leave_puddle(scene.lantern.position)
	trail.leave_puddle(scene.lantern.position)
	var hp: float = scene.lantern.health
	trail._process(0.6)
	assert(scene.lantern.health == hp)
	trail._process(0.5)
	assert(is_equal_approx(scene.lantern.health, hp - 4), "Overlap does not multiply water damage")
	scene.lantern.position += Vector2(200, 0)
	trail._process(8)
	assert(trail.puddles.is_empty())
	# Large body uses the same swept contact calculation with its own radius.
	boss.position = scene.lantern.position + Vector2(100, 0)
	boss.heading = Vector2.LEFT
	boss._process(1.0)
	assert(is_equal_approx(boss.position.distance_to(scene.lantern.position), 44))
	# Existing turrets can acquire the boss as a regular enemy.
	for enemy in get_nodes_in_group("enemies"):
		if enemy != boss:
			enemy.remove_from_group("enemies")
			enemy.queue_free()
	var turret = scene.get_node("Turret")
	turret.position = boss.position + Vector2(60, 0)
	turret._process(0.01)
	assert(boss.health == 699)
	scene.get_node("PauseScreen").pause()
	var age: float = trail.puddles[0].age
	boss.set_process(true)
	trail.set_process(true)
	await process_frame
	await process_frame
	assert(trail.puddles[0].age == age)
	scene.get_node("PauseScreen").resume()
	boss.set_process(false)
	trail.set_process(false)
	boss.take_damage(1000)
	assert(trail.is_queued_for_deletion())
	await process_frame
	scene._process(0.01)
	assert(get_nodes_in_group("bosses").is_empty() and scene.boss_spawned)
	scene.end_run()
	scene.continue_to_preparation()
	scene.start_run()
	assert(not scene.boss_spawned)
	scene.lantern.elapsed = scene.BOSS_TIME
	scene._process(0.01)
	assert(get_nodes_in_group("bosses").size() == 1)
	scene.get_node("PauseScreen").pause()
	scene.get_node("PauseScreen").end_run()
	assert(not paused and get_nodes_in_group("bosses").is_empty() and get_nodes_in_group("hazards").is_empty())
	scene.free()
	DirAccess.remove_absolute(path)
	print("PASS: timed boss, arrival, trail, damage, expiry, large contact, turret hits, pause, death and restart")
	quit()
