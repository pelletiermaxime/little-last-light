extends SceneTree

const BOSS = preload("res://prototype_boss.gd")

class Arena extends Node2D:
	var arena_size := Vector2(1152, 720)
	func get_arena_rect() -> Rect2:
		return Rect2(Vector2.ZERO, arena_size)

class Lantern extends Node2D:
	var running := true
	var brightness := 2
	var move_speed := 220.0
	var health := 1000.0
	func take_damage(amount: float) -> void:
		health -= amount
	func take_projectile_damage(amount: float) -> void:
		take_damage(amount)


func _initialize() -> void:
	call_deferred("check")


func check_tide(size: Vector2, corner: Vector2, vertical: bool, fps: int, dodge: bool) -> void:
	var arena := Arena.new()
	arena.arena_size = size
	root.add_child(arena)
	var lantern := Lantern.new()
	lantern.position = Vector2(16, 16) + (size - Vector2(32, 32)) * corner
	arena.add_child(lantern)
	var boss = BOSS.new()
	boss.kind = BOSS.Kind.TIDEKEEPER
	boss.target = lantern
	boss.position = size * 0.5
	boss.vertical_front = not vertical
	arena.add_child(boss)
	boss.set_process(false)
	boss._process(3.0)
	var elapsed := 0.0
	var step := 1.0 / fps
	while boss.attack != BOSS.Attack.RECOVERY:
		# React after 300 ms and move only along the front toward its fixed opening.
		if dodge and elapsed >= 0.3:
			var axis := 0 if vertical else 1
			lantern.position[axis] = move_toward(lantern.position[axis], boss.front_gap, lantern.move_speed * step)
		boss._process(step)
		for droplet in boss.projectiles:
			if is_instance_valid(droplet) and not droplet.is_queued_for_deletion():
				droplet.set_process(false)
				droplet._process(step)
		elapsed += step
		assert(elapsed < 30.0, "Front eventually ends")
	if dodge:
		assert(lantern.health == 1000.0, "Gap route must be reachable from every corner after reaction time")
	else:
		assert(lantern.health < 1000.0, "Standing outside the opening must be hit")
	assert(boss.position.distance_to(size * 0.5) > 100.0, "Tidekeeper advances during the front instead of idling at its spawn")
	arena.free()


func rush_result(step: float, at_edge: bool) -> Dictionary:
	var arena := Arena.new()
	root.add_child(arena)
	var lantern := Lantern.new()
	lantern.position = Vector2(600, 400)
	arena.add_child(lantern)
	var boss = BOSS.new()
	boss.kind = BOSS.Kind.WICKWATCHER
	boss.target = lantern
	boss.position = Vector2(500, 400)
	arena.add_child(boss)
	boss.set_process(false)
	boss.attack = BOSS.Attack.ACTIVE
	boss.remaining = BOSS.RUSH_DURATION
	boss.heading = Vector2.RIGHT
	if at_edge:
		boss.position = Vector2(1100, 200)
		boss.heading = Vector2(1, 1).normalized()
		var start: Vector2 = boss.position
		var warning_end: Vector2 = boss._rush_endpoint(BOSS.RUSH_SPEED * BOSS.RUSH_DURATION)
		boss._rush(BOSS.RUSH_DURATION)
		assert(boss.position.is_equal_approx(warning_end), "Rush ends precisely at the warned boundary")
		assert(absf((boss.position - start).cross(boss.heading)) < 0.001, "Diagonal wall contact cannot bend the rush")
		assert(boss.attack == BOSS.Attack.RECOVERY)
	else:
		var elapsed := 0.0
		while elapsed < 1.0 - 0.000001:
			boss._process(minf(step, 1.0 - elapsed))
			elapsed += step
		assert(lantern.health == 988.0, "Swept rush hits exactly once")
	var result := {"remaining": boss.remaining, "position": boss.position}
	arena.free()
	return result


func check() -> void:
	for size in [Vector2(640, 480), Vector2(1152, 720), Vector2(1920, 1080)]:
		for corner in [Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN, Vector2.ONE]:
			for vertical in [true, false]:
				for fps in [30, 120]:
					check_tide(size, corner, vertical, fps, true)
					check_tide(size, corner, vertical, fps, false)
	var coarse := rush_result(1.0, false)
	var fine := rush_result(1.0 / 120.0, false)
	assert(is_equal_approx(coarse.remaining, fine.remaining), "Recovery uses actual contact time even on a long frame")
	assert(coarse.position.is_equal_approx(fine.position))
	rush_result(1.0, true)
	print("PASS: 96 tide routes across three arena sizes, all corners, both axes, 30/120 FPS; rushed contact timing and straight wall endpoint")
	quit()
