extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func press_key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	root.push_input(event)

func check() -> void:
	change_scene_to_file("res://main.tscn")
	await scene_changed
	var scene = current_scene
	var lantern = scene.lantern
	var build = scene.get_node("BuildController")
	assert(get_nodes_in_group("turrets").size() == 1, "Ghost is not a real turret")
	press_key(KEY_B)
	assert(not paused and not build.placing, "Cannot build without energy")
	lantern.energy = 40.0
	press_key(KEY_B)
	assert(paused and build.placing and build.preview.visible, "B enters placement")
	var elapsed: float = lantern.elapsed
	await process_frame
	await process_frame
	assert(lantern.energy == 40.0 and lantern.elapsed == elapsed, "Placement freezes economy and timer")
	assert(not build.try_place(Vector2(-10, 300)), "Outside arena rejected")
	assert(not build.try_place(scene.get_node("Turret").global_position), "Overlap rejected")
	assert(not build.try_place(Vector2(30, 30)), "HUD blocked")
	assert(lantern.energy == 40.0, "Invalid clicks do not spend")
	press_key(KEY_ESCAPE)
	assert(not paused and not build.placing and lantern.energy == 40.0, "Esc cancels without cost")
	press_key(KEY_B)
	var arena: Vector2 = scene.get_viewport_rect().size
	var point := Vector2(arena.x * 0.85, arena.y * 0.55)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = point
	root.push_input(click, true)
	assert(not paused and lantern.energy == 20.0, "Purchase costs exactly 20 and resumes")
	assert(get_nodes_in_group("turrets").size() == 2, "Exactly one real turret added")
	assert(not build.try_place(point + Vector2(50, 0)), "Second click cannot purchase again")
	var turret = get_nodes_in_group("turrets")[1]
	lantern.position += Vector2(10, 0)
	assert(turret.global_position == point, "Purchased turret stays fixed")
	scene._spawn_enemy()
	var enemy = get_nodes_in_group("enemies")[0]
	enemy.global_position = point + Vector2(50, 0)
	turret._process(0.1)
	assert(enemy.is_queued_for_deletion(), "Purchased turret shoots")
	lantern.take_damage(1000)
	press_key(KEY_B)
	assert(paused and not build.placing, "Cannot build during defeat")
	scene.restart_button.pressed.emit()
	await scene_changed
	assert(get_nodes_in_group("turrets").size() == 1, "Restart clears purchased turrets")
	assert(not current_scene.get_node("BuildController").placing, "Restart clears placement state")
	print("PASS: keyboard placement, pause, invalid positions, cancel, cost, double-click, fixed turret, shooting, defeat and restart")
	quit()
