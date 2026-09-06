extends SceneTree

var failures: int = 0

func _initialize() -> void:
	call_deferred("check")

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func check() -> void:
	var path := "/tmp/little-last-light-reset-%d.json" % OS.get_process_id()
	var scene = load("res://main.tscn").instantiate()
	scene.save_path = path
	# This scenario checks publication, so simulate a numbered exported release.
	scene.game_version = "0.1.0"
	root.add_child(scene)
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	var build = scene.get_node("BuildController")
	scene.continue_to_preparation()
	scene.start_run()
	scene.lantern.elapsed = 123.0
	scene.end_run(true)
	scene.continue_to_preparation()
	scene.banked_energy = 120.5
	for point in [Vector2(100,100), Vector2(200,100), Vector2(300,100)]:
		build.begin_placement()
		expect(build.try_place(point), "Purchase fixture turret through real pricing")
	expect(is_equal_approx(scene.banked_energy, 30.5), "Purchases cost 20 + 30 + 40")
	expect(build.layout_refund() == 90.0, "Refund is actual price ladder sum, excluding starter")
	build.begin_move(get_nodes_in_group("turrets")[2])
	expect(build.placing, "Can reset during an unfinished move")
	build.reset_button.pressed.emit()
	expect(not build.placing and not build.preview.visible, "Reset cancels active preview")
	expect(get_nodes_in_group("turrets").size() == 1, "Reset immediately retains exactly one turret")
	var starter = get_nodes_in_group("turrets")[0]
	expect(starter.visible and starter.position.is_equal_approx(scene.get_arena_rect().get_center() + Vector2(80,0)), "Starter returns visibly to original position")
	expect(is_equal_approx(scene.banked_energy, 120.5), "All purchased energy refunded, preserving fractional bank")
	expect(scene.best_time == 123.0, "Best survival remains unchanged")
	expect(build.turret_cost() == 20.0 and build.layout_refund() == 0.0, "Purchase ladder resets and starter has no refund")
	build.reset_button.pressed.emit()
	expect(is_equal_approx(scene.banked_energy, 120.5), "Double-click cannot refund twice")
	starter.position = Vector2(50, 50)
	var event := InputEventJoypadButton.new()
	event.device = 3
	event.button_index = JOY_BUTTON_Y
	event.pressed = true
	root.push_input(event)
	event.pressed = false
	root.push_input(event)
	expect(starter.position.is_equal_approx(scene.get_arena_rect().get_center() + Vector2(80,0)), "Triangle/Y can reset layout from a controller")
	build.begin_placement()
	build.reset_layout()
	expect(not build.placing and is_equal_approx(scene.banked_energy, 120.5), "Unpurchased ghost never earns a refund")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(path))
	expect(saved.turrets.size() == 1 and is_equal_approx(saved.energy, 120.5), "Reset writes the refunded bank and single-turret layout")
	scene.continue_to_preparation()
	scene.start_run()
	build._update_interface()
	expect(not build.reset_button.visible and not build.reset_layout(), "Combat blocks reset even when called directly")
	scene.get_node("PauseScreen").pause()
	expect(not build.reset_layout(), "Pausing a run does not allow refunds")
	scene.get_node("PauseScreen").resume()
	scene.free()
	var reopened = load("res://main.tscn").instantiate()
	reopened.save_path = path
	reopened.game_version = "0.1.0"
	root.add_child(reopened)
	await process_frame
	expect(get_nodes_in_group("turrets").size() == 1 and is_equal_approx(reopened.banked_energy,120.5), "Reset survives reopening")
	expect(reopened.best_time == 123.0, "Record survives reset and reopening")
	expect(reopened.leaderboard_profile.pending.get("durationMs") == 123000, "Voluntary run record remains publishable after reset and reopening")
	reopened.free()
	DirAccess.remove_absolute(path)
	if failures == 0:
		print("PASS: price refund, starter reset, preview cancellation, repeat safety, combat lock, save/reopen")
	quit(1 if failures else 0)
