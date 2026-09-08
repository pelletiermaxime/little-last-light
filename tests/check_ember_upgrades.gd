extends SceneTree

class Target extends Node2D:
	var health := 100.0
	func take_damage(amount: float) -> void:
		health -= amount

var failures := 0
var path := "/tmp/lll-ember-upgrades-%d.json" % OS.get_process_id()

func _initialize() -> void:
	call_deferred("check")

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func check() -> void:
	ProjectSettings.set_setting("leaderboard/api_url", "")
	var scene = load("res://main.tscn").instantiate()
	scene.save_path = path
	root.add_child(scene)
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	scene.banked_energy = 10000.0
	var build = scene.get_node("BuildController")
	build.begin_placement("ember")
	expect(build.try_place(Vector2(200, 200)), "Ember purchase")
	var ember = get_nodes_in_group("turrets").back()
	expect(scene.buy_upgrade("damage") and scene.buy_upgrade("fire_rate"), "Purchase shared upgrades")
	expect(ember.damage == 2.5 and is_equal_approx(ember.fire_interval, 2.4), "Existing Ember receives damage/rate upgrades")
	build.begin_placement("ember")
	expect(build.preview.damage == 2.5 and is_equal_approx(build.preview.fire_interval, 2.4), "New preview receives upgrades")
	build.cancel_placement()
	scene.save_progress()
	scene.free()
	await process_frame
	scene = load("res://main.tscn").instantiate()
	scene.save_path = path
	root.add_child(scene)
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	ember = get_nodes_in_group("turrets").back()
	expect(ember.damage == 2.5 and is_equal_approx(ember.fire_interval, 2.4), "Upgraded Ember reloads")
	scene.lantern.running = true
	scene.lantern.position = ember.position + Vector2(110, 0)
	var enemy := Target.new()
	scene.add_child(enemy)
	enemy.position = ember.position + Vector2(50, 0)
	enemy.add_to_group("enemies")
	ember._process(0.01)
	expect(ember.boosted and is_equal_approx(ember.launched_damage, 3.75), "Proximity boundary boosts launched damage")
	scene.lantern.position += Vector2(1, 0)
	ember._process(0.45)
	expect(not ember.boosted and is_equal_approx(enemy.health, 96.25), "Leaving range retains the launched coal's damage")
	var remaining: float = ember.cooldown
	scene.lantern.position = ember.position
	ember._process(0.2)
	expect(is_equal_approx(ember.cooldown, remaining - 0.3), "Entering range immediately accelerates remaining recharge")
	scene.proximity_level = 5
	ember.reset_attack()
	ember._process(0.01)
	expect(is_equal_approx(ember.launched_damage, 5.0), "Proximity upgrade increases Ember bonus")
	var flight: float = ember.pending_time
	ember._process(0.2)
	expect(is_equal_approx(ember.pending_time, flight - 0.2), "Proximity does not accelerate coal flight")
	ember.reset_attack()
	scene.lantern.position += Vector2(111, 0)
	ember._process(0.01)
	scene.lantern.position = ember.position
	ember._process(0.45)
	expect(is_equal_approx(enemy.health, 93.75), "Entering range does not retroactively boost an airborne coal")
	expect(scene.get_node("PreparationUI").upgrade_summaries["Damage turrets"].text.contains("Ember Pot"), "Upgrade page includes Ember stats")
	scene.free()
	await process_frame
	DirAccess.remove_absolute(path)
	if failures == 0:
		print("PASS: Ember purchased upgrades, preview/reload, proximity boundary, recharge transitions, launch damage and fixed flight")
	quit(1 if failures else 0)
