extends SceneTree


func _initialize() -> void:
	call_deferred("check")


func check() -> void:
	root.get_node("GameAudio").muted = true
	var scene = load("res://main.tscn").instantiate()
	var path := "/tmp/lll-desperation-%d.json" % OS.get_process_id()
	scene.save_path = path
	root.add_child(scene)
	scene.get_node("GameHUD").leaderboard.api_url = ""
	scene.start_run()
	scene.set_process(false)
	scene.lantern.set_process(false)
	scene.lantern.set_physics_process(false)
	scene._set_turrets_active(false)
	scene.lantern.elapsed = 900
	scene.encounters.update_final_encounter()
	var boss = get_nodes_in_group("final_bosses")[0]
	boss.set_process(false)
	boss._process(3.0)
	boss._begin_recovery()
	boss.position = Vector2(100, 200)
	boss.drift_destination = Vector2(800, 200)
	assert(boss.remaining == 1.8)
	boss._process(0.25)
	var normal_distance: float = boss.position.x - 100
	assert(is_equal_approx(normal_distance, 21.25))
	boss.take_damage(799)
	assert(boss.health == 401 and boss.enraged and not boss.desperate)
	boss.take_damage(1)
	assert(boss.health == 400 and boss.desperate and boss.remaining == 1.2)
	assert(boss.attack_caption().contains("DESPERATION"))
	var before: Vector2 = boss.position
	boss._process(0.25)
	assert(is_equal_approx(boss.position.distance_to(before), normal_distance * 2.5))
	var announcement: float = boss.desperation_announcement
	boss.take_damage(1)
	assert(boss.desperation_announcement == announcement, "Later hits do not restart the phase announcement")
	scene.get_node("PauseScreen").pause()
	boss.set_process(true)
	before = boss.position
	await process_frame
	await process_frame
	assert(boss.position == before and boss.desperation_announcement == announcement)
	scene.get_node("PauseScreen").resume()
	boss.set_process(false)
	boss.volley_next = true
	boss._process(boss.remaining)
	assert(boss.remaining == 1.0 and boss.attack == boss.Attack.VOLLEY_WARNING, "Full warning survives phase change")
	before = boss.position
	boss._process(0.5)
	assert(boss.position == before, "Still stationary while warning")
	boss._process(0.5)
	assert(boss.attack == boss.Attack.VOLLEY and get_nodes_in_group("enemy_projectiles").size() == 5)
	assert(boss.position == before and is_equal_approx(get_nodes_in_group("enemy_projectiles")[2].velocity.length(), 215.0), "Bullet speed is unchanged")
	boss._begin_recovery()
	assert(boss.remaining == 1.2)
	if "--capture-desperation" in OS.get_cmdline_user_args():
		scene.get_node("GameHUD").refresh()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/lll-desperation.png")
	boss._process(3.0)
	assert(not boss.attack_caption().contains("DESPERATION"), "Attack instructions return after the announcement")
	scene.end_run()
	scene.continue_to_preparation()
	scene.start_run()
	scene.lantern.elapsed = 900
	scene.encounters.update_final_encounter()
	boss = get_nodes_in_group("final_bosses")[0]
	assert(not boss.desperate and boss.desperation_announcement == 0.0)
	boss._process(3.0)
	boss._begin_recovery()
	boss.position = Vector2(100, 200)
	boss.drift_destination = Vector2(800, 200)
	boss.apply_slow(0.4, 0.5)
	boss._process(1.0)
	assert(is_equal_approx(boss.position.x, 172.25), "Pulse uses half boss susceptibility and splits slow expiry movement")
	assert(boss.slow_remaining == 0.0 and is_equal_approx(boss.remaining, 0.8), "Slow changes movement but not attack clocks")
	var hp: float = scene.lantern.health
	scene.lantern.take_projectile_damage(12)
	assert(scene.lantern.health == hp - 12, "Droplets deal their full damage without ward absorption")
	boss.take_damage(9999)
	assert(scene.last_run.victory and not boss.desperate, "A killing blow does not trigger a new phase")
	scene.free()
	await process_frame
	DirAccess.remove_absolute(path)
	print("PASS: exact third-health threshold, 2.5x movement, recovery timing, one-time announcement, pause, full warnings, stationary shooting, unchanged bullet speed, reset and death")
	quit()
