extends SceneTree

var failures: int = 0

func _initialize() -> void:
	call_deferred("check")

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func check() -> void:
	var scene = load("res://main.tscn").instantiate()
	var path := "/tmp/little-last-light-difficulty-%d.json" % OS.get_process_id()
	scene.save_path = path
	root.add_child(scene)
	scene.set_process(false)
	scene.lantern.set_process(false)
	var build = scene.get_node("BuildController")
	await process_frame
	expect(build.turret_cost() == 60.0, "First extra turret costs 60")
	var another = load("res://turrets/turret.tscn").instantiate()
	scene.add_child(another)
	another.position = Vector2(scene.get_arena_rect().size.x * 0.85, 250)
	expect(build.turret_cost() == 85.0, "Second extra turret costs 85")
	expect(build.placement_error(Vector2(3, 300)) == "Too close to the arena edge", "Edge rejection explained")
	expect(build.placement_error(another.position) == "Too close to another turret", "Spacing rejection explained")
	expect(scene.get_arena_rect().size == scene.get_viewport_rect().size, "Arena fills the whole viewport")
	expect(build.can_place_at(Vector2(30, 30)), "Former top-left HUD location is buildable")
	var arena: Rect2 = scene.get_arena_rect()
	var empty_bottom := Vector2(arena.size.x * 0.5, arena.size.y - 36)
	expect(build.can_place_at(empty_bottom), "Empty bottom area is no longer blocked by the container")
	build.begin_move(another)
	expect(build.turret_cost() == 85.0, "Preview and moving a turret do not change price")
	expect(build.try_place(empty_bottom), "Free relocation can use empty bottom area")
	expect(scene.banked_energy == 0.0, "Relocation still free")
	scene.continue_to_preparation()
	scene.start_run()
	expect(scene.get_arena_rect() == arena, "Arena dimensions do not change on Start")
	expect(scene.lantern.position == arena.get_center(), "Lantern starts at arena center")
	scene.lantern.position = Vector2(10000, 10000)
	scene.lantern._keep_inside_viewport()
	expect(arena.has_point(scene.lantern.position), "Lantern cannot enter sidebar")
	scene.lantern._center_in_viewport()
	for index in range(100):
		expect(arena.has_point(scene.encounters._random_edge_position()), "Spawns stay inside arena")
	scene._set_turrets_active(false)
	expect(scene.encounters.current_enemy_health() == 1.0, "Initial enemies take one hit")
	expect(scene.encounters.current_enemy_speed() == 85.0, "Basic enemies use a fixed pursuit speed")
	scene.lantern.elapsed = 29.9
	expect(scene.encounters.current_enemy_health() == 1.0, "No toughness increase before threshold")
	scene.lantern.elapsed = 30.0
	expect(scene.encounters.current_enemy_health() == 2.0, "New enemies take two hits at 30 seconds")
	scene.encounters._spawn_enemy()
	var enemy = get_nodes_in_group("enemies")[0]
	expect(enemy.speed == 85.0, "Later spawns retain the basic pursuit speed")
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	expect(enemy.health == 2.0 and enemy.max_health == 2.0, "Spawn applies toughness before ready")
	scene.lantern.health = 100.0
	enemy.speed = scene.encounters.current_enemy_speed()
	enemy.heading = Vector2.LEFT
	enemy.global_position = scene.lantern.global_position + Vector2(20.0, 0)
	for frame in range(60):
		scene.lantern.position.x -= scene.lantern.move_speed / 60.0
		enemy._process(1.0 / 60.0)
	expect(scene.lantern.health == 100.0, "Running away from a slower pursuer avoids contact")
	scene.lantern._center_in_viewport()
	scene.lantern.health = 100.0
	enemy.speed = 100.0
	enemy.heading = Vector2.LEFT
	enemy.global_position = scene.lantern.global_position + Vector2(30.0, 0)
	enemy._process(0.2)
	expect(is_equal_approx(scene.lantern.health, 98.5), "Only the remaining 0.1 seconds after arrival causes damage")
	enemy.take_damage(1.0)
	expect(enemy.health == 1.0 and not enemy.is_queued_for_deletion(), "Tough enemy survives first hit")
	enemy.take_damage(1.0)
	expect(enemy.is_queued_for_deletion(), "Tough enemy dies on second hit")
	scene.lantern.elapsed = 1000.0
	expect(scene.encounters.current_enemy_speed() < scene.lantern.move_speed * 0.5 and scene.encounters.current_enemy_speed() == 85.0, "Player stays over twice as fast, even beyond 15 minutes")
	var previous: float = scene.encounters.current_enemy_health()
	scene.lantern.elapsed += 30.0
	expect(scene.encounters.current_enemy_health() > previous, "Toughness continues after spawn interval reaches its floor")
	scene.lantern.take_damage(1000)
	scene.continue_to_preparation()
	scene.start_run()
	expect(scene.encounters.current_enemy_health() == 1.0, "Next run resets toughness")
	expect(scene.encounters.current_enemy_speed() == 85.0, "Next run resets enemy speed")
	# A fresh high-brightness run funds choices without immediately buying a swarm.
	scene.lantern.brightness = 2
	scene.lantern._process(180.0)
	expect(is_equal_approx(scene.lantern.energy, 432.0), "Three minutes at high brightness earns 432 energy")
	for time in [120.0, 300.0, 600.0, 900.0]:
		scene.lantern.elapsed = time + 25.0
		var last_interval := INF
		for brightness in range(3):
			scene.lantern.brightness = brightness
			var interval: float = scene.encounters.current_spawn_interval()
			expect(interval < last_interval and interval >= 0.1, "Every brightness retains distinct pressure within the spawn cap")
			last_interval = interval
	scene.lantern.brightness = 0
	scene.lantern.elapsed = 145.0
	var early_interval: float = scene.encounters.current_spawn_interval()
	scene.lantern.elapsed = 325.0
	expect(scene.encounters.current_spawn_interval() < early_interval, "Spawn pressure still grows beyond two minutes")
	scene.lantern.elapsed = 640.0
	expect(scene.encounters.ENCOUNTER_SCHEDULE.chargers_enabled(640.0) and scene.encounters.current_charger_interval() == 12.0, "Late recovery admits occasional chargers")
	expect(scene.encounters.ENCOUNTER_SCHEDULE.pursuer_rate_multiplier(640.0) == 0.5, "Late recovery retains half-pressure breathing room")
	scene.free()
	DirAccess.remove_absolute(path)
	if failures == 0:
		print("PASS: prices, full-window arena, buildable former HUD areas, consistent phases, spawn/movement bounds, multi-hit enemies, continuing pressure")
	quit(0 if failures == 0 else 1)
