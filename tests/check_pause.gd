extends SceneTree

var failures: int = 0

func _initialize() -> void:
	call_deferred("check")

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event)
	event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = false
	root.push_input(event)

func options() -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_START
	event.pressed = true
	root.push_input(event)
	event = InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_START
	event.pressed = false
	root.push_input(event)

func check() -> void:
	var scene = load("res://main.tscn").instantiate()
	var path := "/tmp/little-last-light-pause-%d.json" % OS.get_process_id()
	scene.save_path = path
	root.add_child(scene)
	await process_frame
	var screen = scene.get_node("PauseScreen")
	var build = scene.get_node("BuildController")
	key(KEY_ESCAPE)
	expect(not paused, "Escape does not pause preparation")
	scene.banked_energy = 20.0
	build.begin_placement()
	key(KEY_ESCAPE)
	expect(not build.placing and not paused, "Escape still cancels placement")
	options()
	expect(scene.lantern.running and not paused, "Options starts a run from preparation")
	scene.encounters._spawn_enemy()
	var enemy = get_nodes_in_group("enemies")[0]
	enemy.max_health = 50.0
	enemy.health = 50.0
	enemy.position = scene.lantern.position + Vector2(21,0)
	await process_frame
	key(KEY_ESCAPE)
	expect(paused and screen.overlay.visible, "Escape opens pause screen")
	var lantern = scene.lantern
	var state: Array = [lantern.position, lantern.elapsed, lantern.energy, lantern.health, scene.encounters.spawn_progress, scene.autosave_elapsed, enemy.position, enemy.health, scene.get_node("Turret").cooldown]
	var light: int = lantern.brightness
	key(KEY_D)
	key(KEY_B)
	for frame in range(12):
		await process_frame
	var after: Array = [lantern.position, lantern.elapsed, lantern.energy, lantern.health, scene.encounters.spawn_progress, scene.autosave_elapsed, enemy.position, enemy.health, scene.get_node("Turret").cooldown]
	expect(state == after, "Pause freezes movement, time, income, damage, spawns, autosave timer, and turret firing")
	expect(not build.placing and scene.banked_energy == 20.0, "Pause does not enable building or spend energy")
	expect(lantern.brightness == light, "Pause UI does not change brightness")
	options()
	expect(not paused and not screen.overlay.visible, "Options resumes without starting a new run")
	var before: float = lantern.elapsed
	for frame in range(4):
		await process_frame
	expect(lantern.elapsed > before, "Run advances after resuming")
	key(KEY_P)
	expect(paused, "P can pause")
	screen.resume_button.pressed.emit()
	expect(not paused and not screen.overlay.visible, "Resume button restores game processing")
	lantern.energy = 42.5
	lantern.elapsed = 90.0
	key(KEY_P)
	screen.end_run_button.pressed.emit()
	expect(not paused and not screen.overlay.visible, "End Run closes pause and unpauses preparation")
	expect(scene.phase == scene.Phase.RESULTS and not lantern.running, "End Run opens results")
	expect(scene.banked_energy == 62.5 and lantern.energy == 0.0, "End Run banks all earnings")
	expect(scene.last_run.get("voluntary", false) and scene.last_run.duration == 90.0, "Voluntary ending records its result")
	expect(get_nodes_in_group("enemies").is_empty(), "End Run clears enemies")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(path))
	expect(saved.energy == 62.5, "End Run saves banked energy")
	screen.end_run_button.pressed.emit()
	expect(scene.banked_energy == 62.5, "Repeated End Run cannot bank twice")
	scene.continue_to_preparation()
	scene.start_run()
	expect(lantern.running and not paused and lantern.energy == 0.0, "A fresh run starts normally after ending")
	scene.free()
	DirAccess.remove_absolute(path)
	if failures == 0:
		print("PASS: preparation controls, pause freeze, keyboard/controller toggle, resume and end run, saved earnings, restart")
	quit(1 if failures else 0)
