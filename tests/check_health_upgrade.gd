extends SceneTree

var path := "/tmp/lll-health-upgrade-%d.json" % OS.get_process_id()


func _initialize() -> void:
	call_deferred("check")


func game() -> Node2D:
	var scene = load("res://main.tscn").instantiate()
	scene.save_path = path
	root.add_child(scene)
	scene.set_process(false)
	scene.lantern.set_process(false)
	return scene


func check() -> void:
	var scene := game()
	assert(scene.lantern.health == 25 and scene.lantern.max_health == 25)
	assert(not scene.buy_upgrade("health"))
	scene.banked_energy = 2480
	var build = scene.get_node("BuildController")
	build.begin_placement()
	assert(not scene.buy_upgrade("health"))
	build.cancel_placement()
	build.health_button.pressed.emit()
	assert(scene.health_level == 1 and scene.banked_energy == 2400)
	assert(scene.lantern.health == 40 and scene.lantern.max_health == 40)
	scene.free()
	await process_frame
	scene = game()
	build = scene.get_node("BuildController")
	assert(scene.health_level == 1 and scene.lantern.health == 40)
	for price in [160, 320, 640, 1280]:
		assert(scene.upgrade_cost("health") == price)
		build.health_button.pressed.emit()
	assert(scene.health_level == 5 and scene.lantern.max_health == 100 and scene.banked_energy == 0)
	assert(not scene.buy_upgrade("health") and build.health_button.disabled)
	build.reset_layout()
	assert(scene.health_level == 5)
	scene.start_run()
	scene.lantern.take_damage(12)
	assert(scene.lantern.health == 88)
	assert(not scene.buy_upgrade("health"))
	scene.get_node("PauseScreen").pause()
	assert(not scene.buy_upgrade("health"))
	scene.get_node("PauseScreen").end_run()
	assert(not scene.buy_upgrade("health"))
	scene.continue_to_preparation()
	scene.start_run()
	assert(scene.lantern.health == 100)
	scene.end_run()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for value in [-1, 6, 1.5, "2"]:
		var bad := data.duplicate(true)
		bad.upgrades.health = value
		assert(not scene._valid_save(bad))
	data.upgrades.erase("health")
	assert(scene._valid_save(data))
	scene.free()
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	scene = game()
	assert(scene.health_level == 0 and scene.lantern.max_health == 25)
	scene.start_run()
	scene.lantern.take_damage(12)
	scene.lantern.take_damage(12)
	assert(scene.lantern.health == 1 and scene.phase == scene.Phase.RUNNING)
	scene.lantern.take_damage(12)
	assert(scene.phase == scene.Phase.RESULTS)
	scene.free()
	DirAccess.remove_absolute(path)
	print("PASS: base health, button purchases, persistence, migration, cap, phase guards, refill, three-hit death")
	quit()
