extends Node

# Run this scene natively or use scripts/build-render-benchmark.py for Web.
# Uses disposable progress and never submits a completed run to the leaderboard.
const WARMUP_FRAMES := 120
const SAMPLE_FRAMES := 360
var range_redraws := 0
var scene: Node2D
var results: Array[Dictionary] = []


func _ready() -> void:
	call_deferred("_benchmark")


func _benchmark() -> void:
	seed(472)
	for scenario in [
		{"name": "mixed_100", "enemies": 100, "bosses": false},
		{"name": "mixed_500", "enemies": 500, "bosses": false},
		{"name": "mixed_1000_bosses", "enemies": 1000, "bosses": true},
	]:
		scene = preload("res://main.tscn").instantiate()
		scene.save_path = "user://render-benchmark-%d.json" % OS.get_process_id()
		add_child(scene)
		scene.start_run()
		scene.set_process(false)
		scene.lantern.set_process(false)
		scene.lantern.set_physics_process(false)
		scene.lantern.max_health = 1000000000.0
		scene.lantern.health = scene.lantern.max_health
		scene.lantern.elapsed = 610.0
		# The baseline exporter can run this harness against the pre-refactor game.
		var encounters: Node = scene.get("encounters") if scene.get("encounters") != null else scene
		for index in range(24):
			var turret: Node2D = scene.turret_scene(["damage", "pulse", "sniper", "ember"][index % 4]).instantiate()
			turret.position = scene.get_arena_rect().get_center() + Vector2.from_angle(index * TAU / 24.0) * (80.0 + 60.0 * (index % 3))
			scene.configure_turret(turret)
			scene.add_child(turret)
			var ring := turret.get_node_or_null("RangeIndicator") as CanvasItem
			if ring == null:
				ring = turret
			ring.draw.connect(func(): range_redraws += 1)
		for index in range(scenario.enemies):
			encounters._spawn_enemy()
			var enemy: Node2D = scene.get_child(scene.get_child_count() - 1)
			enemy.position = scene.lantern.position + Vector2.from_angle(index * 2.39996) * (120.0 + index % 220)
			enemy.max_health = 1000000.0
			enemy.health = enemy.max_health
			enemy.contact_damage_per_second = 0.0
		if scenario.bosses:
			encounters._spawn_boss()
			encounters.update_rainkeeper_encounter()
		# Display settings apply deferred on startup; remove the benchmark's cap after that.
		await get_tree().process_frame
		Engine.max_fps = 0
		for frame in range(WARMUP_FRAMES):
			_move_lantern(frame)
			await get_tree().process_frame
		range_redraws = 0
		var samples: Array[float] = []
		var draw_calls: Array[float] = []
		var over_budget := 0
		for frame in range(SAMPLE_FRAMES):
			_move_lantern(frame + WARMUP_FRAMES)
			var started := Time.get_ticks_usec()
			await get_tree().process_frame
			var frame_ms := (Time.get_ticks_usec() - started) / 1000.0
			samples.append(frame_ms)
			draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			if frame_ms > 18.0:
				over_budget += 1
		samples.sort()
		draw_calls.sort()
		var result := {
			"scenario": scenario.name,
			"median_ms": snappedf(samples[SAMPLE_FRAMES / 2], 0.001),
			"p95_ms": snappedf(samples[int(SAMPLE_FRAMES * 0.95)], 0.001),
			"p99_ms": snappedf(samples[int(SAMPLE_FRAMES * 0.99)], 0.001),
			"frames_over_18ms": over_budget,
			"frames": SAMPLE_FRAMES,
			"range_redraws": range_redraws,
			"median_draw_calls": draw_calls[SAMPLE_FRAMES / 2],
			"renderer": DisplayServer.get_name(),
			"viewport": str(scene.get_viewport_rect().size),
		}
		results.append(result)
		print("RENDER_BENCHMARK " + JSON.stringify(result))
		var path: String = scene.save_path
		if scenario.name == "mixed_1000_bosses":
			# Leave the final frame available for visual inspection in the Web shell.
			scene.process_mode = Node.PROCESS_MODE_DISABLED
		else:
			scene.free()
		DirAccess.remove_absolute(path)
		await get_tree().process_frame
	print("RENDER_BENCHMARK_COMPLETE")
	if not OS.has_feature("web"):
		get_tree().quit()


func _move_lantern(frame: int) -> void:
	scene.lantern.position = scene.get_arena_rect().get_center() + Vector2.from_angle(frame * 0.02) * 70.0
