extends SceneTree

# Run with --disable-vsync --fixed-fps 144 --path . --script tests/benchmark_swarm.gd.
# Headless runs measure CPU only; use a real display to include rendering.
var redraws: int = 0


func _initialize() -> void:
	call_deferred("benchmark")


func benchmark() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.save_path = "/tmp/little-last-light-benchmark-%d.json" % OS.get_process_id()
	root.add_child(scene)
	scene.start_run()
	scene.set_process(false)
	scene.lantern.set_physics_process(false)
	scene.lantern.max_health = 1000000000.0
	scene.lantern.health = scene.lantern.max_health
	scene.lantern.elapsed = 300.0
	for index in range(24):
		var turret = load("res://turret.tscn").instantiate()
		turret.position = Vector2(-1000, -1000)
		scene.add_child(turret)
		turret.draw.connect(func(): redraws += 1)
	for count in [100, 500, 1000]:
		scene._clear_enemies()
		await process_frame
		for index in range(count):
			scene._spawn_enemy()
			var enemy = scene.get_child(scene.get_child_count() - 1)
			enemy.position = scene.lantern.position + Vector2.from_angle(index * 2.39996) * (120.0 + index % 200)
			enemy.contact_damage_per_second = 0.0
			enemy.draw.connect(func(): redraws += 1)
			for child in enemy.get_children():
				if child is CanvasItem:
					child.draw.connect(func(): redraws += 1)
		for frame in range(30):
			await process_frame
		redraws = 0
		var samples: Array[float] = []
		for frame in range(240):
			# A deterministic moving target keeps the swarm steering.
			scene.lantern.position = scene.get_arena_rect().get_center() + Vector2.from_angle(frame * 0.02) * 100.0
			var started := Time.get_ticks_usec()
			await process_frame
			samples.append((Time.get_ticks_usec() - started) / 1000.0)
		samples.sort()
		print("SWARM count=%d frame_ms_median=%.3f frame_ms_p95=%.3f redraws=%d renderer=%s" % [count, samples[120], samples[228], redraws, DisplayServer.get_name()])
	scene.free()
	quit()
