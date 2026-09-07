extends SceneTree

var failures: int = 0
var path: String

func _initialize() -> void:
	path = "/tmp/little-last-light-m4-%d.json" % OS.get_process_id()
	call_deferred("check")

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func new_game() -> Node2D:
	var scene = load("res://main.tscn").instantiate()
	scene.save_path = path
	root.add_child(scene)
	current_scene = scene
	scene.set_process(false)
	scene.lantern.set_process(false)
	scene.lantern.set_physics_process(false)
	return scene

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	root.push_input(event)

func check() -> void:
	var game = new_game()
	var lantern = game.lantern
	var build = game.get_node("BuildController")
	await process_frame
	expect(game.phase == game.Phase.PREPARATION, "Starts in preparation")
	lantern._process(10)
	game._process(10)
	lantern.take_damage(10)
	expect(lantern.energy == 0 and lantern.elapsed == 0 and lantern.health == lantern.max_health, "Preparation has no income, time, or damage")
	expect(get_nodes_in_group("enemies").is_empty(), "Preparation does not spawn enemies")
	key(KEY_B)
	expect(not build.placing, "Cannot buy without banked energy")
	var turret = get_nodes_in_group("turrets")[0]
	var original: Vector2 = turret.position
	build.begin_move(turret)
	key(KEY_ENTER)
	expect(game.phase == game.Phase.PREPARATION, "Cannot start mid-placement")
	key(KEY_ESCAPE)
	expect(turret.visible and turret.position == original and not build.placing, "Cancelled move restores original")
	key(KEY_ENTER)
	expect(game.phase == game.Phase.RUNNING and lantern.running, "Enter starts combat")
	game.banked_energy = 30.0
	key(KEY_B)
	build.begin_move(turret)
	expect(not build.placing, "Build and move locked during combat")
	var initial: float = game.current_spawn_interval()
	lantern._process(20)
	expect(is_equal_approx(game.current_spawn_interval(), initial * 0.65 / 2), "20 seconds combines the time ramp with the pressure period")
	lantern._process(5)
	lantern.brightness = 2
	expect(game.current_spawn_interval() < initial / 2, "Brightness adds pressure")
	lantern._process(1)
	expect(lantern.energy == 31.0, "Only this-run earnings belong to lantern")
	expect(game.save_progress(), "Mid-run save succeeds")
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	expect(data.energy == 61.0 and game.banked_energy == 30.0, "Autosave includes earnings without double banking")
	game._spawn_enemy()
	lantern.take_damage(1000)
	expect(game.phase == game.Phase.RESULTS and game.banked_energy == 61.0 and lantern.energy == 0, "Death banks once")
	game._on_lantern_died()
	expect(game.banked_energy == 61.0, "Repeated death cannot duplicate currency")
	expect(get_nodes_in_group("enemies").is_empty() and not turret.can_process(), "Death clears enemies and stops turrets")
	game.continue_to_preparation()
	key(KEY_B)
	expect(build.placing, "Can buy after death despite zero health")
	expect(not build.try_place(original) and not build.try_place(Vector2(-10, 0)), "Invalid placement rejected")
	var arena: Vector2 = game.get_arena_rect().size
	var spot := Vector2(arena.x * 0.85, arena.y * 0.35)
	expect(build.try_place(spot), "Preparation purchase succeeds")
	expect(game.banked_energy == 41.0 and get_nodes_in_group("turrets").size() == 2, "Purchase deducts 20 once")
	expect(not build.try_place(spot + Vector2(40, 0)), "Duplicate click cannot buy again")
	build.begin_move(turret)
	var moved := original + Vector2(0, -65)
	expect(build.try_place(moved), "Can reposition freely")
	expect(game.banked_energy == 41.0 and turret.position == moved, "Move costs no energy")
	game.continue_to_preparation()
	game.start_run()
	expect(lantern.health == lantern.max_health and lantern.energy == 0 and lantern.elapsed == 0 and lantern.brightness == 0, "New run resets health, earnings, timer and brightness")
	expect(game.banked_energy == 41.0 and get_nodes_in_group("turrets").size() == 2 and turret.position == moved, "New run retains purchases and layout")
	lantern._process(3)
	game.save_progress()
	game.free()
	await process_frame
	game = new_game()
	expect(game.phase == game.Phase.PREPARATION and game.banked_energy == 44.0, "Reopening banks saved active-run earnings")
	expect(get_nodes_in_group("turrets").size() == 2, "Reopening restores all turrets")
	expect(get_nodes_in_group("turrets")[0].position.distance_to(moved) < 0.01, "Reopening restores positions")
	expect(game.best_time == 26.0, "Best completed run persists")
	game.free()
	await process_frame
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("broken save")
	file.close()
	game = new_game()
	expect(not game.save_is_readable and not game.save_progress(), "Corrupt save is not overwritten")
	expect(FileAccess.get_file_as_string(path) == "broken save", "Original corrupt file is preserved")
	game.free()
	await process_frame
	for empty_contents in ["", " \n\t "]:
		file = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(empty_contents)
		file.close()
		game = new_game()
		expect(game.save_is_readable and game.banked_energy == 0, "Empty save starts a fresh profile")
		game.continue_to_preparation()
		game.start_run()
		game.lantern._process(7)
		game.lantern.take_damage(1000)
		expect(game.banked_energy == 7 and game.save_progress(), "Fresh profile saves earned energy")
		game.free()
		await process_frame
		game = new_game()
		expect(game.banked_energy == 7, "Energy from formerly empty save survives reopening")
		game.free()
		await process_frame
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("invalid")
	file.close()
	game = new_game()
	file = FileAccess.open(path, FileAccess.WRITE)
	file.close()
	expect(game.save_progress() and game.save_is_readable, "Clearing a bad file allows an open session to save again")
	game.free()
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".tmp")
	if failures == 0:
		print("PASS: phases, income, pressure, death banking, purchases, repositioning, fresh runs, save/reopen, corrupt save")
	quit(0 if failures == 0 else 1)
