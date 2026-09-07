extends SceneTree

# Deterministic native rendering and simulation probe; never uses the player's save.
func _initialize() -> void:
	call_deferred("check")


func check() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.save_path = "/tmp/little-last-light-ward-playtest-%d.json" % OS.get_process_id()
	root.add_child(scene)
	await process_frame
	root.size = Vector2i(960, 640)
	scene._resize_layout()
	scene.lantern._center_in_viewport()
	scene.get_node("Turret").position = scene.lantern.position + Vector2(80, 0)
	scene.start_run()
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	var lantern = scene.lantern
	var hud = scene.get_node("GameHUD")
	# A modest defended pocket: starter plus three turrets, one damage upgrade.
	scene.damage_level = 1
	for index in range(3):
		var turret = scene.TURRET_SCENE.instantiate()
		scene.add_child(turret)
		turret.position = lantern.position + Vector2.from_angle((index + 1) * PI / 2) * 80.0
	for turret in get_nodes_in_group("turrets"):
		scene.configure_turret(turret)
	for state in ["forming", "active", "broken"]:
		lantern.reset_ward()
		lantern.update_ward(0.7 if state == "forming" else 4.0, false)
		if state == "broken":
			lantern.take_damage(8.0)
			lantern.update_ward(0.3, false)
		hud.refresh()
		await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/m15-ward-%s.png" % state)
	for mode in [{"moving": false, "brightness": 0}, {"moving": true, "brightness": 0}, {"moving": false, "brightness": 2}, {"moving": true, "brightness": 2}]:
		var moving: bool = mode.moving
		seed(15)
		scene._clear_enemies()
		lantern.reset_ward()
		lantern.health = 85.0
		lantern.elapsed = 0.0
		lantern.energy = 0.0
		lantern.brightness = mode.brightness
		for turret in get_nodes_in_group("turrets"):
			turret.cooldown = 0.0
		scene.spawn_progress = 0.0
		scene.next_charger_time = 20.0
		var center: Vector2 = scene.get_arena_rect().get_center()
		for frame in range(60 * 60):
			var delta := 1.0 / 60.0
			if not lantern.running:
				break
			lantern.position = center + Vector2.from_angle(frame * delta * 1.5) * 100.0 if moving else center
			lantern.update_ward(delta, moving)
			lantern._process(delta)
			scene._process(delta)
			for turret in get_nodes_in_group("turrets"):
				turret._process(delta)
			for enemy in get_nodes_in_group("enemies"):
				if not enemy.is_queued_for_deletion():
					enemy._process(delta)
			# Flush deferred deaths before the next simulated targeting frame.
			for enemy in get_nodes_in_group("enemies"):
				if enemy.is_queued_for_deletion():
					enemy.free()
		print("PLAYTEST %s brightness=%d: %.1fs, %.1f HP, %.1f ward, %d enemies" % ["orbit" if moving else "settled", mode.brightness, lantern.elapsed, lantern.health, lantern.ward_charge, get_nodes_in_group("enemies").size()])
		if not lantern.running:
			scene.continue_to_preparation()
			scene.start_run()
	var path: String = scene.save_path
	scene._clear_enemies()
	await process_frame
	scene.free()
	DirAccess.remove_absolute(path)
	quit()
