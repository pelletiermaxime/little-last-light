extends SceneTree

class CountingTurret extends "res://turret.gd":
	var searches: int = 0
	func _find_nearest_enemy() -> Node2D:
		searches += 1
		return super._find_nearest_enemy()

var failures: int = 0
var body_redraws: int = 0
var health_redraws: int = 0
var turret_redraws: int = 0


func _initialize() -> void:
	call_deferred("check")


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func check() -> void:
	var scene = load("res://main.tscn").instantiate()
	var test_path := "/tmp/little-last-light-performance-%d.json" % OS.get_process_id()
	scene.save_path = test_path
	root.add_child(scene)
	scene.start_run()
	scene.set_process(false)
	scene.lantern.set_process(false)
	scene.lantern.set_physics_process(false)
	scene._set_turrets_active(false)
	var hud = scene.get_node("GameHUD")
	hud.set_process(false)
	scene.lantern.elapsed = 300.0
	scene._spawn_enemy()
	var enemy = get_nodes_in_group("enemies")[0]
	enemy.set_process(false)
	enemy.position = scene.lantern.position + Vector2(200, 0)
	enemy.body.draw.connect(func(): body_redraws += 1)
	enemy.draw.connect(func(): health_redraws += 1)
	await process_frame
	await process_frame
	body_redraws = 0
	health_redraws = 0
	for frame in range(12):
		enemy._process(1.0 / 144.0)
		await process_frame
	expect(body_redraws == 0 and health_redraws == 0, "Moving pursuers reuse cached body and health drawings")
	expect(is_equal_approx(enemy.body.rotation, enemy.heading.angle()), "Cached eyes still follow the heading")
	enemy.take_damage(1.0)
	await process_frame
	await process_frame
	expect(health_redraws == 1 and body_redraws == 0, "Damage redraws the upright health bar only")
	var turret := CountingTurret.new()
	turret.position = Vector2(-1000, -1000)
	scene.add_child(turret)
	turret.set_process(false)
	turret.draw.connect(func(): turret_redraws += 1)
	await process_frame
	await process_frame
	turret_redraws = 0
	for frame in range(144):
		turret._process(1.0 / 144.0)
		await process_frame
	expect(turret.searches <= 10, "Idle turret scans at most ten times per second at 144 FPS")
	expect(turret_redraws == 0, "Idle turret does not rebuild its range circle")
	# A target entering range is found at the next poll, within 0.1 seconds.
	turret.position = enemy.position
	var previous_health: float = enemy.health
	turret._process(0.1)
	expect(enemy.health == previous_health - turret.damage, "Newly reachable enemy is hit at the next poll")
	expect(turret.shot_time > 0.0, "Shot flash begins")
	await process_frame
	await process_frame
	expect(turret_redraws == 1, "Firing redraws the shot")
	turret._process(0.12)
	await process_frame
	await process_frame
	expect(turret.shot_time == 0.0 and turret_redraws == 2, "Expired shot is erased without ongoing redraws")
	expect(enemy.health == previous_health - turret.damage, "Shot interval is still respected")
	var stale_text: String = hud.health_text.text
	for hit in range(100):
		scene.lantern.take_damage(0.1)
	expect(is_equal_approx(scene.lantern.health, 90.0), "All crowd damage is applied immediately")
	expect(hud.health_text.text == stale_text, "Contact hits do not each rebuild the HUD")
	hud._process(0.1)
	expect(is_equal_approx(hud.health_bar.value, 90.0), "HUD samples accumulated damage at its normal cadence")
	scene.lantern.take_damage(1000.0)
	expect(scene.phase == scene.Phase.PREPARATION and not hud.health_bar.visible, "Death refreshes the HUD immediately")
	scene.free()
	DirAccess.remove_absolute(test_path)
	if failures == 0:
		print("PASS: cached swarm drawings, idle scan budget, targeting latency, shot expiry, batched HUD damage, immediate death")
	quit(0 if failures == 0 else 1)
