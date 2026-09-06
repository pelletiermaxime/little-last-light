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
	scene.continue_to_preparation()
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
	var first_offer: Dictionary = scene.leaderboard_profile.pending.duplicate(true)
	expect(first_offer.energyEarned == 0 and first_offer.energyInvested == 0, "The free starting turret has zero investment")
	expect(first_offer.turretLayout.turrets.size() == 1, "Captures actual turret, not placement preview")
	var arena: Vector2 = scene.get_arena_rect().size
	var turret_point: Vector2 = scene.get_node("Turret").position / arena
	expect(first_offer.turretLayout == {"width": arena.x, "height": arena.y, "turrets": [{"x": turret_point.x, "y": turret_point.y}], "upgrades": {"damage": 0, "fireRate": 0, "health": 0}}, "Layout captures normalized positions, arena aspect ratio and upgrades")
	scene.get_node("Turret").position = Vector2(30, 40)
	expect(scene.leaderboard_profile.pending == first_offer, "Moving a turret cannot change the completed run snapshot")
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
	var restored: Dictionary = scene.leaderboard_profile.pending
	expect(restored.energyEarned == first_offer.energyEarned and restored.energyInvested == first_offer.energyInvested, "Energy survives saving and reopening")
	expect(restored.turretLayout.width == arena.x and restored.turretLayout.height == arena.y and restored.turretLayout.turrets.size() == 1, "Arena and turret count survive reopening")
	expect(is_equal_approx(restored.turretLayout.turrets[0].x, turret_point.x) and is_equal_approx(restored.turretLayout.turrets[0].y, turret_point.y), "Original run positions survive reopening after layout changes")
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
	# M6's voluntary End Run must use the same record and saving path as death.
	scene.continue_to_preparation()
	scene.start_run()
	scene.lantern.elapsed = 12.345
	scene.lantern.energy = 7.0
	var pause_screen = scene.get_node("PauseScreen")
	pause_screen.pause()
	pause_screen.end_run_button.pressed.emit()
	expect(not paused and scene.phase == scene.Phase.RESULTS, "Ending a paused run opens results")
	expect(scene.last_run.voluntary and scene.best_time == 12.345, "End Run records the voluntary personal best")
	expect(scene.leaderboard_profile.pending.version == "0.2.0" and scene.leaderboard_profile.pending.durationMs == 12345, "End Run offers its record for the correct version")
	expect(scene.leaderboard_profile.pending.energyEarned == 7.0 and scene.leaderboard_profile.pending.energyInvested == 0.0, "Unspent savings and run earnings do not count as defense investment")
	expect(scene.get_node("GameHUD").leaderboard.prompt.text.contains("layout will be public"), "Publish offer discloses shared layout")
	expect(scene.get_node("GameHUD").leaderboard.publish.visible, "End Run immediately displays the opt-in offer")
	expect(scene.banked_energy == 107.0, "End Run banks energy alongside the leaderboard record")
	scene.free()
	await process_frame
	scene = game("0.2.0")
	expect(scene.best_time == 12.345 and scene.leaderboard_profile.pending.durationMs == 12345, "Voluntary record and pending publication survive reopening")
	expect(scene.banked_energy == 107.0, "Leaderboard persistence preserves End Run earnings")
	var release_offer: Dictionary = scene.leaderboard_profile.pending.duplicate(true)
	scene.get_node("BuildController").reset_layout()
	expect(scene.leaderboard_profile.pending == release_offer, "Reset layout cannot change a pending run")
	scene.free()
	await process_frame
	scene = game("dev")
	expect(scene.best_time == 0.0, "Development has a separate local best")
	finish(scene, 120.0)
	panel = scene.get_node("GameHUD").leaderboard
	expect(scene.best_time == 120.0 and scene.version_bests["0.2.0"] == 12.345, "Playtests do not change release bests")
	expect(scene.leaderboard_profile.pending.version == "dev" and scene.leaderboard_profile.pending.durationMs == 120000, "Dev records create their own publish offer")
	expect(panel.publish.visible and panel.prompt.text.contains("dev"), "Dev offers public publishing")
	panel.api_url = "https://example.convex.site"
	panel.username.text = "DevKeeper"
	panel._publish()
	expect(panel.sending.version == "dev", "Dev can send leaderboard requests")
	panel.request.cancel_request()
	panel._completed(HTTPRequest.RESULT_CANT_CONNECT, 0, [], PackedByteArray())
	expect(scene.leaderboard_profile.pending.version == "dev", "Failed dev publication remains retryable")
	expect(panel._scores_url().ends_with("?version=dev"), "Dev reads only its own scores")
	panel._scores_completed(HTTPRequest.RESULT_SUCCESS, 200, [], '[{"rank":1,"username":"DevKeeper","durationMs":120000}]'.to_utf8_buffer())
	expect(panel.scores_page.visible and panel.scores_rows.get_child(0).text == "#1  DevKeeper\n02:00.000", "Dev displays published rankings inside the game")
	expect(not panel.refresh_scores.disabled, "Dev rankings can be refreshed")
	scene.free()
	await process_frame
	scene = game("dev")
	expect(scene.best_time == 120.0 and scene.banked_energy == 107.0, "Dev record and progression survive reopening")
	expect(scene.leaderboard_profile.pending.version == "dev", "Dev publish offer survives reopening")
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
	scene.leaderboard_profile.pending = {"version": "0.3.0", "durationMs": 1000}
	scene.save_progress()
	scene.free()
	await process_frame
	scene = game("0.3.0")
	expect(scene.save_is_readable and scene.leaderboard_profile.pending.version == "0.3.0" and scene.leaderboard_profile.pending.durationMs == 1000 and scene.leaderboard_profile.pending.size() == 2, "Old pending offers remain publishable without invented run details")
	# Buy two turrets for 20 + 30 energy. Savings and later earnings must not
	# change the investment, and resetting the layout must preserve this record.
	scene.banked_energy = 1000.0
	var builder = scene.get_node("BuildController")
	builder.begin_placement()
	expect(builder.try_place(Vector2(80, 80)), "Buy the first paid turret")
	builder.begin_placement()
	expect(builder.try_place(Vector2(160, 80)), "Buy the second paid turret")
	scene.start_run()
	scene.lantern.elapsed = 10.0
	scene.lantern.energy = 60.0
	scene.lantern.take_damage(1000)
	expect(scene.leaderboard_profile.pending.energyInvested == 50.0 and scene.leaderboard_profile.pending.energyEarned == 60.0, "Death records 20 + 30 investment independently of savings and earnings")
	expect(not scene.leaderboard_profile.pending.has("totalEnergy"), "New offers no longer submit available energy")
	expect(scene.banked_energy == 1010.0, "Recording investment does not change the economy")
	scene.continue_to_preparation()
	builder.reset_layout()
	expect(scene.leaderboard_profile.pending.energyInvested == 50.0, "Refunding a defense preserves the previous run investment")
	scene.save_progress()
	scene.free()
	await process_frame
	scene = game("0.3.0")
	expect(scene.leaderboard_profile.pending.energyInvested == 50.0, "Run investment survives reopening with a different current layout")
	scene.start_run()
	scene.lantern.elapsed = 11.0
	scene.end_run(true)
	expect(scene.leaderboard_profile.pending.energyInvested == 0.0, "The next run uses the reset free defense budget")
	scene.continue_to_preparation()
	expect(scene.buy_upgrade("damage") and scene.buy_upgrade("damage") and scene.buy_upgrade("fire_rate") and scene.buy_upgrade("health"), "Purchase persistent upgrades for the next run")
	scene.start_run()
	scene.lantern.elapsed = 12.0
	scene.end_run(true)
	expect(scene.leaderboard_profile.pending.energyInvested == 270.0, "Investment includes damage 60 + 120, fire rate 50 and health 40 exactly once")
	expect(scene.leaderboard_profile.pending.turretLayout.upgrades == {"damage": 2, "fireRate": 1, "health": 1}, "Published configuration includes the actual upgrade levels")
	scene.continue_to_preparation()
	expect(scene.buy_upgrade("health"), "Purchase another upgrade after the recorded run")
	expect(scene.leaderboard_profile.pending.energyInvested == 270.0 and scene.leaderboard_profile.pending.turretLayout.upgrades.health == 1, "Later upgrades do not rewrite recorded investment or configuration")
	scene.free()
	DirAccess.remove_absolute(path)
	if failures == 0:
		print("PASS: version isolation, save migration, opt-in, identity, input focus, retries, stale response protection, paused End Run and reopening")
	quit(1 if failures else 0)
