extends SceneTree

const DROPLET = preload("res://hazards/enemy_droplet.gd")


func _initialize() -> void:
	call_deferred("check")


func clear_projectiles() -> void:
	for droplet in get_nodes_in_group("enemy_projectiles"):
		droplet.retire()


func check() -> void:
	root.get_node("GameAudio").muted = true
	var scene = load("res://main.tscn").instantiate()
	scene.save_path = "/tmp/lll-droplet-%d.json" % OS.get_process_id()
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
	boss.position = Vector2(300, 300)
	scene.lantern.position = Vector2(500, 300)
	boss._process(3.99)
	assert(get_nodes_in_group("enemy_projectiles").is_empty(), "Arrival and full volley warning are harmless")
	boss._process(0.02)
	assert(get_nodes_in_group("enemy_projectiles").size() == 5)
	var first = get_nodes_in_group("enemy_projectiles")[2]
	assert(is_equal_approx(get_nodes_in_group("enemy_projectiles")[0].velocity.angle(), -0.28))
	assert(is_equal_approx(get_nodes_in_group("enemy_projectiles")[4].velocity.angle(), 0.28), "Five-shot fan retains the original angular spacing")
	var original_velocity: Vector2 = first.velocity
	scene.lantern.position = Vector2(300, 500)
	boss._process(0.32)
	assert(get_nodes_in_group("enemy_projectiles").size() == 10)
	assert(first.velocity == original_velocity, "Fired droplets do not home")
	assert(get_nodes_in_group("enemy_projectiles")[7].velocity.y > 200, "Next volley aims at the new position")
	boss._process(2.24)
	assert(boss.attack == boss.Attack.RECOVERY)
	assert(get_nodes_in_group("enemy_projectiles").size() == 40, "Eight five-shot volleys, no skipped boundaries")
	clear_projectiles()
	boss._process(boss.remaining)
	assert(boss.attack == boss.Attack.RING_WARNING and boss.rings_this_pattern == 1)
	var ring_start: float = boss.ring_angle
	boss._process(1.0)
	var normal_ring_count := get_nodes_in_group("enemy_projectiles").size()
	assert(normal_ring_count == 36, "Full circle has no omitted sector")
	for index in range(normal_ring_count):
		var droplet = get_nodes_in_group("enemy_projectiles")[index]
		var expected := Vector2.from_angle(ring_start + TAU * index / 36.0)
		assert(droplet.velocity.normalized().is_equal_approx(expected), "All 360 degrees are evenly covered")
	# Pause freezes existing projectiles as well as pattern clocks.
	first = get_nodes_in_group("enemy_projectiles")[0]
	var paused_position: Vector2 = first.position
	var paused_lifetime: float = first.lifetime
	scene.get_node("PauseScreen").pause()
	await process_frame
	await process_frame
	assert(first.position == paused_position and first.lifetime == paused_lifetime)
	scene.get_node("PauseScreen").resume()
	clear_projectiles()
	boss.take_damage(600)
	assert(boss.enraged, "Overlapping rings begin at half health")
	boss.attack = boss.Attack.RECOVERY
	boss.remaining = 0.1
	boss.volley_next = false
	boss._process(0.1)
	assert(boss.rings_this_pattern == 3 and boss.remaining == 1.0)
	ring_start = boss.ring_angle
	boss._process(1.0)
	assert(is_equal_approx(boss.ring_angle, ring_start + PI / 36.0))
	boss._process(1.7)
	assert(get_nodes_in_group("enemy_projectiles").size() == 108, "Low health sends three complete overlapping rings")
	if "--capture-droplets" in OS.get_cmdline_user_args():
		for droplet in get_nodes_in_group("enemy_projectiles"):
			droplet.set_process(false)
			droplet._process(0.75)
		scene.get_node("GameHUD").refresh()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/lll-bullet-hell.png")
	clear_projectiles()
	# Swept collision, once-only damage, shared hit grace and expiry.
	scene.lantern.health = 85
	scene.lantern.projectile_grace_remaining = 0
	scene.lantern.position = Vector2(300, 300)
	for index in range(2):
		var droplet = DROPLET.new()
		droplet.target = scene.lantern
		droplet.position = Vector2(100, 300)
		droplet.velocity = Vector2(400, 0)
		droplet.arming_remaining = 0
		scene.add_child(droplet)
		droplet._process(1.0)
		droplet._process(1.0)
		assert(droplet.is_queued_for_deletion())
	assert(scene.lantern.health == 73, "Crossing hits once; overlapping bullets share grace")
	scene.lantern._process(0.36)
	scene.lantern.take_projectile_damage(12)
	assert(scene.lantern.health == 61)
	var harmless = DROPLET.new()
	harmless.target = scene.lantern
	harmless.position = scene.lantern.position
	harmless.lifetime = 0.1
	scene.add_child(harmless)
	harmless._process(0.1)
	assert(harmless.is_queued_for_deletion() and scene.lantern.health == 61, "Spawn grace and expiry are harmless")
	for index in range(10):
		boss._fire_ring()
	assert(get_nodes_in_group("enemy_projectiles").size() <= boss.MAX_PROJECTILES)
	boss.take_damage(9999)
	assert(scene.last_run.victory and get_nodes_in_group("enemy_projectiles").is_empty() and get_nodes_in_group("hazards").is_empty())
	scene.continue_to_preparation()
	scene.start_run()
	assert(scene.lantern.projectile_grace_remaining == 0)
	var path: String = scene.save_path
	scene.free()
	await process_frame
	DirAccess.remove_absolute(path)
	print("PASS: bullet warnings, aimed volleys, non-homing droplets, full 360-degree rings, half-health overlap, pause, swept hits, grace, lifetime, cap, cleanup and reset")
	quit()
