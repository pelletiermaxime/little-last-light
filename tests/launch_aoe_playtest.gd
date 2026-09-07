extends SceneTree


func _initialize() -> void:
	call_deferred("launch")


func launch() -> void:
	ProjectSettings.set_setting("leaderboard/api_url", "")
	var scene = load("res://main.tscn").instantiate()
	# A separate persistent profile keeps the normal game's layout and savings intact.
	scene.save_path = "user://ember-playtest-v1.json"
	root.add_child(scene)
	current_scene = scene
	if get_nodes_in_group("turrets").size() == 1:
		var arena: Rect2 = scene.get_arena_rect()
		var kinds := ["ember", "sniper"]
		for index in range(kinds.size()):
			var turret: Node2D = scene.turret_scene(kinds[index]).instantiate()
			turret.purchase_cost = scene.get_node("BuildController").turret_cost(kinds[index])
			scene.configure_turret(turret)
			scene.add_child(turret)
			turret.position = arena.size * Vector2(0.4 + index * 0.2, 0.7)
		scene._set_turrets_active(false)
	scene.banked_energy = maxf(scene.banked_energy, 1500.0)
	scene.save_progress()
	scene.get_node("BuildController")._update_interface()
	scene.get_node("PreparationUI").open_view(1)
	root.title = "Little Last Light — Ember Pot playtest"
	print("READY: Ember Pot and Watchlight; separate profile; 1500 energy available")
