extends SceneTree

var path := "/tmp/lll-slow-upgrades-%d.json" % OS.get_process_id()

func _initialize() -> void:
	call_deferred("check")

func game() -> Node2D:
	var scene = load("res://main.tscn").instantiate()
	scene.save_path = path
	root.add_child(scene)
	current_scene = scene
	scene.set_process(false)
	scene.get_node("GameHUD").leaderboard.api_url = ""
	return scene

func joy(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 3
	event.button_index = button
	event.pressed = true
	root.push_input(event)
	event.pressed = false
	root.push_input(event)

func check() -> void:
	var scene := game()
	var prep = scene.get_node("PreparationUI")
	var build = scene.get_node("BuildController")
	prep.open_view(prep.View.UPGRADES)
	assert(build.damage_button.visible and build.health_button.visible and prep.slow_buttons.slow_rate.visible)
	assert(prep.upgrade_groups.get_child_count() == 3 and prep.upgrade_progress.size() == 8)
	assert(not scene.buy_upgrade("slow_rate"), "Cannot buy without funds")
	scene.banked_energy = 20000.0
	build._update_interface()
	prep.slow_buttons.slow_rate.grab_focus()
	joy(JOY_BUTTON_A)
	assert(scene.slow_levels.slow_rate == 1 and scene.banked_energy == 19880.0, "Controller buys exactly one level")
	assert(prep.upgrade_summaries["Slow turrets"].text.contains("2.9s"))
	assert(prep.upgrade_progress.slow_rate.get_child(5).text.strip_edges() == "1/5")
	joy(JOY_BUTTON_B)
	assert(prep.view == prep.View.HOME)
	build.begin_placement("pulse")
	assert(build.try_place(Vector2(100, 100)))
	var pulse = get_nodes_in_group("turrets").back()
	assert(is_equal_approx(pulse.fire_interval, 2.85), "New turrets inherit previously bought upgrades")
	assert(scene.buy_upgrade("slow_strength") and scene.buy_upgrade("slow_duration"))
	assert(is_equal_approx(pulse.slow_factor, 0.5) and is_equal_approx(pulse.slow_duration, 1.45), "Existing turrets update immediately")
	assert(get_nodes_in_group("turrets")[0].damage == 1 and get_nodes_in_group("turrets")[0].fire_interval == 1.5, "Slow upgrades do not change damage turrets")
	assert(scene.defense_investment() == 440.0, "Investment includes 380 upgrades and 60 turret cost")
	for kind in scene.slow_levels:
		assert(scene.upgrade_cost(kind) == scene.UPGRADE_BASE_COSTS[kind] * 2)
		for i in range(4):
			assert(scene.buy_upgrade(kind))
		var funds: float = scene.banked_energy
		assert(not scene.buy_upgrade(kind) and scene.banked_energy == funds, "Cap rejects further spending")
	assert(is_equal_approx(pulse.fire_interval, 2.25) and is_equal_approx(pulse.slow_factor, 0.3) and is_equal_approx(pulse.slow_duration, 2.05))
	prep.open_view(prep.View.UPGRADES)
	for button in prep.slow_buttons.values():
		assert(button.disabled and button.text.contains("MAX") and not button.text.contains("→"))
	for kind in scene.slow_levels:
		assert(prep.upgrade_progress[kind].get_child(5).text.strip_edges() == "5/5")
	scene.save_progress()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for kind in scene.slow_levels:
		for invalid in [-1, 1.5, 6, "2"]:
			var bad := data.duplicate(true)
			bad.upgrades[kind] = invalid
			assert(not scene._valid_save(bad))
	scene.free()
	await process_frame
	scene = game()
	pulse = get_nodes_in_group("turrets").back()
	assert(scene.slow_levels == {"slow_rate": 5, "slow_strength": 5, "slow_duration": 5})
	assert(is_equal_approx(pulse.fire_interval, 2.25) and is_equal_approx(pulse.slow_factor, 0.3) and is_equal_approx(pulse.slow_duration, 2.05))
	scene.start_run()
	scene.lantern.set_process(false)
	scene.lantern.position = Vector2(800, 100)
	scene._spawn_enemy()
	var enemy = get_nodes_in_group("enemies")[0]
	enemy.set_process(false)
	enemy.position = pulse.position + Vector2(170, 0)
	pulse._process(0.01)
	assert(is_equal_approx(enemy.slow_factor, 0.3) and is_equal_approx(enemy.slow_remaining, 2.05), "Actual pulse uses upgraded strength and duration")
	enemy._consume_slow(2.1)
	pulse._process(2.1)
	assert(enemy.slow_remaining == 0, "Even maximum upgrades leave an unslowed gap")
	pulse._process(0.2)
	assert(is_equal_approx(enemy.slow_remaining, 2.05) and is_equal_approx(enemy.slow_factor, 0.3), "Next pulse reapplies slow after the gap")
	enemy._consume_slow(3.0)
	enemy.position = pulse.position + Vector2(176, 0)
	pulse.cooldown = 0.0
	pulse._process(0.01)
	assert(enemy.slow_remaining == 0.0, "Targets outside the expanded range remain unaffected")
	assert(not scene.buy_upgrade("slow_rate"), "Combat cannot upgrade")
	scene.end_run(true)
	scene.continue_to_preparation()
	scene.get_node("BuildController").reset_layout()
	assert(scene.slow_levels.slow_strength == 5, "Layout refund preserves upgrades")
	scene.free()
	await process_frame
	# Legacy M14 saves have no slow upgrade levels.
	for kind in ["slow_rate", "slow_strength", "slow_duration"]:
		data.upgrades.erase(kind)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	scene = game()
	pulse = get_nodes_in_group("turrets").back()
	assert(scene.slow_levels.slow_rate == 0 and pulse.fire_interval == 3.0 and is_equal_approx(pulse.slow_factor, 0.55) and pulse.slow_duration == 1.3)
	scene.free()
	DirAccess.remove_absolute(path)
	print("PASS: grouped upgrades/progress/controller, prices, investment, existing/future turrets, caps, persistence/migration, actual upgraded pulses")
	quit()
