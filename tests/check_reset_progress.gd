extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var path := "/tmp/lll-reset-progress-%d.json" % OS.get_process_id()
	var scene = load("res://main.tscn").instantiate()
	scene.save_path = path
	root.add_child(scene)
	current_scene = scene
	scene.banked_energy = 1000.0
	scene.buy_upgrade("damage")
	scene.buy_upgrade("health")
	scene.buy_upgrade("slow_rate")
	scene.buy_upgrade("slow_strength")
	scene.buy_upgrade("slow_duration")
	var build = scene.get_node("BuildController")
	build.begin_placement("pulse")
	assert(build.try_place(Vector2(100, 100)))
	scene.best_time = 123.0
	scene.version_bests = {"dev": 123.0}
	scene.save_progress()
	var original := FileAccess.get_file_as_string(path)
	var audio_volume: float = root.get_node("GameAudio").volume
	var fps: int = root.get_node("DisplaySettings").fps_limit
	var settings = scene.get_node("SettingsScreen")
	settings.open(scene.get_node("PreparationUI").settings_button)
	assert(settings.reset_button.visible)
	settings.reset_button.pressed.emit()
	assert(settings.reset_pending and root.gui_get_focus_owner() == settings.reset_cancel)
	assert(not settings.volume_button.visible and settings.reset_confirm.visible)
	assert(FileAccess.get_file_as_string(path) == original, "Opening confirmation never clears progress")
	settings.close()
	assert(settings.is_open() and not settings.reset_pending, "Back cancels confirmation before closing settings")
	assert(FileAccess.get_file_as_string(path) == original)
	settings.reset_button.pressed.emit()
	# A write failure leaves both the active game and its save unchanged.
	scene.save_path = "/missing-directory-lll/progress.json"
	settings.reset_confirm.pressed.emit()
	assert(scene.banked_energy > 0 and scene.damage_level == 1)
	assert(FileAccess.get_file_as_string(path) == original)
	scene.save_path = path
	settings.reset_cancel.pressed.emit()
	settings.reset_button.pressed.emit()
	root.size = Vector2i(640, 480)
	for frame in range(6):
		await process_frame
	assert(root.get_visible_rect().encloses(settings.reset_confirm.get_global_rect()))
	# Real controller input confirms once, and release cannot start the new run.
	settings.reset_confirm.grab_focus()
	var event := InputEventJoypadButton.new()
	event.device = 3
	event.button_index = JOY_BUTTON_A
	event.pressed = true
	root.push_input(event)
	event.pressed = false
	root.push_input(event)
	for frame in range(6):
		await process_frame
	scene = current_scene
	assert(scene.save_path == path and scene.phase == scene.Phase.PREPARATION)
	assert(scene.banked_energy == 0 and scene.damage_level == 0 and scene.health_level == 0 and scene.fire_rate_level == 0)
	assert(scene.slow_levels == {"slow_rate": 0, "slow_strength": 0, "slow_duration": 0})
	assert(scene.best_time == 0 and scene.legacy_best_time == 0 and scene.version_bests.is_empty())
	assert(scene.last_run.is_empty() and scene.leaderboard_profile.pending.is_empty() and scene.leaderboard_profile.username.is_empty())
	assert(get_nodes_in_group("turrets").size() == 1)
	assert(get_nodes_in_group("turrets")[0].purchase_cost == 0 and get_nodes_in_group("turrets")[0].turret_type == "damage")
	assert(scene.lantern.health == 25 and scene.lantern.energy == 0)
	build = scene.get_node("BuildController")
	var prep = scene.get_node("PreparationUI")
	assert(build.using_controller, "Reset retains the active controller for text as well as icons")
	prep.open_view(prep.View.PLACEMENT)
	assert(not build.build_button.text.contains("(B)") and not build.pulse_button.text.contains("(V)"))
	assert(not prep.back_button.text.contains("Esc") and not prep.hide_button.text.contains("Tab"))
	assert(not build.cancel_button.text.contains("Esc") and not prep.show_button.text.contains("Tab"))
	assert(build.build_button.icon != null and build.pulse_button.icon != null)
	assert(root.get_node("GameAudio").volume == audio_volume and root.get_node("DisplaySettings").fps_limit == fps)
	assert(JSON.parse_string(FileAccess.get_file_as_string(path)).energy == 0)
	scene.start_run()
	scene.get_node("PauseScreen").pause()
	settings = scene.get_node("SettingsScreen")
	settings.open(scene.get_node("PauseScreen").settings_button)
	assert(not settings.reset_button.visible and not scene.reset_progress(), "Reset is only offered from preparation")
	paused = false
	scene.free()
	DirAccess.remove_absolute(path)
	print("PASS: reset confirmation/cancel, write failure, controller confirm, fresh state/save, retained preferences, pause restriction")
	quit()
