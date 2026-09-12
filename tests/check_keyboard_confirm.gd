extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("check")

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func key(code: Key, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	event.echo = echo
	root.push_input(event)
	event.pressed = false
	event.echo = false
	root.push_input(event)

func check() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.save_path = "/tmp/lll-keyboard-%d.json" % OS.get_process_id()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var prep = scene.get_node("PreparationUI")
	var settings = scene.get_node("SettingsScreen")
	for frame in range(6):
		await process_frame
	expect(root.gui_get_focus_owner() == scene.get_node("BuildController").start_button, "Main menu starts with Start run focused")
	key(KEY_DOWN)
	expect(root.gui_get_focus_owner() == prep.place_button, "Down moves from Start run to Place turrets")
	key(KEY_UP)
	expect(root.gui_get_focus_owner() == scene.get_node("BuildController").start_button, "Up returns to Start run")
	for button in [prep.place_button, prep.upgrades_button, prep.records_button, prep.achievements_button, prep.settings_button]:
		key(KEY_DOWN)
		expect(root.gui_get_focus_owner() == button, "Down follows vertical main menu order")
	key(KEY_ENTER)
	expect(settings.is_open() and scene.phase == scene.Phase.PREPARATION, "Enter opens selected Settings instead of starting a run")
	if settings.is_open():
		settings.assistance_button.grab_focus()
		key(KEY_KP_ENTER)
		expect(settings.assistance_open, "Numpad Enter opens Assistance")
		key(KEY_ESCAPE)
		key(KEY_ESCAPE)
		expect(not settings.is_open(), "Escape returns through Settings to preparation")
		prep.upgrades_button.grab_focus()
		key(KEY_ENTER)
		expect(prep.view == prep.View.UPGRADES, "Enter opens selected upgrades")
		scene.banked_energy = 1000
		scene.get_node("BuildController")._update_interface()
		scene.get_node("BuildController").damage_button.grab_focus()
		key(KEY_ENTER)
		expect(scene.damage_level == 1, "One Enter press purchases one upgrade")
		key(KEY_ENTER, true)
		expect(scene.damage_level == 1, "Held Enter does not repeat purchases")
		prep.open_view(prep.View.HOME)
		scene.get_node("BuildController").start_button.grab_focus()
		key(KEY_ENTER)
		expect(scene.phase == scene.Phase.RUNNING, "Enter still starts a run when Start run is selected")
		scene.get_node("PauseScreen").pause()
		scene.get_node("PauseScreen").settings_button.grab_focus()
		key(KEY_ENTER)
		expect(settings.is_open() and paused, "Enter opens pause Settings without resuming")
	paused = false
	var path: String = scene.save_path
	scene.free()
	DirAccess.remove_absolute(path)
	if failures == 0:
		print("PASS: Enter and numpad Enter activate focused menus once, including settings, upgrades, start and pause")
	quit(1 if failures else 0)
