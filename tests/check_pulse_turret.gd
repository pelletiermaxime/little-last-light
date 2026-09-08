extends SceneTree

var failures := 0
var path := "/tmp/lll-pulse-%d.json" % OS.get_process_id()


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
	scene.get_node("GameHUD").leaderboard.api_url = ""
	return scene


func check() -> void:
	var scene := game()
	var build = scene.get_node("BuildController")
	var ui = scene.get_node("PreparationUI")
	ui.open_view(ui.View.PLACEMENT)
	expect(build.pulse_button.visible and build.pulse_button.disabled, "Pulse purchase is visible but requires funds")
	build.begin_placement("pulse")
	expect(not build.placing, "No funds cannot begin pulse purchase")
	scene.banked_energy = 1000.0
	build._update_interface()
	var key := InputEventKey.new()
	key.physical_keycode = KEY_V
	key.pressed = true
	root.push_input(key)
	key.pressed = false
	root.push_input(key)
	expect(not build.placing, "V no longer buys a slow turret")
	build.pulse_button.pressed.emit()
	expect(build.placing and build.placement_type == "pulse", "Slow turret button begins placement")
	build._process(0.01)
	expect(build.placement_hint.size.x > 150.0 and build.placement_hint.get_line_count() == 1, "Placement hint stays horizontal")
	build.cancel_placement()
	build.pulse_button.pressed.emit()
	expect(build.placing and build.preview.turret_type == "pulse" and build.preview.attack_range == 175.0, "Pulse button previews its actual type and range")
	expect(get_nodes_in_group("turrets").size() == 1, "Preview never enters turret group")
	expect(not build.try_place(Vector2.ZERO) and scene.banked_energy == 1000.0, "Invalid placement never spends")
	expect(build.try_place(Vector2(100, 100)), "Pulse can be placed")
	var pulse = get_nodes_in_group("turrets").back()
	expect(pulse.turret_type == "pulse" and pulse.purchase_cost == 60.0 and scene.banked_energy == 940.0, "Pulse uses the shared purchase price")
	expect(build.turret_cost() == 85.0 and build.turret_cost("pulse") == 85.0 and build.turret_cost("sniper") == 85.0, "All types share layout price escalation")
	build.begin_move(pulse)
	expect(build.preview.turret_type == "pulse" and not pulse.visible, "Moving retains pulse preview")
	build.cancel_placement()
	expect(pulse.visible and pulse.position == Vector2(100, 100), "Cancel restores pulse unchanged")
	build.begin_move(pulse)
	expect(build.try_place(Vector2(200, 100)) and scene.banked_energy == 940.0, "Moving a pulse is free")
	scene.buy_upgrade("damage")
	scene.buy_upgrade("fire_rate")
	expect(pulse.damage == 0.0 and pulse.fire_interval == 3.0, "Damage upgrades do not change support cadence or strength")
	scene.save_progress()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	expect(data.turret_types == ["damage", "pulse"] and data.turret_costs == [0.0, 60.0], "Save records mixed types and prices")
	for types in [["damage"], ["pulse", "damage"], ["damage", "unknown"]]:
		var bad := data.duplicate(true)
		bad.turret_types = types
		expect(not scene._valid_save(bad), "Invalid type metadata is rejected")
	scene.free()
	await process_frame
	scene = game()
	build = scene.get_node("BuildController")
	pulse = get_nodes_in_group("turrets").back()
	expect(pulse.turret_type == "pulse" and pulse.position.is_equal_approx(Vector2(200, 100)) and pulse.purchase_cost == 60.0, "Mixed layout reloads with exact price and location")
	scene.start_run()
	scene.lantern.position = Vector2(1000, 100)
	scene.encounters._spawn_enemy()
	var enemy = get_nodes_in_group("enemies")[0]
	enemy.position = Vector2(250, 100)
	enemy.heading = Vector2.RIGHT
	enemy.speed = 100.0
	pulse._process(0.01)
	expect(enemy.health == enemy.max_health and is_equal_approx(enemy.slow_factor, 0.55), "Pulse slows without damage")
	expect(pulse.shot_time > 0.0 and pulse.cooldown == 3.0, "Visible pulse starts full cooldown")
	enemy._process(0.5)
	expect(is_equal_approx(enemy.position.x, 277.5), "Pursuer moves at 55 percent speed")
	enemy.apply_slow(0.55, 1.5)
	enemy.apply_slow(0.55, 1.5)
	expect(is_equal_approx(enemy.slow_factor, 0.55) and enemy.slow_remaining == 1.5, "Overlaps refresh without stacking strength or duration")
	enemy._process(2.0)
	expect(is_equal_approx(enemy.position.x, 410.0) and enemy.slow_factor == 1.0 and enemy.modulate == Color.WHITE, "Expiry within a long frame restores full speed and tint")
	pulse._process(1.0)
	expect(enemy.slow_remaining == 0.0, "Pulse respects cooldown")
	pulse.cooldown = 0.0
	pulse._process(0.01)
	expect(pulse.cooldown <= 0.1 and enemy.slow_remaining == 0.0, "Out-of-range enemies are ignored and idle search is throttled")
	# Contact time remains real time, including a slow expiring during the frame.
	enemy.position = Vector2(200, 100)
	scene.lantern.position = Vector2(300, 100)
	scene.lantern.health = 100.0
	enemy.apply_slow(0.5, 1.0)
	enemy._process(2.0)
	expect(is_equal_approx(scene.lantern.health, 89.5), "Only 0.7 seconds of contact damage after slowed approach")
	scene.lantern.position = Vector2(1000, 100)
	scene.encounters._spawn_charger()
	var charger = get_nodes_in_group("chargers")[0]
	charger.position = Vector2(200, 100)
	charger.apply_slow(0.55, 1.5)
	charger._process(1.0)
	expect(is_equal_approx(charger.position.x, 233.0), "Charger approach is slowed")
	charger.state = charger.State.WARNING
	charger.state_remaining = 0.9
	charger.heading = Vector2.RIGHT
	charger.apply_slow(0.55, 1.5)
	charger._process(0.9)
	expect(charger.state == charger.State.CHARGING and is_equal_approx(charger.state_remaining, 0.7), "Warning duration is unchanged by slow")
	var before: float = charger.position.x
	charger._process(0.1)
	expect(is_equal_approx(charger.position.x - before, 38.0), "Committed charge retains its advertised speed")
	scene.encounters._spawn_boss()
	var boss = get_nodes_in_group("bosses")[0]
	boss.apply_slow(0.55, 1.5)
	expect(is_equal_approx(boss.slow_factor, 0.775), "Boss resists half the slowdown")
	boss._process(1.5)
	expect(boss.slow_remaining == 0.0 and boss.arrival_remaining == 1.5, "Slow expires normally during boss arrival")
	boss.arrival_remaining = 0.0
	boss.position = Vector2(100, 100)
	boss.heading = Vector2.RIGHT
	boss.apply_slow(0.55, 1.5)
	boss._process(1.0)
	expect(is_equal_approx(boss.position.x, 160.45), "Boss pursuit uses reduced susceptibility")
	# Let the actual scene tree, rather than direct calls, verify pause handling.
	scene.process_mode = Node.PROCESS_MODE_INHERIT
	scene.set_process(false)
	scene.lantern.set_process(false)
	enemy.apply_slow(0.55, 1.5)
	var remaining: float = enemy.slow_remaining
	var cooldown: float = pulse.cooldown
	paused = true
	await process_frame
	await process_frame
	expect(enemy.slow_remaining == remaining and pulse.cooldown == cooldown, "Scene pause freezes slow and pulse cooldown")
	paused = false
	scene.end_run(true)
	expect(pulse.shot_time == 0.0 and pulse.cooldown == 0.0, "Ending clears pulse animation and cooldown")
	scene.continue_to_preparation()
	scene.start_run()
	expect(get_nodes_in_group("enemies").is_empty(), "Fresh run has no stale slowed enemies")
	scene.end_run(true)
	scene.continue_to_preparation()
	var funds: float = scene.banked_energy
	build.begin_move(pulse)
	expect(build.sell_selected_turret() and scene.banked_energy == funds + 60.0, "Selling refunds original pulse price after reopening")
	expect(not build.sell_selected_turret(), "Pulse cannot be refunded twice")
	build.begin_placement("pulse")
	expect(build.try_place(Vector2(200, 100)), "Pulse can be repurchased")
	build.reset_layout()
	expect(get_nodes_in_group("turrets").size() == 1 and get_nodes_in_group("turrets")[0].turret_type == "damage", "Reset keeps free damage starter")
	scene.free()
	await process_frame
	# Pre-M14 metadata has no type field, even with recorded purchase costs.
	data.erase("turret_types")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	scene = game()
	for turret in get_nodes_in_group("turrets"):
		expect(turret.turret_type == "damage", "Legacy layouts default to damage turrets")
	scene.free()
	DirAccess.remove_absolute(path)
	if failures == 0:
		print("PASS: pulse purchase, preview, movement, pricing, upgrades, save migration, slow refresh/expiry/contact, charger timing, boss resistance, pause, restart and refunds")
	quit(1 if failures else 0)
