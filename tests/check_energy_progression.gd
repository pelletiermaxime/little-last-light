extends SceneTree

var failures := 0
var path := "/tmp/lll-energy-%d.json" % OS.get_process_id()

func _initialize() -> void:
	call_deferred("check")

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func game() -> Node2D:
	var scene = load("res://main.tscn").instantiate()
	scene.save_path = path
	root.add_child(scene)
	scene.set_process(false)
	scene.lantern.set_process(false)
	scene.lantern.set_physics_process(false)
	return scene

func check() -> void:
	DirAccess.remove_absolute(path)
	var scene := game()
	var prep = scene.get_node("PreparationUI")
	prep.open_view(prep.View.UPGRADES)
	expect(prep.energy_button.visible and prep.energy_button.disabled, "Energy upgrade is visible but unaffordable on a fresh profile")
	scene.banked_energy = 1500.0
	scene.get_node("BuildController")._update_interface()
	prep.energy_button.pressed.emit()
	expect(scene.energy_level == 1 and scene.banked_energy == 1400.0, "Energy upgrade button buys one permanent level for 100")
	expect(prep.energy_button.text.contains("+25%") and prep.energy_button.text.contains("200 energy"), "UI shows current bonus and next price")
	scene.start_run()
	scene._set_turrets_active(false)
	expect(not scene.buy_upgrade("energy"), "Income upgrades cannot be purchased during combat")
	scene.lantern.brightness = 2
	scene.lantern._process(180.0)
	expect(is_equal_approx(scene.lantern.energy, 540.0), "High brightness with one upgrade earns 540 in three minutes")
	scene.lantern.elapsed = 300.0
	scene._spawn_boss()
	var boss = get_nodes_in_group("bosses")[0]
	boss.take_damage(1.0)
	expect(not scene.boss_reward_earned, "Damaging the boss gives no reward")
	boss.take_damage(10000.0)
	boss.take_damage(10000.0)
	expect(scene.boss_reward_earned and is_equal_approx(scene.lantern.energy, 915.0), "Defeating the boss pays an amplified 375 once at energy level one")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	expect(is_equal_approx(saved.energy, 2315.0), "Boss reward is saved immediately with current run earnings")
	expect(scene.get_node("GameHUD").schedule_text.text.contains("+375 energy"), "Boss reward has visible feedback")
	scene.end_run(true)
	expect(is_equal_approx(scene.banked_energy, 2315.0) and scene.last_run.boss_bonus == 375.0, "End Run banks the reward exactly once and retains its breakdown")
	expect(scene.get_node("ResultsScreen").stats.text.contains("Includes 375 energy"), "Results identify the boss reward within the total")
	scene.free()
	await process_frame
	scene = game()
	expect(scene.energy_level == 1 and is_equal_approx(scene.banked_energy, 2315.0), "Income level and reward survive reopening")
	scene.banked_energy = 5000.0
	for cost in [200.0, 400.0, 800.0, 1600.0]:
		expect(scene.upgrade_cost("energy") == cost and scene.buy_upgrade("energy"), "Remaining income upgrade levels use the doubling ladder")
	expect(scene.energy_multiplier() == 2.25 and not scene.buy_upgrade("energy"), "Income upgrade caps at five levels and 2.25x passive earnings")
	scene.start_run()
	scene._set_turrets_active(false)
	expect(not scene.boss_reward_earned, "New runs can earn a new boss reward")
	scene.lantern.brightness = 0
	scene.lantern._process(10.0)
	expect(is_equal_approx(scene.lantern.energy, 13.5), "Maximum energy upgrade multiplies low-brightness income")
	scene._spawn_boss()
	scene.end_run(true)
	expect(scene.last_run.boss_bonus == 0.0 and is_equal_approx(scene.last_run.energy, 13.5), "Ending a run with a living boss never grants its reward")
	for level in range(6):
		scene.continue_to_preparation()
		scene.energy_level = level
		scene.start_run()
		scene._set_turrets_active(false)
		expect(scene.boss_reward_amount == 0.0, "New runs clear the previous reward amount")
		scene._spawn_boss()
		var next_boss = get_nodes_in_group("bosses")[0]
		next_boss.take_damage(10000.0)
		next_boss.take_damage(10000.0)
		var expected := 300.0 + 75.0 * level
		expect(scene.lantern.energy == expected and scene.boss_reward_amount == expected, "Boss reward scales once at energy level %d" % level)
		scene.end_run(true)
		expect(scene.last_run.boss_bonus == expected, "Results retain the scaled reward at level %d" % level)
	scene.free()
	await process_frame
	# Older profiles default to no income upgrade; invalid levels remain rejected.
	saved.upgrades.erase("energy")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(saved))
	file.close()
	scene = game()
	expect(scene.energy_level == 0 and scene.save_is_readable, "Legacy saves load with zero energy upgrades")
	for invalid in [-1, 1.5, 6, "2"]:
		var bad := saved.duplicate(true)
		bad.upgrades.energy = invalid
		expect(not scene._valid_save(bad), "Invalid income levels are rejected")
	scene.free()
	DirAccess.remove_absolute(path)
	if failures == 0:
		print("PASS: income purchase/UI, rates, cap, persistence, boss reward once, banking, cleanup and migration")
	quit(1 if failures else 0)
