extends SceneTree

var failures := 0
var path := "/tmp/little-last-light-achievements-%d.json" % OS.get_process_id()


func _initialize() -> void:
	call_deferred("check")


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func game() -> Node2D:
	var scene = load("res://main.tscn").instantiate()
	scene.save_path = path
	scene.game_version = "0.1.0"
	root.add_child(scene)
	scene.achievements.api_url = ""
	scene.get_node("GameHUD").leaderboard.api_url = ""
	scene.set_process(false)
	return scene


func check() -> void:
	var scene := game()
	var tracker: Node = scene.achievements
	var token: String = scene.leaderboard_profile.token
	expect(tracker.data.unlocked.is_empty(), "Free starter does not unlock first purchase")
	scene.start_run()
	expect(tracker.data.started, "A zero-unlock player enters the denominator")
	scene._on_drencher_defeated()
	scene._on_drencher_defeated()
	expect(tracker.data.unlocked == ["defeat_drencher"], "Repeated boss events unlock once")
	var rain = load("res://bosses/rainkeeper.gd").new()
	rain.target = scene.lantern
	rain.defeated.connect(scene._on_rainkeeper_defeated)
	scene.add_child(rain)
	rain.attack = rain.Attack.RECOVERY
	rain.take_damage(10000)
	expect("defeat_rainkeeper" in tracker.data.unlocked, "Rainkeeper killing blow reports an unlock")
	scene.encounters.final_boss_spawned = true
	scene._on_final_boss_defeated()
	expect("defeat_snuffer" in tracker.data.unlocked, "Final boss unlock is saved before ending the run")
	scene.continue_to_preparation()
	scene.banked_energy = 1000
	var builder: Node = scene.get_node("BuildController")
	builder.begin_move(scene.get_node("Turret"))
	builder.try_place(Vector2(120, 120))
	expect("first_tower" not in tracker.data.unlocked, "Moving a free tower is not a purchase")
	builder.begin_placement()
	expect(not builder.try_place(Vector2(-1, -1)), "Invalid purchase fails")
	expect("first_tower" not in tracker.data.unlocked, "Invalid purchase cannot unlock")
	expect(builder.try_place(Vector2(300, 120)), "Valid purchase succeeds")
	expect("first_tower" in tracker.data.unlocked, "Paid tower unlocks")
	tracker.sent = ["defeat_drencher"]
	tracker._completed(HTTPRequest.RESULT_SUCCESS, 200, [], '{"ok":true}'.to_utf8_buffer())
	expect(not tracker.synced, "An older successful upload cannot discard newer unlocks")
	tracker.sent = tracker.data.unlocked.duplicate()
	tracker._completed(HTTPRequest.RESULT_CANT_CONNECT, 0, [], PackedByteArray())
	expect(not tracker.synced, "Failed upload stays pending")
	scene.free()
	# Gameplay resets and release changes can replace this file; identity stays separate.
	DirAccess.remove_absolute(path)
	scene = game()
	expect(scene.leaderboard_profile.token == token, "Gameplay reset keeps the same score and achievement identity")
	expect(scene.achievements.data.unlocked.size() == 4, "All offline unlocks survive reload")
	scene.save_progress()
	scene.free()
	var previous: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	previous.game_version = "99.0.0"
	load("res://game/progress_store.gd").write_atomic(path, previous)
	scene = game()
	expect(scene.leaderboard_profile.token == token and scene.achievements.data.unlocked.size() == 4, "Release rollover preserves lifetime identity and unlocks")
	scene.free()
	DirAccess.remove_absolute(path + ".achievements-editor.json")
	scene = game()
	expect(scene.leaderboard_profile.token == token, "First achievement update adopts the old score token even across versions")
	scene.free()
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".achievements-editor.json")
	scene = game()
	scene.set_assist("cheap_upgrades", true)
	scene.start_run()
	scene._on_drencher_defeated()
	expect(not scene.achievements.data.started and scene.achievements.data.unlocked.is_empty(), "Assisted play neither enrolls nor unlocks")
	scene.free()
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".achievements-editor.json")
	# Old editor unlocks migrate locally, but must never seed production progress.
	load("res://game/progress_store.gd").write_atomic(path + ".achievements.json", {"token": token, "started": true, "unlocked": ["first_tower"]})
	scene = game()
	expect(scene.achievements.data.unlocked == ["first_tower"], "Migrates the pre-release editor achievement file")
	var exported = load("res://game/achievement_tracker.gd").new()
	scene.add_child(exported)
	exported.setup(scene, false)
	expect(exported.path != scene.achievements.path, "Editor and exported builds use separate local files")
	expect(exported.data.unlocked.is_empty() and not exported.data.started, "Neither legacy nor current editor unlocks seed production")
	exported.unlock("defeat_drencher")
	var editor_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(scene.achievements.path))
	expect(editor_data.unlocked == ["first_tower"], "Exported unlocks do not modify editor achievements")
	scene.free()
	DirAccess.remove_absolute(path + ".achievements.json")
	DirAccess.remove_absolute(path + ".achievements-editor.json")
	DirAccess.remove_absolute(path + ".achievements-export.json")
	print("Achievement checks: %d failures" % failures)
	quit(1 if failures else 0)
