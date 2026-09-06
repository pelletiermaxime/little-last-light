extends SceneTree

var failures := 0
var path := "/tmp/little-last-light-upgrades-%d.json" % OS.get_process_id()


func _initialize() -> void:
	call_deferred("check")


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func game() -> Node2D:
	var scene = load("res://main.tscn").instantiate()
	scene.save_path = path
	root.add_child(scene)
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	return scene


func buy(build: Node2D, point: Vector2) -> void:
	build.begin_placement()
	expect(build.try_place(point), "Purchase fixture uses the real placement flow")


func check() -> void:
	var scene := game()
	var build = scene.get_node("BuildController")
	expect(not scene.buy_upgrade("damage") and scene.damage_level == 0, "Insufficient funds cannot buy an upgrade")
	scene.banked_energy = 500.0
	var repeated := InputEventKey.new()
	repeated.physical_keycode = KEY_G
	repeated.pressed = true
	repeated.echo = true
	build._unhandled_input(repeated)
	expect(scene.damage_level == 0 and scene.banked_energy == 500.0, "Held upgrade shortcut cannot buy repeated levels")
	buy(build, Vector2(60, 80))
	buy(build, Vector2(140, 80))
	var turrets := get_nodes_in_group("turrets")
	expect(turrets[1].purchase_cost == 20.0 and turrets[2].purchase_cost == 30.0, "Every purchase records its actual cost")
	build.damage_button.pressed.emit()
	build.rate_button.pressed.emit()
	expect(scene.damage_level == 1 and scene.fire_rate_level == 1 and scene.banked_energy == 340.0, "Upgrade buttons charge displayed initial prices")
	expect(scene.upgrade_cost("damage") == 120.0 and scene.upgrade_cost("fire_rate") == 100.0, "Upgrade prices increase by level")
	for turret in turrets:
		expect(turret.damage == 2.0 and is_equal_approx(turret.fire_interval, 1.2), "Global upgrades affect every existing turret")
	build.begin_move(turrets[1])
	expect(not scene.buy_upgrade("damage"), "Finish a placement before upgrading")
	build.sell_button.pressed.emit()
	expect(scene.banked_energy == 360.0 and not build.placing, "Selling refunds original cost and clears preview")
	expect(not build.sell_selected_turret() and scene.banked_energy == 360.0, "Repeated sell cannot refund twice")
	buy(build, Vector2(60, 80))
	var replacement = get_nodes_in_group("turrets").back()
	expect(replacement.purchase_cost == 30.0 and replacement.damage == 2.0 and is_equal_approx(replacement.fire_interval, 1.2), "New turrets receive upgrades and their new purchase price")
	expect(build.layout_refund() == 60.0, "Layout refund sums actual investment after a sale and rebuy")
	build.begin_move(get_nodes_in_group("turrets")[0])
	expect(not build.sell_selected_turret() and build.sell_button.disabled, "Free starter remains available")
	build.cancel_placement()
	# Reopening preserves both global stats and the non-original price sequence.
	scene.free()
	await process_frame
	scene = game()
	build = scene.get_node("BuildController")
	expect(scene.damage_level == 1 and scene.fire_rate_level == 1 and scene.banked_energy == 330.0, "Upgrade purchase persists")
	expect(build.layout_refund() == 60.0, "Stored purchase prices survive reopening")
	for turret in get_nodes_in_group("turrets"):
		expect(turret.damage == 2.0 and is_equal_approx(turret.fire_interval, 1.2), "Loaded turrets receive global stats")
	build.reset_layout()
	expect(scene.banked_energy == 390.0 and scene.damage_level == 1 and scene.fire_rate_level == 1, "Reset refunds turrets but preserves purchased upgrades")
	expect(build.layout_refund() == 0.0, "Reset cannot refund upgrade spending as turrets")
	# Check real shooting: both hit strength and time to next shot changed.
	scene.continue_to_preparation()
	scene.start_run()
	var turret = get_nodes_in_group("turrets")[0]
	scene._spawn_enemy()
	var enemy = get_nodes_in_group("enemies")[0]
	enemy.position = turret.position + Vector2(40, 0)
	enemy.health = 9.0
	enemy.max_health = 9.0
	turret._process(0.01)
	expect(enemy.health == 7.0, "Upgraded turret deals two real damage")
	turret._process(0.8)
	expect(enemy.health == 7.0, "Turret still respects cooldown")
	turret._process(0.41)
	expect(enemy.health == 5.0, "Faster turret fires again before the base 1.5 seconds")
	expect(not scene.buy_upgrade("damage"), "Combat cannot buy upgrades")
	scene.get_node("PauseScreen").pause()
	expect(not scene.buy_upgrade("fire_rate") and not build.sell_selected_turret(), "Pause does not unlock upgrades or selling")
	scene.get_node("PauseScreen").end_run()
	scene.continue_to_preparation()
	# Upper bounds are enforced in code as well as the buttons.
	scene.banked_energy = 10000.0
	for kind in ["damage", "fire_rate"]:
		for level in range(3):
			expect(scene.buy_upgrade(kind), "Remaining upgrade levels can be purchased")
		var before: float = scene.banked_energy
		expect(not scene.buy_upgrade(kind) and scene.banked_energy == before, "Max level cannot spend again")
	expect(build.damage_button.disabled and build.rate_button.disabled, "Maxed upgrades show disabled buttons")
	scene.free()
	await process_frame
	# Pre-M9 saves have a known purchase order: infer costs once on load.
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string('{"version":1,"energy":42,"best_time":99,"turrets":[[0.5,0.5],[0.1,0.1],[0.2,0.1]]}')
	file.close()
	scene = game()
	build = scene.get_node("BuildController")
	expect(scene.damage_level == 0 and scene.fire_rate_level == 0 and scene.banked_energy == 42.0, "Legacy saves start with base upgrades and retain their balance")
	expect(build.layout_refund() == 50.0, "Legacy turrets migrate to original prices")
	scene.save_progress()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	expect(data.turret_costs == [0.0, 20.0, 30.0], "Migrated costs are saved explicitly")
	for invalid in [-1, 1.5, 9, "2"]:
		var bad := data.duplicate(true)
		bad.upgrades.damage = invalid
		expect(not scene._valid_save(bad), "Invalid upgrade levels are rejected")
	for invalid in [[0, 20], [0, -20, 30], [0, 20.5, 30], [20, 20, 30]]:
		var bad := data.duplicate(true)
		bad.turret_costs = invalid
		expect(not scene._valid_save(bad), "Invalid purchase metadata is rejected")
	scene.free()
	DirAccess.remove_absolute(path)
	if failures == 0:
		print("PASS: global stats, upgrade prices, sale/rebuy refunds, starter protection, reset, save migration, actual shots, phase guards, caps, validation")
	quit(1 if failures else 0)
