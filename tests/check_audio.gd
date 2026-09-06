extends SceneTree

var failures := 0
var heard: Array[StringName] = []

func _initialize() -> void:
	call_deferred("check")

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func check() -> void:
	var audio = root.get_node("GameAudio")
	audio.settings_path = "/tmp/lll-audio-%d.cfg" % OS.get_process_id()
	audio.set_muted(false)
	audio.set_volume(0.5)
	audio.cue_played.connect(func(cue): heard.append(cue))
	expect(audio.players.size() == 8, "Only the eight selected sounds are loaded")
	expect(audio.play(&"shot"), "First shot plays")
	for index in range(100):
		expect(not audio.play(&"shot"), "Simultaneous turret shots are throttled")
	expect(audio.players[&"shot"].max_polyphony == 2, "Turret voices are capped at two")
	audio._process(0.12)
	expect(audio.play(&"shot"), "Shot becomes available after shared cooldown")
	paused = true
	audio.stop_combat()
	audio._process(1.0)
	expect(not audio.play(&"shot") and audio.play(&"back"), "Pause silences combat but allows menu audio")
	paused = false
	audio.set_muted(true)
	expect(not audio.play(&"confirm"), "Mute suppresses sounds")
	audio.set_volume(0.75)
	audio.muted = false
	audio.volume = 0.1
	audio.load_settings()
	expect(audio.muted and audio.volume == 0.75, "Volume and mute persist separately from progress")
	audio.set_muted(false)
	audio.set_volume(0.0)
	expect(not audio.play(&"confirm"), "Zero volume is silent")
	audio.set_volume(0.5)
	var scene = load("res://main.tscn").instantiate()
	scene.save_path = "/tmp/lll-audio-%d.json" % OS.get_process_id()
	root.add_child(scene)
	await process_frame
	heard.clear()
	scene.banked_energy = 0
	expect(not scene.buy_upgrade("damage") and not heard.has(&"upgrade"), "Failed upgrade is silent")
	scene.banked_energy = 1000
	expect(scene.buy_upgrade("damage") and heard.count(&"upgrade") == 1, "Successful upgrade plays once")
	var build = scene.get_node("BuildController")
	build.begin_placement()
	heard.clear()
	expect(not build.try_place(Vector2(-100, -100)) and heard.is_empty(), "Invalid placement is silent")
	expect(build.try_place(Vector2(100, 100)), "Valid placement succeeds")
	expect(heard.count(&"place") == 1 and not heard.has(&"back"), "Successful placement does not play cancel")
	scene.start_run()
	heard.clear()
	scene.lantern.set_brightness(0)
	scene.lantern.take_damage(0)
	expect(heard.is_empty(), "Unchanged brightness and zero damage are silent")
	scene.lantern.set_brightness(1)
	scene.lantern.take_damage(1)
	expect(heard.count(&"brightness") == 1 and heard.count(&"damage") == 1, "Brightness and damage play on actual changes")
	var path: String = scene.save_path
	scene.free()
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(audio.settings_path)
	if failures == 0:
		print("PASS: selected clips, shot limits, pause, mute, persisted volume, successful action cues")
	quit(1 if failures else 0)
