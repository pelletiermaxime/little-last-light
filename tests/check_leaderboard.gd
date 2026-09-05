extends SceneTree

var failures := 0
var path := "/tmp/little-last-light-leaderboard-%d.json" % OS.get_process_id()


func _initialize() -> void:
	call_deferred("check")


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func game(version: String) -> Node2D:
	var scene = load("res://main.tscn").instantiate()
	scene.save_path = path
	scene.game_version = version
	root.add_child(scene)
	# Keep offline-state assertions independent of this worktree's configured API.
	scene.get_node("GameHUD").leaderboard.api_url = ""
	scene.get_node("GameHUD").leaderboard.refresh()
	scene.set_process(false)
	scene.lantern.set_process(false)
	scene.lantern.set_physics_process(false)
	return scene


func finish(scene: Node2D, seconds: float) -> void:
	scene.start_run()
	scene.lantern.elapsed = seconds
	scene.lantern.take_damage(1000)
	scene.get_node("GameHUD").refresh()


func check() -> void:
	var scene := game("0.1.0")
	var panel = scene.get_node("GameHUD").leaderboard
	expect(scene.leaderboard_profile.token.length() == 64, "Creates anonymous identity")
	expect(not panel.publish.visible, "No publish offer before completed personal best")
	finish(scene, 65.125)
	expect(panel.publish.visible and scene.leaderboard_profile.pending.durationMs == 65125, "New best offers precise score")
	expect(panel.publish.disabled, "Unconfigured build stays local")
	var token: String = scene.leaderboard_profile.token
	scene.leaderboard_profile.username = "Keeper"
	scene.save_progress()
	scene.free()
	await process_frame
	scene = game("0.1.0")
	await process_frame
	panel = scene.get_node("GameHUD").leaderboard
	expect(scene.best_time == 65.125 and scene.leaderboard_profile.token == token, "Best and identity survive restart")
	expect(panel.username.text == "Keeper" and panel.publish.visible, "Name and pending offer survive restart")
	panel.username.grab_focus()
	var event := InputEventKey.new()
	event.keycode = KEY_B
	event.physical_keycode = KEY_B
	event.pressed = true
	scene.banked_energy = 100
	scene.get_node("BuildController")._unhandled_input(event)
	expect(not scene.get_node("BuildController").placing, "Username typing cannot buy a turret")
	panel.username.release_focus()
	panel._skip()
	finish(scene, 65.125)
	expect(not panel.publish.visible, "Tied record does not prompt")
	finish(scene, 10)
	expect(not panel.publish.visible, "Lower record does not prompt")
	finish(scene, 70)
	panel.api_url = "https://example.convex.site"
	panel.sending = scene.leaderboard_profile.pending.duplicate()
	panel._completed(HTTPRequest.RESULT_CANT_CONNECT, 0, [], PackedByteArray())
	expect(not scene.leaderboard_profile.pending.is_empty() and panel.notice.text.contains("failed"), "Network failure retains pending record")
	panel.sending = scene.leaderboard_profile.pending.duplicate()
	finish(scene, 80)
	panel._completed(HTTPRequest.RESULT_SUCCESS, 200, [], '{"ok":true}'.to_utf8_buffer())
	expect(scene.leaderboard_profile.pending.durationMs == 80000, "Older response cannot clear newer record")
	panel.sending = scene.leaderboard_profile.pending.duplicate()
	panel._completed(HTTPRequest.RESULT_SUCCESS, 200, [], '{"ok":true}'.to_utf8_buffer())
	expect(scene.leaderboard_profile.pending.is_empty(), "Successful publish clears matching pending score")
	scene.free()
	await process_frame
	scene = game("0.2.0")
	expect(scene.best_time == 0 and scene.banked_energy == 100, "New version resets best but keeps economy")
	finish(scene, 5)
	expect(scene.last_run.new_best and scene.version_bests["0.1.0"] == 80, "New release record keeps older version history")
	scene.free()
	await process_frame
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string('{"version":1,"energy":42,"best_time":99,"turrets":[[0.5,0.5]]}')
	file.close()
	scene = game("0.3.0")
	expect(scene.best_time == 0 and scene.legacy_best_time == 99 and scene.banked_energy == 42, "Legacy save migrates without attributing unknown version")
	scene.save_progress()
	scene.free()
	await process_frame
	scene = game("0.3.0")
	expect(scene.legacy_best_time == 99, "Legacy record preserved after migration")
	scene.free()
	DirAccess.remove_absolute(path)
	if failures == 0:
		print("PASS: version isolation, save migration, opt-in, identity, input focus, retries, stale response protection")
	quit(1 if failures else 0)
