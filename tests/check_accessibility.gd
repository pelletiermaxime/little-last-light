extends SceneTree

var failures := 0
var path := "/tmp/lll-accessibility-%d.json" % OS.get_process_id()

func _initialize() -> void:
	call_deferred("check")

func expect(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func new_game() -> Node2D:
	var game = load("res://main.tscn").instantiate()
	game.save_path = path
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	game.lantern.set_process(false)
	game.lantern.set_physics_process(false)
	game.get_node("GameHUD").leaderboard.api_url = ""
	return game

func confirm() -> void:
	var event := InputEventJoypadButton.new()
	event.device = 3
	event.button_index = JOY_BUTTON_A
	event.pressed = true
	root.push_input(event)
	event.pressed = false
	root.push_input(event)

func check() -> void:
	var display = root.get_node("DisplaySettings")
	var original_path: String = display.settings_path
	var original := {}
	for key in display.VISUAL_OPTIONS:
		original[key] = display.get(key)
	display.settings_path = path + ".cfg"
	var game = new_game()
	await process_frame
	var settings = game.get_node("SettingsScreen")
	settings.open(null)
	settings.visual_button.pressed.emit()
	expect(settings.visual_page.visible and not settings.volume_button.visible, "Visual accessibility has its own page")
	for key in ["strong_danger_cues", "reduce_effects"]:
		display.set_visual_option(key, true)
	display.set_visual_option("show_turret_ranges", false)
	expect(game.leaderboard_eligible() and not game.assisted_progress, "Visual options do not disqualify progress")
	var turret = get_nodes_in_group("turrets")[0]
	expect(not turret.range_visible(), "Placed turret range can be hidden")
	expect(game.get_node("BuildController").preview.range_visible(), "Placement preview retains its range guide")
	var range_turrets: Array[Node] = []
	for kind in ["turret", "pulse_turret", "sniper_turret", "ember_turret"]:
		var placed = load("res://turrets/%s.tscn" % kind).instantiate()
		game.add_child(placed)
		range_turrets.append(placed)
		expect(not placed.range_indicator.visible, "Cached range starts hidden: " + kind)
		placed.range_preview = true
		expect(placed.range_indicator.visible, "Preview override shows cached range: " + kind)
		placed.range_preview = false
		expect(not placed.range_indicator.visible, "Removing preview override hides cached range: " + kind)
	paused = true
	display.set_visual_option("show_turret_ranges", true)
	for placed in range_turrets:
		expect(placed.range_indicator.visible, "Cached range updates while paused")
	display.set_visual_option("show_turret_ranges", false)
	for placed in range_turrets:
		expect(not placed.range_indicator.visible, "Cached range hides while paused")
		placed.free()
	expect(game.get_node("BuildController").preview.range_indicator.visible, "Preview cached range remains visible")
	paused = false
	for key in display.VISUAL_OPTIONS:
		display.set(key, not display.get(key))
	display.load_settings()
	expect(display.strong_danger_cues and display.reduce_effects and not display.show_turret_ranges, "Visual preferences persist independently")
	root.size = Vector2i(640, 480)
	for frame in range(6):
		await process_frame
	for control in ["StrongDangerCues", "ReduceEffects", "ShowTurretRanges", "BackButton"]:
		expect(root.get_visible_rect().encloses(settings.visual_page.get_node(control).get_global_rect()), "Visual control fits at 640x480: " + control)
	settings.close()
	settings._show_assistance(true)
	settings.assistance_page.get_node("DamageTaken").pressed.emit()
	expect(game.damage_taken_factor == 0.75 and not game.leaderboard_eligible(), "Damage button cycles to 75 percent and marks progress assisted")
	for frame in range(6):
		await process_frame
	for control in ["DamageTaken", "BackButton"]:
		expect(root.get_visible_rect().encloses(settings.assistance_page.get_node(control).get_global_rect()), "Extended assist control fits: " + control)
	settings.close()
	settings.close()
	game.start_run()
	expect(Engine.time_scale == 1, "Assisted play keeps normal game speed")
	game.lantern.take_damage(8)
	expect(game.lantern.health == 19, "Contact damage respects 75 percent factor")
	game.lantern.take_projectile_damage(8)
	expect(game.lantern.health == 13, "Projectile damage applies factor exactly once")
	expect(game.lantern.hit_flash == 0, "Reduced effects removes damage flash")
	var trail = load("res://hazards/water_trail.gd").new()
	trail.target = game.lantern
	game.add_child(trail)
	trail.leave_puddle(game.lantern.position)
	trail._process(1.6)
	expect(is_equal_approx(game.lantern.health, 7.0), "Water damage respects reduction")
	var pause = game.get_node("PauseScreen")
	pause.pause()
	expect(Engine.time_scale == 1 and paused, "Pause menu runs at normal speed")
	settings.open(null)
	settings._show_visual(true)
	settings.visual_page.get_node("ReduceEffects").grab_focus()
	confirm()
	expect(not display.reduce_effects, "Visual options remain editable while paused")
	confirm()
	expect(display.reduce_effects, "Controller can toggle visual option back on without a double activation")
	settings.close()
	settings._show_assistance(true)
	expect(settings.assistance_page.get_node("DamageTaken").disabled, "Gameplay assists stay locked during run")
	expect(not game.set_damage_taken(1), "Gameplay setters reject mid-run changes")
	settings.close()
	settings.close()
	pause.resume()
	expect(Engine.time_scale == 1, "Resume keeps normal game speed")
	game.end_run(true)
	expect(Engine.time_scale == 1 and game.last_run.assisted, "Results restore normal speed and reject records")
	game.continue_to_preparation()
	game.set_damage_taken(0)
	game.start_run()
	game.lantern.take_damage(999)
	game.lantern.take_projectile_damage(999)
	expect(game.lantern.health == game.lantern.max_health and game.phase == game.Phase.RUNNING, "Zero damage grants invincibility")
	game.end_run(true)
	game.continue_to_preparation()
	game.set_damage_taken(0.5)
	await process_frame
	game.free()
	# A save from the retired speed prototype must load at normal speed and
	# retain its assisted history, without writing the old option back out.
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	legacy.game_speed = 0.5
	legacy.assists.slow_game = true
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	game = new_game()
	await process_frame
	expect(game.damage_taken_factor == 0.5 and game.assisted_progress, "Damage factor survives save reload")
	game.start_run()
	expect(Engine.time_scale == 1 and not game.assists.has("slow_game"), "Old speed preference is ignored")
	game.end_run(true)
	game.continue_to_preparation()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	expect(not saved.has("game_speed") and not saved.assists.has("slow_game"), "New saves omit the retired speed preference")
	game.set_damage_taken(1)
	expect(not game.leaderboard_eligible(), "Normal factors do not erase assisted progress")
	game.reset_progress()
	for frame in range(6):
		await process_frame
	game = current_scene
	expect(game.damage_taken_factor == 1 and Engine.time_scale == 1 and game.leaderboard_eligible(), "Reset restores normal gameplay factors and eligibility")
	expect(display.strong_danger_cues and not display.show_turret_ranges, "Progress reset preserves visual preferences")
	game.free()
	for key in original:
		display.set(key, original[key])
	display.settings_path = original_path
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".cfg")
	print("Accessibility checks: %d failures" % failures)
	quit(1 if failures else 0)
