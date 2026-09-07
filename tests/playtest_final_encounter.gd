extends SceneTree


func _initialize() -> void:
	call_deferred("check")


func check() -> void:
	for strategy in ["stationary", "orbit", "dodge"]:
		var scene = load("res://main.tscn").instantiate()
		var path := "/tmp/lll-final-playtest-%d.json" % OS.get_process_id()
		scene.save_path = path
		root.add_child(scene)
		scene.get_node("GameHUD").leaderboard.api_url = ""
		scene.damage_level = 4
		scene.fire_rate_level = 4
		scene.health_level = 4
		scene.configure_lantern()
		var center: Vector2 = scene.get_arena_rect().get_center()
		for index in range(6):
			var turret = scene.get_node("Turret") if index == 0 else scene.TURRET_SCENE.instantiate()
			if index > 0:
				turret.purchase_cost = 20 + 10 * (index - 1)
				scene.add_child(turret)
			scene.configure_turret(turret)
			turret.position = center + Vector2.from_angle(TAU * index / 6.0) * 160
		scene.start_run()
		scene.set_process(false)
		scene.lantern.set_process(false)
		scene.lantern.set_physics_process(false)
		scene._set_turrets_active(false)
		scene.lantern.elapsed = 900
		scene.update_final_encounter()
		var boss = get_nodes_in_group("final_bosses")[0]
		boss.set_process(false)
		var fight_time := 0.0
		while scene.phase == scene.Phase.RUNNING and fight_time < 240:
			var delta := 1.0 / 60.0
			fight_time += delta
			if strategy != "stationary":
				# A repeatable orbit at normal movement speed; no teleports after start.
				var destination := center + Vector2.from_angle(fight_time * 1.5) * 125
				if strategy == "dodge":
					scene.lantern.position += dodge_velocity(scene, destination) * delta
				else:
					scene.lantern.position = scene.lantern.position.move_toward(destination, scene.lantern.move_speed * delta)
			scene.lantern._process(delta)
			boss._process(delta)
			for droplet in get_nodes_in_group("enemy_projectiles"):
				droplet._process(delta)
			if scene.phase == scene.Phase.RUNNING:
				for turret in get_nodes_in_group("turrets"):
					turret._process(delta)
		print("PLAYTEST: %s, six upgraded turrets, %.1fs fight, %.0f HP, %s" % [strategy, fight_time, scene.lantern.health, "victory" if scene.last_run.get("victory", false) else "defeat/timeout"])
		if strategy == "dodge":
			assert(scene.last_run.get("victory", false), "A defense that reads the projectiles can win")
		scene.free()
		await process_frame
		DirAccess.remove_absolute(path)
	quit()


func dodge_velocity(scene: Node2D, destination: Vector2) -> Vector2:
	var best_velocity := Vector2.ZERO
	var best_score := -INF
	var arena: Rect2 = scene.get_arena_rect().grow(-20)
	var bullets := get_nodes_in_group("enemy_projectiles")
	for index in range(17):
		var velocity: Vector2 = Vector2.ZERO if index == 16 else Vector2.from_angle(TAU * index / 16.0) * scene.lantern.move_speed
		var future: Vector2 = scene.lantern.position + velocity * 0.5
		if not arena.has_point(future):
			continue
		var clearance := 100.0
		for bullet in bullets:
			var relative: Vector2 = bullet.position - scene.lantern.position
			var end: Vector2 = relative + (bullet.velocity - velocity) * 0.5
			clearance = minf(clearance, Geometry2D.get_closest_point_to_segment(Vector2.ZERO, relative, end).length())
		var score := clearance - future.distance_to(destination) * 0.06
		if score > best_score:
			best_score = score
			best_velocity = velocity
	return best_velocity
