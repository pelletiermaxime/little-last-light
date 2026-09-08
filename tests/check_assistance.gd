extends SceneTree

var failures := 0
var path := "/tmp/lll-assistance-%d.json" % OS.get_process_id()

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
	# Godot's south face button maps to Cross on PlayStation controllers.
	var event := InputEventJoypadButton.new()
	event.device = 3
	event.button_index = JOY_BUTTON_A
	event.pressed = true
	root.push_input(event)
	event.pressed = false
	root.push_input(event)

func check() -> void:
	var game = new_game()
	await process_frame
	expect(game.leaderboard_eligible(), "Fresh progress is eligible")
	var settings = game.get_node("SettingsScreen")
	settings.open(null)
	settings.assistance_button.pressed.emit()
	expect(settings.assistance_page.visible and not settings.volume_button.visible, "Assistance is a separate settings page")
	root.size = Vector2i(640, 480)
	for frame in range(6):
		await process_frame
	for button in ["CheapUpgrades", "ShortNight", "SlowEnemies", "BackButton"]:
		expect(root.get_visible_rect().encloses(settings.assistance_page.get_node(button).get_global_rect()), "Assistance control fits a small window: " + button)
	if "--capture-assistance" in OS.get_cmdline_user_args():
		root.size = Vector2i(960, 720)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/lll-assistance.png")
	var cheap: CheckButton = settings.assistance_page.get_node("CheapUpgrades")
	cheap.grab_focus()
	confirm()
	expect(cheap.button_pressed and game.assists.cheap_upgrades, "Controller confirm toggles on once across press and release")
	confirm()
	expect(not cheap.button_pressed and not game.assists.cheap_upgrades, "Second controller confirm toggles off")
	confirm()
	expect(game.assists.cheap_upgrades and game.assisted_progress, "UI enables assistance and marks progress")
	game.banked_energy = 60
	expect(game.buy_upgrade("damage") and game.damage_level == 1 and game.banked_energy == 0, "Half-price upgrade purchases use displayed cost")
	game.set_assist("cheap_upgrades", false)
	expect(game.upgrade_cost("damage") == 240 and not game.leaderboard_eligible(), "Turning assist off restores price but not eligibility")
	game.set_assist("short_night", true)
	game.set_assist("slow_enemies", true)
	settings.close()
	expect(settings.is_open() and not settings.assistance_page.visible, "Back returns to Settings")
	settings.close()
	game.start_run()
	expect(game.run_assisted and not game.set_assist("short_night", false), "Assists cannot change during a run")
	game.get_node("GameHUD").refresh()
	expect("ASSISTED" in game.get_node("GameHUD").save_notice.text, "Live HUD identifies assisted run")
	game.get_node("PauseScreen").pause()
	settings.open(null)
	settings._show_assistance(true)
	expect(settings.assistance_page.get_node("ShortNight").disabled, "Paused-run assist controls are locked")
	settings.close()
	settings.close()
	expect(paused, "Closing assistance and settings leaves the run paused")
	game.get_node("PauseScreen").resume()
	game.lantern.elapsed = 10
	expect(game.encounter_time() == 20 and game.ENCOUNTER_SCHEDULE.chargers_enabled(game.encounter_time()), "First pressure and chargers arrive at 10 seconds")
	game.lantern.elapsed = 20
	expect(game.ENCOUNTER_SCHEDULE.period(game.encounter_time()) == "Recovery", "Recovery starts at 20 seconds")
	game.lantern.elapsed = 149.99
	game._process(0)
	expect(not game.boss_spawned, "Drencher does not arrive early")
	game.lantern.elapsed = 150
	game._process(0)
	expect(game.boss_spawned, "Drencher arrives at 2:30")
	var drencher = get_nodes_in_group("bosses")[0]
	expect(drencher.assist_movement_factor == 0.5 and drencher.arrival_remaining == 3, "Boss movement is halved but arrival warning preserved")
	game.lantern.elapsed = 299.99
	game.update_rainkeeper_encounter()
	expect(not game.rainkeeper_spawned, "Rainkeeper does not arrive early")
	game.lantern.elapsed = 300
	game.update_rainkeeper_encounter()
	expect(game.rainkeeper_spawned and get_nodes_in_group("rainkeepers")[0].assist_movement_factor == 0.5, "Rainkeeper arrives at 5:00 and receives movement assistance")
	game.lantern.elapsed = 449.99
	expect(not game.update_final_encounter(), "Snuffer does not arrive early")
	game.lantern.elapsed = 450
	expect(game.update_final_encounter(), "Snuffer arrives at 7:30")
	var snuffer = get_nodes_in_group("final_bosses")[0]
	snuffer._fire_ring()
	expect(is_equal_approx(get_nodes_in_group("enemy_projectiles")[0].velocity.length(), 82.5), "Enemy projectiles travel at half speed")
	game._spawn_enemy()
	game._spawn_charger()
	for enemy in get_nodes_in_group("enemies"):
		expect(enemy.assist_movement_factor == 0.5, "All enemy types receive movement assistance")
	var pursuer = get_nodes_in_group("enemies").filter(func(enemy): return not enemy.is_in_group("bosses") and not enemy.is_in_group("chargers"))[0]
	game.lantern.position = Vector2(600, 300)
	pursuer.position = Vector2(100, 300)
	pursuer.heading = Vector2.RIGHT
	pursuer._process(1)
	expect(is_equal_approx(pursuer.position.x, 142.5), "Pursuer covers half its normal distance")
	pursuer.apply_slow(0.5, 2)
	pursuer._process(1)
	expect(is_equal_approx(pursuer.position.x, 163.75), "Pulse slow stacks with assistance")
	game.lantern.energy = 123
	game.lantern.elapsed = 460
	game.end_run(false, true)
	expect(game.last_run.assisted and game.last_run.survival == 450 and not game.last_run.new_best, "Assisted victory uses shorter survival cap without record")
	expect(game.leaderboard_profile.pending.is_empty() and game.version_clears.is_empty() and game.best_time == 0, "Assisted clear creates no competitive records")
	expect("Assisted run" in game.get_node("ResultsScreen").best.text, "Results identify assistance")
	game.continue_to_preparation()
	game.set_assist("short_night", false)
	game.set_assist("slow_enemies", false)
	await process_frame
	game.free()
	game = new_game()
	await process_frame
	expect(game.assisted_progress and not game.assists.values().has(true) and game.banked_energy == 123, "Save reload preserves eligibility lock and banked earnings with every assist off")
	game.start_run()
	game.lantern.elapsed = 901
	game.end_run(false, true)
	expect(game.last_run.assisted and game.leaderboard_profile.pending.is_empty(), "Later unassisted run using assisted progress stays disqualified")
	game.continue_to_preparation()
	expect(game.reset_progress(), "Reset succeeds")
	await process_frame
	game = current_scene
	expect(game.leaderboard_eligible() and not game.assists.values().has(true), "Reset gives fresh eligible progress with assists off")
	game.set_process(false)
	game.lantern.set_process(false)
	game.start_run()
	game.lantern.elapsed = 12
	game.end_run(true)
	expect(not game.leaderboard_profile.pending.is_empty(), "Fresh normal run still earns pending record")
	var old_record: Dictionary = game.leaderboard_profile.pending.duplicate(true)
	game.continue_to_preparation()
	game.set_assist("slow_enemies", true)
	expect(game.leaderboard_profile.pending.is_empty() and game.best_time == 12, "Enabling assistance clears pending submission and preserves historical best")
	# Even a stale in-memory pending payload cannot bypass the publishing guard.
	game.leaderboard_profile.pending = old_record
	var leaderboard = game.get_node("GameHUD").leaderboard
	leaderboard.api_url = "https://example.invalid"
	leaderboard.username.text = "TestPlayer"
	leaderboard._publish()
	leaderboard.refresh()
	expect(leaderboard.sending.is_empty() and not leaderboard.publish.visible, "Publishing boundary rejects assisted progress with stale pending data")
	await process_frame
	game.free()
	DirAccess.remove_absolute(path)
	print("Assistance checks: %d failures" % failures)
	quit(1 if failures else 0)
