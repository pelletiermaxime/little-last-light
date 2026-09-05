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
	expect(not hud.brightness_box.visible, "Preparation hides combat brightness controls")
	hud.light_buttons[2].pressed.emit()
	expect(lantern.brightness == 0, "Hidden brightness actions cannot change preparation state")
	expect(hud.format_time(125.9) == "02:05", "Survival time uses whole minutes and seconds")
	scene.start_run()
	for level in range(3):
		hud.light_buttons[level].pressed.emit()
		expect(lantern.brightness == level, "Brightness buttons select their own level")
		expect(hud.displayed_brightness == level, "Selected brightness is immediately shown")
		expect(hud.light_buttons[level].text.contains("+%d /s" % int(lantern.ENERGY_RATES[level])), "Income labels match gameplay rates")
	lantern.elapsed = 65.0
	lantern.energy = 28.4
	lantern.health = 24.0
	hud.refresh()
	expect(hud.health_bar.value == 24.0 and hud.health_text.text.contains("DANGER"), "Low health has a number, bar, and warning")
	expect(hud.subheading.text == "01:05", "Run timer displays actual elapsed time")
	scene.banked_energy = 5.0
	lantern.take_damage(100.0)
	hud.refresh()
	build._update_interface()
	expect(is_equal_approx(scene.last_run.energy, 28.4), "Recap captures earnings before banking clears them")
	expect(is_equal_approx(scene.banked_energy, 33.4), "HUD does not change banking arithmetic")
	expect(scene.last_run.new_best and scene.last_run.duration == 65.0, "Recap records survival and personal best")
	expect(hud.earnings.text == "+28 energy earned", "Recap retains earned amount after death")
	lantern._process(0.2)
	expect(lantern.hit_flash == 0.0 and lantern.energy == 0.0, "Hit feedback fades after death without producing preparation income")
	expect(build.bar.get_parent() == hud.panel and hud.panel.get_parent() == hud.scroll, "Recap and actions share a scrollable column instead of overlapping")
	expect(build.overview.text.contains("affordable"), "Recap identifies affordable next purchase")
	build.begin_placement()
	expect(build.try_place(Vector2(100, 100)), "Purchase after recap succeeds")
	build._update_interface()
	expect(build.overview.text.contains("17 more"), "Purchase refreshes progress toward escalating next price")
	scene.save_message = "Save test warning"
	hud.refresh()
	expect(hud.save_notice.visible and hud.save_notice.text == scene.save_message, "Save failures remain visible")
	scene.save_message = ""
	scene.start_run()
	hud.refresh()
	expect(hud.health_bar.value == 100.0 and hud.earnings.text == "+0 energy", "New run replaces recap with fresh live values")
	lantern.elapsed = 10.0
	lantern.take_damage(100.0)
	expect(not scene.last_run.new_best and scene.best_time == 65.0, "Shorter run does not claim a personal best")
	scene.free()
	DirAccess.remove_absolute(test_path)
	if failures == 0:
		print("PASS: brightness selection, health HUD, recap, affordability, save warning, restart")
	quit(1 if failures else 0)
