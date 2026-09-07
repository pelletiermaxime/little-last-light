extends SceneTree


func _initialize() -> void:
	call_deferred("launch")


func launch() -> void:
	ProjectSettings.set_setting("leaderboard/api_url", "")
	var scene = load("res://main.tscn").instantiate()
	# Persistent separate profile: test the full progression without erasing the main save.
	scene.save_path = "user://balance-test-v1.json"
	root.add_child(scene)
	current_scene = scene
	root.title = "Little Last Light — Balance playtest"
	print("READY: balance playtest, separate persistent profile, normal encounter timings")
