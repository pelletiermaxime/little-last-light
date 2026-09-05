extends SceneTree

var deaths: int = 0

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	change_scene_to_file("res://main.tscn")
	await process_frame
	var scene = current_scene
	var lantern = scene.get_node("Lantern")
	scene.set_process(false)
	lantern.set_process(false)
	scene.get_node("Turret").set_process(false)
	lantern.died.connect(func(): deaths += 1)
	scene._spawn_enemy()
	var enemy = get_nodes_in_group("enemies")[0]
	enemy.set_process(false)
	enemy.global_position = lantern.global_position + Vector2(100, 0)
	enemy._process(1.0)
	assert(lantern.health == 100.0, "No damage outside contact range")
	enemy.global_position = lantern.global_position
	enemy._process(0.5)
	assert(lantern.health == 92.5, "Contact damage uses elapsed time")
	lantern.take_damage(-10)
	assert(lantern.health == 92.5, "Negative damage ignored")
	lantern.set_process(true)
	scene.set_process(true)
	lantern.take_damage(1000)
	lantern.take_damage(1000)
	assert(lantern.health == 0 and deaths == 1, "Death emits once and health clamps")
	assert(paused and scene.defeat_screen.visible, "Death pauses and shows menu")
	assert(scene.restart_button.can_process(), "Restart works while paused")
	var energy: float = lantern.energy
	var progress: float = scene.spawn_progress
	await process_frame
	await process_frame
	assert(lantern.energy == energy and scene.spawn_progress == progress, "Run freezes")
	scene.restart_button.pressed.emit()
	await process_frame
	await process_frame
	assert(not paused and current_scene != scene, "Restart replaces scene and unpauses")
	assert(current_scene.lantern.health == 100.0, "Restart restores health")
	assert(current_scene.lantern.energy < 1.0 and get_nodes_in_group("enemies").is_empty(), "Fresh run state")
	assert(not current_scene.defeat_screen.visible, "Defeat menu is hidden again")
	print("PASS: contact damage, death, paused run, interactive restart, fresh scene")
	quit()
