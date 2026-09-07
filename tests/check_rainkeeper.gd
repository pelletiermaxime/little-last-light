extends SceneTree

const BOSS = preload("res://rainkeeper.gd")


func _initialize() -> void:
	call_deferred("check")


func check() -> void:
	ProjectSettings.set_setting("leaderboard/api_url", "")
	var scene = load("res://main.tscn").instantiate()
	var path := "/tmp/lll-rainkeeper-check-%d.json" % OS.get_process_id()
	scene.save_path = path
	root.add_child(scene)
	current_scene = scene
	scene.start_run()
	scene.set_process(false)
	scene.lantern.set_process(false)
	scene._set_turrets_active(false)
	scene.lantern.health = 1000.0
	var hud = scene.get_node("GameHUD")
	hud.set_process(false)
	scene.lantern.elapsed = 599.99
	scene._process(0.001)
	assert(get_nodes_in_group("rainkeepers").is_empty(), "No early arrival")
	var drencher = get_nodes_in_group("bosses")[0]
	drencher.set_process(false)
	drencher.trail.set_process(false)
	drencher.trail.leave_puddle(Vector2(20, 20))
	scene.lantern.elapsed = 600.0
	scene._process(0.001)
	scene._process(0.001)
	assert(get_nodes_in_group("rainkeepers").size() == 1, "Normal runs spawn exactly one Rainkeeper at ten minutes")
	assert(not drencher.is_queued_for_deletion() and not drencher.trail.puddles.is_empty())
	var rain = get_nodes_in_group("rainkeepers")[0]
	rain.set_process(false)
	hud.refresh()
	assert(hud.boss_warning.text.begins_with("THE RAINKEEPER"), "New encounter takes priority over a surviving Drencher")
	rain.take_damage(100)
	assert(rain.health == 900)
	rain._process(3.0)
	var locked: Vector2 = rain.mark
	var hp: float = scene.lantern.health
	rain._process(BOSS.POOL_WARNING)
	assert(scene.lantern.health == hp, "Warning boundary is harmless")
	rain._process(0.5)
	assert(is_equal_approx(scene.lantern.health, hp - 4.0))
	scene.lantern.position = locked + Vector2(150, 0)
	assert(rain.rain_pools[0].point == locked)
	rain._process(rain.remaining)
	assert(rain.rain_pools.size() == 2)
	assert(is_equal_approx(scene.lantern.health, hp - 4.0))
	scene.lantern.position = locked
	rain._process(0.1)
	assert(is_equal_approx(scene.lantern.health, hp - 4.8), "Overlapping pools do not multiply damage")
	scene.lantern.position = locked + Vector2(150, 0)
	rain._process(rain.remaining)
	assert(rain.mark == scene.lantern.position, "Every strike locks a new position")
	scene.lantern.position += Vector2(150, 0)
	rain._process(rain.remaining)
	assert(rain.rain_pools.size() == 3)
	rain._process(rain.remaining)
	assert(rain.attack == BOSS.Attack.RECOVERY)
	assert((BOSS.POOL_RADIUS + 10.0) / scene.lantern.move_speed < BOSS.POOL_WARNING - 0.3)
	rain.position = Vector2(60, 60)
	var before: Vector2 = rain.position
	rain.apply_slow(0.5, 10.0)
	rain._process(1.0)
	assert(is_equal_approx(rain.position.distance_to(before), 58.5))
	rain._process(rain.remaining)
	assert(rain.attack == BOSS.Attack.WARNING)
	# Pool expiry remains exact on long frames, including recovery.
	rain._tick_rain(BOSS.POOL_DURATION)
	assert(rain.rain_pools.is_empty())
	rain.set_process(true)
	paused = true
	var clock: float = rain.remaining
	await process_frame
	await process_frame
	assert(rain.remaining == clock)
	paused = false
	rain.set_process(false)
	# Isolate targeting and the Rainkeeper defeat message from earlier enemies.
	for enemy in get_nodes_in_group("enemies"):
		if enemy != rain:
			enemy.remove_from_group("enemies")
			enemy.queue_free()
	var turret = scene.get_node("Turret")
	turret.position = rain.position + Vector2(60, 0)
	turret._process(0.01)
	assert(rain.health < 900)
	rain.take_damage(10000)
	assert(rain.rain_pools.is_empty())
	hud.refresh()
	assert(hud.boss_text.text == "THE RAINKEEPER DEFEATED")
	assert(scene.phase == scene.Phase.RUNNING, "Rainkeeper defeat does not win the run")
	await process_frame
	scene.update_rainkeeper_encounter()
	assert(get_nodes_in_group("rainkeepers").is_empty(), "No respawn after defeat")
	scene.end_run(true)
	scene.continue_to_preparation()
	scene.start_run()
	assert(not scene.rainkeeper_spawned)
	scene._set_turrets_active(false)
	scene.lantern.elapsed = 600.0
	scene.update_rainkeeper_encounter()
	assert(get_nodes_in_group("rainkeepers").size() == 1, "Restart resets arrival")
	scene.lantern.elapsed = 900.0
	scene.update_final_encounter()
	hud.refresh()
	assert(hud.boss_warning.text.begins_with("THE SNUFFER"))
	assert(get_nodes_in_group("rainkeepers").size() == 1)
	scene._on_final_boss_defeated()
	assert(scene.phase == scene.Phase.RESULTS and scene.last_run.victory)
	assert(get_nodes_in_group("rainkeepers").is_empty())
	assert(get_nodes_in_group("hazards").is_empty())
	scene.free()
	DirAccess.remove_absolute(path)
	print("PASS: ten-minute arrival, retained Drencher, HUD priority, three strikes, warning/expiry/overlap, slow, pause, targeting, defeat, restart and final victory")
	quit()
