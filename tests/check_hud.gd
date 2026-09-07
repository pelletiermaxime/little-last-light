extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("check")


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func check() -> void:
	var scene = load("res://main.tscn").instantiate()
	var test_path := "/tmp/little-last-light-hud-%d.json" % OS.get_process_id()
	scene.save_path = test_path
	root.add_child(scene)
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	var hud = scene.get_node("GameHUD")
	var build = scene.get_node("BuildController")
	var lantern = scene.lantern
	expect(not hud.brightness_indicator.visible, "Preparation hides combat brightness controls")
	hud.brightness_indicator.pressed.emit()
	expect(lantern.brightness == 0, "Hidden brightness actions cannot change preparation state")
	expect(hud.format_time(125.9) == "02:05", "Survival time uses whole minutes and seconds")
	scene.continue_to_preparation()
	scene.start_run()
	for level in range(3):
		lantern.set_brightness((level + 2) % 3)
		hud.brightness_indicator.pressed.emit()
		expect(lantern.brightness == level, "Brightness buttons select their own level")
		expect(hud.displayed_brightness == level, "Selected brightness is immediately shown")
		expect(hud.brightness_indicator.text.contains("+%.1f/s" % lantern.ENERGY_RATES[level]), "Income labels match fractional gameplay rates")
	lantern.elapsed = 65.0
	lantern.energy = 28.4
	lantern.health = 6.0
	hud.refresh()
	expect(hud.health_bar.value == 6.0 and hud.health_text.text.contains("DANGER"), "Low health has a number, bar, and warning")
	expect(hud.subheading.text == "01:05", "Run timer displays actual elapsed time")
	expect(hud.brightness_indicator.level == 2, "Three segments indicate high brightness")
	for frame in range(5):
		await process_frame
	expect(hud.health_group.size.y <= 42 and hud.timer_group.size.y <= 64, "HP and time stay compact after container layout")
	expect(not hud.health_group is PanelContainer and not hud.timer_group is PanelContainer, "HP and time have no card backgrounds")
	scene.banked_energy = 45.0
	lantern.take_damage(100.0)
	hud.refresh()
	build._update_interface()
	expect(is_equal_approx(scene.last_run.energy, 28.4), "Recap captures earnings before banking clears them")
	expect(is_equal_approx(scene.banked_energy, 73.4), "HUD does not change banking arithmetic")
	expect(scene.last_run.new_best and scene.last_run.duration == 65.0, "Recap records survival and personal best")
	expect(hud.earnings.text == "+28 energy earned", "Recap retains earned amount after death")
	lantern._process(0.2)
	expect(lantern.hit_flash == 0.0 and lantern.energy == 0.0, "Hit feedback fades after death without producing preparation income")
	expect(not scene.get_node("PreparationUI").card.visible and scene.get_node("ResultsScreen").overlay.visible, "Results replace preparation controls")
	expect(not build.build_button.disabled, "Earned energy makes the next turret affordable")
	scene.continue_to_preparation()
	build.begin_placement()
	expect(build.try_place(Vector2(100, 100)), "Purchase after recap succeeds")
	build._update_interface()
	expect(build.build_button.disabled and int(ceil(build.turret_cost() - scene.banked_energy)) == 72, "Purchase refreshes affordability at the next price")
	scene.save_message = "Save test warning"
	hud.refresh()
	expect(hud.save_notice.visible and hud.save_notice.text == scene.save_message, "Save failures remain visible")
	scene.save_message = ""
	scene.continue_to_preparation()
	scene.start_run()
	hud.refresh()
	expect(hud.health_bar.value == lantern.max_health and hud.earnings.text == "+0 energy", "New run replaces recap with fresh live values")
	lantern.elapsed = 10.0
	lantern.take_damage(100.0)
	expect(not scene.last_run.new_best and scene.best_time == 65.0, "Shorter run does not claim a personal best")
	scene.free()
	DirAccess.remove_absolute(test_path)
	if failures == 0:
		print("PASS: brightness selection, health HUD, recap, affordability, save warning, restart")
	quit(1 if failures else 0)
