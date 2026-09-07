extends SceneTree


func _initialize() -> void:
	call_deferred("launch")


func launch() -> void:
	# Local interactive sandbox: never publish shortened runs or use normal progress.
	ProjectSettings.set_setting("leaderboard/api_url", "")
	var scene = load("res://main.tscn").instantiate()
	scene.save_path = "/tmp/lll-interactive-final-%d.json" % OS.get_process_id()
	scene.final_boss_time = 60.0
	root.add_child(scene)
	current_scene = scene
	root.title = "Little Last Light — M16 test — Snuffer at 01:00"
	scene.damage_level = 4
	scene.fire_rate_level = 4
	scene.health_level = 4
	scene.banked_energy = 1000
	scene.configure_lantern()
	var center: Vector2 = scene.get_arena_rect().get_center()
	for index in range(6):
		var turret = scene.get_node("Turret") if index == 0 else scene.TURRET_SCENE.instantiate()
		if index > 0:
			turret.purchase_cost = 20.0 + 10.0 * (index - 1)
			scene.add_child(turret)
		scene.configure_turret(turret)
		turret.position = center + Vector2.from_angle(TAU * index / 6.0) * 160
	scene.summary = "M16 TEST · The Snuffer arrives at 01:00.\nSix upgraded turrets; arrange your defense, then start."
	scene.save_progress()
	scene.lantern._update_status()
	print("READY: M16 interactive test, Snuffer at 01:00, six upgraded turrets, isolated save, online publishing disabled")
