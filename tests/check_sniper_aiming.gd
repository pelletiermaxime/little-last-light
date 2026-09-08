extends SceneTree

class CountingSniper extends "res://turrets/sniper_turret.gd":
	var searches := 0
	func _furthest_enemy() -> Node2D:
		searches += 1
		return super._furthest_enemy()

var failures := 0
var scene: Node2D
var sniper: Node2D
var path := "/tmp/lll-sniper-aim-%d.json" % OS.get_process_id()


func _initialize() -> void:
	if "--capture-aiming" in OS.get_cmdline_user_args():
		root.get_node("GameAudio").muted = true
		root.get_node("DisplaySettings").settings_path = "/tmp/lll-sniper-aim-display.cfg"
	call_deferred("check")


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func enemy_at(offset: Vector2, health: float = 100.0) -> Node2D:
	scene.encounters._spawn_enemy()
	var enemy: Node2D = get_nodes_in_group("enemies").back()
	enemy.position = sniper.position + offset
	enemy.health = health
	enemy.max_health = health
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	return enemy


func check() -> void:
	ProjectSettings.set_setting("leaderboard/api_url", "")
	scene = load("res://main.tscn").instantiate()
	scene.save_path = path
	root.add_child(scene)
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	scene.start_run()
	scene.lantern.position = Vector2(900, 600)
	sniper = CountingSniper.new()
	scene.add_child(sniper)
	sniper.position = Vector2(350, 300)
	var doomed := enemy_at(Vector2(300, 0), 3)
	var next := enemy_at(Vector2(0, 200))
	sniper._process(0)
	expect(doomed.is_queued_for_deletion(), "First shot kills the furthest enemy")
	expect(sniper.aim_target == next and next.health == 100, "Next target is selected immediately after damage without an extra shot")
	expect(sniper.aim_angle == 0 and sniper.shot_endpoint == doomed.position, "Shot direction stays on the enemy actually hit")
	await capture("shot")
	sniper._process(0.06)
	expect(sniper.aim_angle == 0, "Housing stays aligned throughout the flash")
	sniper._process(0.10)
	expect(sniper.aim_angle > 0 and sniper.aim_angle < PI / 2, "Reload turn is gradual rather than snapping")
	await capture("turning")
	sniper._process(0.30)
	expect(is_equal_approx(sniper.aim_angle, PI / 2), "Housing reaches next target during reload")
	await capture("tracking")
	expect(is_equal_approx(sniper.cooldown, 4.04) and next.health == 100, "Aiming leaves cadence and damage unchanged")
	var incoming := enemy_at(Vector2(250, 0))
	sniper._process(0.1)
	expect(sniper.aim_target == incoming and sniper.aim_angle < PI / 2, "New furthest enemy redirects reload aim")
	incoming.health = 0
	sniper._process(0.1)
	expect(sniper.aim_target == next, "Dead target is replaced during reload")
	next.position = sniper.position + Vector2(0, 361)
	var held_angle: float = sniper.aim_angle
	sniper._process(0.1)
	expect(sniper.aim_target == null and sniper.aim_angle == held_angle, "Leaving range releases target and holds last direction")
	# Empty reload searches are bounded; the base ready-to-fire poll shares the timer.
	sniper.searches = 0
	for frame in range(144):
		sniper._process(1.0 / 144.0)
	expect(sniper.searches <= 10, "Reload scans at most ten times per second at 144 FPS")
	next.position = sniper.position + Vector2(0, 150)
	sniper._process(0.1)
	expect(sniper.aim_target == next, "Enemy entering range is acquired before reload completes")
	next.queue_free()
	sniper._process(0.1)
	expect(sniper.aim_target == null, "Queued target is released safely")
	var cached := enemy_at(Vector2(100, 0))
	sniper._process(0.1)
	expect(sniper.aim_target == cached, "Reload has a candidate")
	var last_moment := enemy_at(Vector2(-250, 0))
	sniper.cooldown = 0
	sniper._process(0)
	expect(last_moment.health == 97 and cached.health == 100, "Firing rechecks priority even before the next aim poll")
	expect(is_equal_approx(absf(sniper.aim_angle), PI), "Actual shot snaps to the freshly selected target")
	# Exercise pause with actual tree processing, not just direct calls.
	scene.process_mode = Node.PROCESS_MODE_INHERIT
	scene.set_process(false)
	scene.lantern.set_process(false)
	scene.lantern.set_physics_process(false)
	scene.get_node("PauseScreen").pause()
	var angle_before: float = sniper.aim_angle
	var searches_before: int = sniper.searches
	var cooldown_before: float = sniper.cooldown
	await process_frame
	await process_frame
	expect(sniper.aim_angle == angle_before and sniper.searches == searches_before and sniper.cooldown == cooldown_before, "Pause freezes turning, scanning and recharge")
	scene.get_node("PauseScreen").resume()
	scene.free()
	await process_frame
	DirAccess.remove_absolute(path)
	if failures == 0:
		print("PASS: immediate post-kill acquisition, flash alignment, smooth reload turn, moving/dead/out-of-range targets, bounded scanning, unchanged cadence, firing priority and pause")
	quit(1 if failures else 0)


func capture(state: String) -> void:
	if "--capture-aiming" not in OS.get_cmdline_user_args():
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/lll-sniper-aim-%s.png" % state)
