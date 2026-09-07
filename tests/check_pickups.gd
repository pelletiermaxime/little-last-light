extends SceneTree

var failures := 0
var path := "/tmp/lll-pickups-%d.json" % OS.get_process_id()

func _initialize() -> void:
	call_deferred("check")

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func check() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.save_path = path
	root.add_child(scene)
	scene.set_process(false)
	scene.lantern.set_process(false)
	scene.lantern.set_physics_process(false)
	var pickups = scene.pickups
	pickups.set_process(false)
	pickups.rng.seed = 1
	pickups._process(20.0)
	expect(not pickups.active, "No pickups during preparation")
	scene.start_run()
	scene._set_turrets_active(false)
	scene.lantern.elapsed = 11.9
	pickups._process(0.1)
	expect(not pickups.active, "Opening leaves twelve seconds to settle")
	scene.lantern.elapsed = 12.0
	pickups._process(0.1)
	expect(pickups.active and pickups.remaining == 18.0, "First marker gets its full lifetime")
	expect(pickups.pickup_position.distance_to(scene.lantern.position) >= 160.0, "Marker requires movement")
	expect(pickups.status.text.contains("Walk into"), "HUD explains collection")
	pickups.reset()
	for kind in [pickups.Kind.KINDLING, pickups.Kind.FLARE]:
		pickups._spawn()
		pickups.kind = kind
		pickups._refresh_status()
		expect(pickups.status.text.contains("Walk into"), "First offer of each type explains its effect")
		pickups._refresh_status()
		expect(pickups.status.visible, "Explanation stays visible on its first marker")
		pickups._spawn()
		pickups.kind = kind
		pickups._refresh_status()
		expect(not pickups.status.visible, "Repeated offers do not repeat the large explanation")
	for attempt in range(100):
		pickups._spawn()
		expect(pickups._spawn_rect().has_point(pickups.pickup_position), "Spawn remains inside safe arena")
		expect(pickups.pickup_position.distance_to(scene.lantern.position) >= 160.0, "Spawn avoids lantern")
	pickups.kind = pickups.Kind.KINDLING
	scene.lantern.position = pickups.pickup_position
	pickups._process(0.1)
	expect(not pickups.active and pickups.kindling_remaining == 8.0, "Walking into Kindling collects once")
	pickups._collect()
	scene.energy_level = 2
	scene.lantern.brightness = 2
	expect(is_equal_approx(scene.lantern.current_energy_rate(), 7.2), "Kindling combines with permanent gain and brightness")
	scene.lantern._process(10.0)
	expect(is_equal_approx(scene.lantern.energy, 64.8), "Expiry frame pays eight doubled and two ordinary seconds")
	expect(pickups.kindling_remaining == 0.0 and is_equal_approx(scene.lantern.current_energy_rate(), 3.6), "Income returns to normal")
	# Real enemies establish radius, damage amount and single application.
	var enemies: Array[Node2D] = []
	for distance in [0.0, 180.0, 181.0]:
		var enemy = scene.ENEMY_SCENE.instantiate()
		enemy.max_health = 10.0
		scene.add_child(enemy)
		enemy.position = scene.lantern.position + Vector2(distance, 0)
		enemy.set_process(false)
		enemies.append(enemy)
	pickups.active = true
	pickups.kind = pickups.Kind.FLARE
	pickups.remaining = 18.0
	pickups.pickup_position = scene.lantern.position
	pickups._process(0.1)
	pickups._collect()
	expect(enemies[0].health == 2 and enemies[1].health == 2 and enemies[2].health == 10, "Flare hits its larger radius once for eight, leaving outsiders intact")
	pickups._spawn()
	pickups.kindling_remaining = 8.0
	paused = true
	var snapshot: Array = [pickups.remaining, pickups.kindling_remaining, pickups.next_spawn]
	pickups.set_process(true)
	for frame in range(5):
		await process_frame
	expect(snapshot == [pickups.remaining, pickups.kindling_remaining, pickups.next_spawn], "Actual pause freezes marker and effect clocks")
	pickups.set_process(false)
	paused = false
	pickups.pickup_position = scene.lantern.position + Vector2(160, 0)
	pickups._process(18.0)
	expect(not pickups.active and pickups.notice == "Ember faded", "Ignored marker expires without collection")
	scene.lantern.elapsed = 180.0
	pickups.next_spawn = 179.0
	pickups._process(1.0)
	expect(not pickups.active, "No new markers after three minutes")
	pickups.active = true
	pickups.remaining = 10.0
	pickups.kindling_remaining = 8.0
	paused = true
	scene.end_run(true)
	expect(not paused and not pickups.active and pickups.kindling_remaining == 0 and pickups.burst_remaining == 0 and not pickups.status.visible, "Paused End Run clears all pickup state and visuals")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	expect(not saved.has("pickups") and not saved.has("kindling_remaining"), "Temporary effects stay out of saves")
	scene.continue_to_preparation()
	scene.start_run()
	expect(pickups.next_spawn == 12.0 and not pickups.active, "Restart resets cadence")
	expect(pickups.explained_kinds.is_empty(), "Restart enables first-offer explanations again")
	pickups.active = true
	pickups.kindling_remaining = 8.0
	scene.lantern.take_damage(1000)
	expect(not pickups.active and pickups.kindling_remaining == 0, "Death also clears effects")
	scene.free()
	DirAccess.remove_absolute(path)
	if failures == 0:
		print("PASS: pickup spawn bounds/cadence, collection, income expiry, explosion radius, pause, expiration, cutoff, end/death/restart and save isolation")
	quit(1 if failures else 0)
