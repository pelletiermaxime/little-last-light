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
	var scene = load("res://main.tscn").instantiate()
	var test_path := "/tmp/little-last-light-build-%d.json" % OS.get_process_id()
	scene.save_path = test_path
	root.add_child(scene)
	current_scene = scene
	var lantern = scene.lantern
	var build = scene.get_node("BuildController")
	assert(get_nodes_in_group("turrets").size() == 1, "Ghost is not a real turret")
	press_key(KEY_B)
	assert(not paused and not build.placing, "Cannot build without energy")
	scene.banked_energy = 40.0
	press_key(KEY_B)
	assert(not paused and build.placing and build.preview.visible, "B enters preparation placement")
	var elapsed: float = lantern.elapsed
	await process_frame
	await process_frame
	assert(scene.banked_energy == 40.0 and lantern.energy == 0.0 and lantern.elapsed == elapsed, "Preparation has no income or timer")
	assert(not build.try_place(Vector2(-10, 300)), "Outside arena rejected")
	assert(not build.try_place(scene.get_node("Turret").global_position), "Overlap rejected")
	assert(not build.try_place(Vector2(scene.get_arena_rect().end.x + 30, 30)), "Sidebar is outside arena")
	assert(scene.banked_energy == 40.0, "Invalid clicks do not spend")
	press_key(KEY_ESCAPE)
	assert(not paused and not build.placing and scene.banked_energy == 40.0, "Esc cancels without cost")
	press_key(KEY_B)
	var arena: Vector2 = scene.get_arena_rect().size
	var point := Vector2(arena.x * 0.85, arena.y * 0.35)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = point
	root.push_input(click, true)
	assert(scene.phase == scene.Phase.PREPARATION and scene.banked_energy == 20.0, "Purchase costs 20 and stays in preparation")
	assert(get_nodes_in_group("turrets").size() == 2, "Exactly one real turret added")
	assert(not build.try_place(point + Vector2(50, 0)), "Second click cannot purchase again")
	var turret = get_nodes_in_group("turrets")[1]
	lantern.position += Vector2(10, 0)
	assert(turret.global_position == point, "Purchased turret stays fixed")
	scene.start_run()
	scene._spawn_enemy()
	var enemy = get_nodes_in_group("enemies")[0]
	enemy.global_position = point + Vector2(50, 0)
	turret._process(0.1)
	assert(enemy.is_queued_for_deletion(), "Purchased turret shoots")
	press_key(KEY_B)
	assert(not build.placing, "Cannot build during combat")
	lantern.take_damage(1000)
	scene.start_run()
	assert(get_nodes_in_group("turrets").size() == 2, "New run preserves purchased turrets")
	assert(not build.placing, "New run has no placement state")
	print("PASS: input, placement, invalid positions, cancel, cost, double-click, fixed turret, shooting, combat lock, persistent turrets")
	scene.free()
	DirAccess.remove_absolute(test_path)
	quit()
