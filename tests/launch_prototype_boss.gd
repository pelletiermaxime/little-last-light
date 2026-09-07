extends SceneTree

const CANDIDATES := ["rainkeeper", "tidekeeper", "wickwatcher"]


func _initialize() -> void:
	call_deferred("launch")


func launch() -> void:
	var selected := "rainkeeper"
	var arrival := 60.0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--boss="):
			selected = argument.trim_prefix("--boss=")
		elif argument.begins_with("--arrival="):
			arrival = float(argument.trim_prefix("--arrival="))
	if selected not in CANDIDATES or not is_finite(arrival) or arrival < 0 or arrival >= 900:
		push_error("Use --boss=rainkeeper|tidekeeper|wickwatcher and --arrival=0..899")
		quit(1)
		return
	ProjectSettings.set_setting("leaderboard/api_url", "")
	var scene = load("res://main.tscn").instantiate()
	scene.save_path = "/tmp/lll-%s-practice-%d.json" % [selected, OS.get_process_id()]
	scene.prototype_boss_kind = CANDIDATES.find(selected)
	scene.prototype_boss_time = arrival
	root.add_child(scene)
	current_scene = scene
	root.title = "Little Last Light — %s at %02d:%02d" % [selected.capitalize(), int(arrival) / 60, int(arrival) % 60]
	scene.damage_level = 4
	scene.fire_rate_level = 4
	scene.health_level = 4
	scene.banked_energy = 1000
	scene.configure_lantern()
	var center: Vector2 = scene.get_arena_rect().get_center()
	for index in range(6):
		var turret = scene.get_node("Turret") if index == 0 else scene.TURRET_SCENE.instantiate()
		if index > 0:
			turret.purchase_cost = 25.0 * index
			scene.add_child(turret)
		scene.configure_turret(turret)
		turret.position = center + Vector2.from_angle(TAU * index / 6.0) * 160
	scene.summary = "%s PRACTICE · arrives at %02d:%02d.\nSix upgraded turrets. Arrange your defense, then start." % [selected.to_upper(), int(arrival) / 60, int(arrival) % 60]
	scene.save_progress()
	scene.lantern._update_status()
	print("READY: %s at %.1fs, separate practice save, publishing disabled" % [selected, arrival])
