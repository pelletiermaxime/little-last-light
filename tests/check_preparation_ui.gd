extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var scene = load("res://main.tscn").instantiate()
	var path := "/tmp/lll-ui-test-%d.json" % OS.get_process_id()
	scene.save_path = path
	root.add_child(scene)
	scene.set_process(false)
	scene.lantern.set_process(false)
	var ui = scene.get_node("PreparationUI")
	var build = scene.get_node("BuildController")
	var hud = scene.get_node("GameHUD")
	assert(scene.get_arena_rect().size == scene.get_viewport_rect().size)
	assert(ui.card.visible and ui.place_button.visible and ui.upgrades_button.visible and build.start_button.visible)
	assert(not build.build_button.visible and not build.damage_button.visible and not hud.scroll.visible)
	ui.place_button.pressed.emit()
	assert(ui.view == ui.View.PLACEMENT and build.build_button.visible)
	scene.banked_energy = 100
	build.begin_placement()
	await process_frame
	await process_frame
	var count := get_nodes_in_group("turrets").size()
	assert(ui.card.position.x == 16 and ui.actions.columns == 1)
	assert(ui.card_style.bg_color.a < 0.4)
	# Exercise the actual GUI event path: card background must pass clicks to the arena.
	var point: Vector2 = ui.card.position + Vector2(30, 30)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = point
	click.pressed = true
	root.push_input(click, true)
	click.pressed = false
	root.push_input(click, true)
	assert(get_nodes_in_group("turrets").size() == count + 1 and not build.placing)
	var purchased = get_nodes_in_group("turrets").back()
	assert(purchased.position.is_equal_approx(point))
	build.begin_move(purchased)
	await process_frame
	await process_frame
	var covered: Vector2 = build.cancel_button.get_global_rect().get_center()
	assert(ui.blocks_point(covered))
	# Hiding controls preserves the preview and reveals even button-covered spots.
	build.using_controller = true
	build._select_or_place(ui.hide_button.get_global_rect().get_center())
	assert(not ui.card.visible and build.placing)
	build.using_controller = false
	build._select_or_place(covered)
	assert(not build.placing and purchased.position.is_equal_approx(covered))
	ui.show_button.pressed.emit()
	assert(ui.card.visible)
	build.begin_move(get_nodes_in_group("turrets")[0])
	assert(build.cancel_button.visible and not ui.back_button.visible, "Only Cancel is shown during placement")
	build.cancel_button.pressed.emit()
	assert(not build.cancel_button.visible and ui.back_button.visible, "Done returns after canceling placement")
	ui.back_button.pressed.emit()
	assert(ui.view == ui.View.HOME and not build.placing and get_nodes_in_group("turrets")[0].visible)
	ui.upgrades_button.pressed.emit()
	assert(build.damage_button.visible and build.health_button.visible and not build.build_button.visible)
	build.health_button.pressed.emit()
	assert(scene.health_level == 1 and scene.banked_energy == 40)
	ui.back_button.pressed.emit()
	assert(ui.view == ui.View.HOME)
	ui.records_button.pressed.emit()
	assert(hud.leaderboard.get_parent() == ui.records_host and hud.leaderboard.is_visible_in_tree())
	ui.back_button.pressed.emit()
	build.start_button.pressed.emit()
	assert(scene.phase == scene.Phase.RUNNING and not ui.card.visible and hud.scroll.visible)
	assert(scene.get_arena_rect().size == scene.get_viewport_rect().size)
	var pause_event := InputEventKey.new()
	pause_event.physical_keycode = KEY_ESCAPE
	pause_event.pressed = true
	scene.get_node("PauseScreen")._input(pause_event)
	assert(paused)
	scene.get_node("PauseScreen").end_run()
	assert(scene.phase == scene.Phase.RESULTS and not ui.card.visible and not hud.scroll.visible)
	scene.get_node("ResultsScreen").continue_button.pressed.emit()
	assert(ui.view == ui.View.HOME and ui.card.visible and not hud.scroll.visible)
	# Saved normalized coordinates reopen in the larger arena without changing the layout.
	var expected: Vector2 = get_nodes_in_group("turrets").back().position
	scene.free()
	await process_frame
	scene = load("res://main.tscn").instantiate()
	scene.save_path = path
	root.add_child(scene)
	assert(get_nodes_in_group("turrets").back().position.is_equal_approx(expected))
	ui = scene.get_node("PreparationUI")
	root.content_scale_size = Vector2i(640, 640)
	root.size = Vector2i(640, 640)
	await process_frame
	await process_frame
	ui.refresh()
	assert(ui.actions.columns == 1)
	assert(scene.get_viewport_rect().encloses(ui.card.get_global_rect()), "Narrow preparation card stays in view")
	ui.open_view(ui.View.UPGRADES)
	await process_frame
	await process_frame
	assert(scene.get_viewport_rect().encloses(ui.card.get_global_rect()), "Narrow upgrades card stays in view")
	scene.free()
	DirAccess.remove_absolute(path)
	print("PASS: full arena, home/actions, click-through placement, hiding controls, upgrades, records, pause/results, saved layout")
	quit()
