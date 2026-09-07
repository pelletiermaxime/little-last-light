extends SceneTree

const BOSS = preload("res://prototype_boss.gd")
var scene: Node2D


func _initialize() -> void:
	call_deferred("check")


func spawn_candidate(kind: int) -> Node2D:
	scene.prototype_boss_kind = kind
	scene.prototype_boss_time = 60.0
	scene.start_run()
	scene.set_process(false)
	scene.lantern.set_process(false)
	scene._set_turrets_active(false)
	scene.lantern.health = 1000.0
	scene.lantern.elapsed = 59.99
	scene.update_prototype_encounter()
	assert(get_nodes_in_group("prototype_bosses").is_empty())
	scene.lantern.elapsed = 60.0
	scene.update_prototype_encounter()
	scene.update_prototype_encounter()
	assert(get_nodes_in_group("prototype_bosses").size() == 1)
	var boss = get_nodes_in_group("prototype_bosses")[0]
	boss.set_process(false)
	boss.take_damage(100)
	assert(boss.health == 900, "Arrival is protected")
	boss._process(3.0)
	assert(boss.arrival_remaining == 0)
	return boss


func finish_candidate() -> void:
	scene.end_run(true)
	assert(get_nodes_in_group("hazards").is_empty())
	assert(get_nodes_in_group("prototype_bosses").is_empty())
	scene.continue_to_preparation()


func check() -> void:
	ProjectSettings.set_setting("leaderboard/api_url", "")
	scene = load("res://main.tscn").instantiate()
	scene.save_path = "/tmp/lll-prototypes-check-%d.json" % OS.get_process_id()
	root.add_child(scene)
	current_scene = scene
	var hud = scene.get_node("GameHUD")
	hud.set_process(false)
	var rain = spawn_candidate(BOSS.Kind.RAINKEEPER)
	var locked: Vector2 = rain.mark
	var hp: float = scene.lantern.health
	rain._process(BOSS.POOL_WARNING)
	assert(scene.lantern.health == hp, "Warning boundary deals no damage")
	rain._process(0.5)
	assert(is_equal_approx(scene.lantern.health, hp - 4.0))
	scene.lantern.position = locked + Vector2(150, 0)
	assert(rain.rain_pools[0].point == locked, "Landed pools never track the player")
	# Second mark was locked during the first half-second; escape both marks.
	rain._process(rain.remaining)
	assert(rain.rain_pools.size() == 2)
	assert(is_equal_approx(scene.lantern.health, hp - 4.0), "Leaving the footprint avoids damage")
	# Overlapping pools are one exposure, not two independent hits.
	scene.lantern.position = locked
	rain._process(0.1)
	assert(is_equal_approx(scene.lantern.health, hp - 4.8))
	scene.lantern.position = locked + Vector2(150, 0)
	rain._process(rain.remaining)
	assert(rain.mark == scene.lantern.position, "Each strike acquires a fresh fixed mark")
	scene.lantern.position += Vector2(150, 0)
	rain._process(rain.remaining)
	assert(rain.rain_pools.size() == 3, "Three lingering pools constrain the return route")
	rain._process(rain.remaining)
	assert(rain.attack == BOSS.Attack.RECOVERY)
	assert((BOSS.POOL_RADIUS + 10.0) / scene.lantern.move_speed < BOSS.POOL_WARNING - 0.3, "Center escape retains a reaction margin")
	# A slow affects movement but does not prolong the next warning.
	rain.position = Vector2(60, 60)
	var before: Vector2 = rain.position
	rain.apply_slow(0.5, 10.0)
	rain._process(1.0)
	assert(is_equal_approx(rain.position.distance_to(before), 58.5))
	rain._process(rain.remaining)
	assert(rain.attack == BOSS.Attack.WARNING)
	hud.refresh()
	assert(hud.boss_text.text.contains("THE RAINKEEPER"))
	# Real pause processing, not manual calls while paused.
	rain.set_process(true)
	paused = true
	var clock: float = rain.remaining
	await process_frame
	await process_frame
	assert(rain.remaining == clock)
	paused = false
	rain.set_process(false)
	# Automatic targeting sees the boss; defeat announces its own name.
	var turret = scene.get_node("Turret")
	turret.position = rain.position + Vector2(60, 0)
	turret._process(0.01)
	assert(rain.health < 900)
	rain.take_damage(10000)
	assert(rain.rain_pools.is_empty(), "Defeat clears lingering rain immediately")
	hud.refresh()
	assert(hud.boss_text.text == "THE RAINKEEPER DEFEATED")
	finish_candidate()
	await process_frame
	var tide = spawn_candidate(BOSS.Kind.TIDEKEEPER)
	assert(tide.front_warning >= 1.5)
	var axis: float = scene.lantern.position.x if tide.vertical_front else scene.lantern.position.y
	assert(absf(axis - tide.front_gap) / scene.lantern.move_speed < tide.front_warning)
	tide._process(tide.remaining)
	assert(tide.projectiles.size() > 0)
	for droplet in tide.projectiles:
		droplet.set_process(false)
		var across: float = droplet.position.x if tide.vertical_front else droplet.position.y
		assert(absf(across - tide.front_gap) >= BOSS.GAP_WIDTH / 2)
	# Whole front crosses a lantern placed at the gap without damage.
	scene.lantern.position = Vector2(tide.front_gap, tide.front_travel / 2) if tide.vertical_front else Vector2(tide.front_travel / 2, tide.front_gap)
	hp = scene.lantern.health
	for droplet in tide.projectiles:
		droplet._process(tide.remaining)
	assert(scene.lantern.health == hp)
	tide._process(tide.remaining + 2.0)
	assert(tide.attack == BOSS.Attack.WARNING and not tide.vertical_front, "Axes alternate after recovery")
	tide._process(tide.remaining)
	assert(not get_nodes_in_group("enemy_projectiles").is_empty())
	tide.front_arena_size += Vector2(1, 0)
	tide._process(0.01)
	assert(tide.attack == BOSS.Attack.RECOVERY and get_nodes_in_group("enemy_projectiles").is_empty(), "Resize clears a front whose gap may be cropped")
	tide._process(tide.remaining)
	tide._process(tide.remaining)
	tide.take_damage(10000)
	assert(get_nodes_in_group("enemy_projectiles").is_empty(), "Death clears owned projectiles immediately")
	finish_candidate()
	await process_frame
	var wick = spawn_candidate(BOSS.Kind.WICKWATCHER)
	wick.position = scene.lantern.position - Vector2(200, 0)
	scene.lantern.brightness = 2
	wick._process(1.0)
	assert(is_equal_approx(wick.charge, 0.42))
	scene.lantern.brightness = 0
	wick._process(1.0)
	assert(is_equal_approx(wick.charge, 0.07))
	wick.take_damage(1)
	assert(wick.health == 899, "Dimming does not grant immunity")
	scene.lantern.brightness = 1
	wick._process(1.0)
	assert(is_equal_approx(wick.charge, 0.25))
	scene.lantern.brightness = 2
	wick._process((1.0 - wick.charge) / 0.42)
	assert(wick.attack == BOSS.Attack.WARNING)
	var direction: Vector2 = wick.heading
	scene.lantern.brightness = 0
	scene.lantern.position += Vector2(0, 100)
	wick._process(1.2)
	assert(wick.heading == direction and wick.attack == BOSS.Attack.ACTIVE)
	hp = scene.lantern.health
	wick._process(0.75)
	assert(scene.lantern.health == hp, "Sidestep avoids the locked rush")
	# Swept contact cannot tunnel or repeatedly hit during recovery.
	wick.position = scene.lantern.position - Vector2(100, 0)
	wick.heading = Vector2.RIGHT
	wick.attack = BOSS.Attack.ACTIVE
	wick.remaining = 0.75
	wick._process(0.75)
	assert(scene.lantern.health == hp - 12)
	wick._process(1.0)
	assert(scene.lantern.health == hp - 12)
	# Final arrival coexists and keeps HUD/victory priority.
	scene.lantern.elapsed = 900
	scene.update_final_encounter()
	hud.refresh()
	assert(hud.boss_warning.text.begins_with("THE SNUFFER"))
	assert(get_nodes_in_group("prototype_bosses").size() == 1)
	scene._on_final_boss_defeated()
	assert(scene.phase == scene.Phase.RESULTS and scene.last_run.victory)
	assert(get_nodes_in_group("prototype_bosses").is_empty())
	var path: String = scene.save_path
	scene.free()
	DirAccess.remove_absolute(path)
	print("PASS: prototype timing, rain damage and escape, tide gap and cleanup, brightness charge, locked rush, targeting, pause, restart and final coexistence")
	quit()
