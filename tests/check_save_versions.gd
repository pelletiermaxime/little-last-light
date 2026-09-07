extends SceneTree

var path := "/tmp/lll-save-version-%d.json" % OS.get_process_id()

func _initialize() -> void:
	call_deferred("check")

func game() -> Node2D:
	var scene = load("res://main.tscn").instantiate()
	scene.save_path = path
	root.add_child(scene)
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	return scene

func check() -> void:
	var original: String = ProjectSettings.get_setting("application/config/version")
	var scene := game()
	scene.banked_energy = 987.0
	scene.damage_level = 5
	scene.proximity_level = 3
	scene.save_progress()
	scene.free()
	await process_frame
	scene = game()
	assert(scene.banked_energy == 987.0 and scene.damage_level == 5 and scene.proximity_level == 3, "Same version preserves purchases and energy")
	scene.free()
	await process_frame
	ProjectSettings.set_setting("application/config/version", "version-reset-test")
	scene = game()
	assert(scene.banked_energy == 0.0 and scene.damage_level == 0 and scene.proximity_level == 0, "New version starts fresh")
	assert(get_nodes_in_group("turrets").size() == 1 and scene.save_is_readable)
	scene.banked_energy = 12.0
	assert(scene.save_progress(), "Fresh version can replace previous progression")
	scene.free()
	await process_frame
	scene = game()
	assert(scene.banked_energy == 12.0, "Restarting the new version preserves new progress")
	scene.free()
	await process_frame
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string('{"version":1,"energy":999,"best_time":300,"turrets":[[0.5,0.5]]}')
	file.close()
	scene = game()
	assert(scene.banked_energy == 0.0 and scene.best_time == 0.0, "Unversioned old saves start fresh")
	scene.free()
	ProjectSettings.set_setting("application/config/version", original)
	DirAccess.remove_absolute(path)
	print("PASS: same-version persistence, new-version reset, writable fresh profile and unversioned reset")
	quit()
