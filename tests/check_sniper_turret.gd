extends SceneTree

var failures := 0
var path := "/tmp/lll-sniper-test-%d.json" % OS.get_process_id()


func _initialize() -> void:
	root.get_node("DisplaySettings").settings_path = "/tmp/lll-sniper-test-display.cfg"
	call_deferred("check")


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func game() -> Node2D:
	ProjectSettings.set_setting("leaderboard/api_url", "")
	var scene = load("res://main.tscn").instantiate()
	scene.save_path = path
	root.add_child(scene)
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	return scene


func enemy_at(scene: Node2D, at: Vector2) -> Node2D:
	scene._spawn_enemy()
	var enemy: Node2D = get_nodes_in_group("enemies").back()
	enemy.position = at
	enemy.health = 100.0
	enemy.max_health = 100.0
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	return enemy


func check() -> void:
	var scene := game()
	var build = scene.get_node("BuildController")
	var ui = scene.get_node("PreparationUI")
	ui.open_view(ui.View.PLACEMENT)
	expect(build.sniper_button.visible and build.sniper_button.disabled, "Watchlight appears but requires funds")
	build.begin_placement("sniper")
	expect(not build.placing, "Insufficient funds cannot begin sniper placement")
	scene.banked_energy = 10000
	build._update_interface()
	var key := InputEventKey.new()
	key.physical_keycode = KEY_N
	key.pressed = true
	root.push_input(key)
	key.pressed = false
	root.push_input(key)
	expect(not build.placing, "N no longer buys a Watchlight")
	build.sniper_button.pressed.emit()
	expect(build.placing and build.placement_type == "sniper", "Watchlight button begins placement")
	expect(build.preview.attack_range == 360 and get_nodes_in_group("turrets").size() == 1, "Preview displays sniper range without joining combat")
	expect(not build.try_place(Vector2.ZERO) and scene.banked_energy == 10000, "Invalid placement never spends")
	expect(build.try_place(Vector2(350, 260)), "Watchlight can be placed")
	var sniper = get_nodes_in_group("turrets").back()
	expect(sniper.turret_type == "sniper" and sniper.purchase_cost == 120 and scene.banked_energy == 9880, "Sniper premium is paid and recorded")
	expect(build.turret_cost("sniper") == 145, "Sniper shares escalating layout prices")
	expect(sniper.damage == 3 and sniper.fire_interval == 4.5, "Base heavy damage and slow cadence")
	build.begin_move(sniper)
	expect(build.preview.turret_type == "sniper" and not sniper.visible, "Move preview preserves selected design")
	build.cancel_placement()
	expect(sniper.visible, "Cancel restores hidden turret")
	build.begin_move(sniper)
	expect(build.try_place(Vector2(350, 300)) and scene.banked_energy == 9880, "Moving remains free")
	scene.buy_upgrade("damage")
	scene.buy_upgrade("fire_rate")
	expect(sniper.damage == 7.5 and is_equal_approx(sniper.fire_interval, 3.6), "Shared upgrades preserve three-times damage and interval")
	ui.open_view(ui.View.PLACEMENT)
	expect(build.sniper_button in scene.get_node("Controls").menu_controls(), "Controller navigation includes Watchlight")
	build.sniper_button.grab_focus()
	var confirm := InputEventJoypadButton.new()
	confirm.button_index = JOY_BUTTON_A
	confirm.pressed = true
	root.push_input(confirm)
	confirm.pressed = false
	root.push_input(confirm)
	expect(build.placing and build.placement_type == "sniper", "Controller confirms Watchlight purchase")
	expect(build.preview.damage == 7.5, "New previews receive existing upgrades")
	build.cancel_placement()
	scene.save_progress()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	expect(data.turret_types == ["damage", "sniper"] and data.turret_costs == [0.0, 120.0], "Mixed layout persists sniper type and cost: %s / %s" % [data.turret_types, data.turret_costs])
	expect(scene._valid_run_layout(scene._run_turret_layout()), "Sniper layout is valid for pending records")
	scene.free()
	await process_frame
	scene = game()
	build = scene.get_node("BuildController")
	ui = scene.get_node("PreparationUI")
	sniper = get_nodes_in_group("turrets").back()
	expect(sniper.turret_type == "sniper" and sniper.position.is_equal_approx(Vector2(350, 300)) and sniper.purchase_cost == 120, "Reload restores type, position and paid price")
	expect(sniper.damage == 7.5 and is_equal_approx(sniper.fire_interval, 3.6), "Reload restores upgraded sniper stats")
	scene.damage_level = 0
	scene.fire_rate_level = 0
	scene.configure_turret(sniper)
	scene.start_run()
	scene.lantern.position = Vector2(900, 500)
	var near := enemy_at(scene, sniper.position + Vector2(70, 0))
	var far := enemy_at(scene, sniper.position + Vector2(0, -360))
	var outside := enemy_at(scene, sniper.position + Vector2(360.1, 0))
	sniper._process(0.0)
	expect(far.health == 97 and near.health == 100 and outside.health == 100, "Only furthest in-range enemy is hit; exact boundary included")
	expect(is_equal_approx(sniper.aim_angle, -PI / 2) and sniper.shot_endpoint == far.position, "Housing faces actual target at firing")
	sniper._process(4.4)
	expect(far.health == 97, "Long cooldown prevents early second shot")
	sniper._process(0.11)
	expect(far.health == 94, "Next shot occurs after full cadence")
	far.position = sniper.position + Vector2(20, 0)
	sniper.cooldown = 0
	sniper._process(0)
	expect(near.health == 97 and far.health == 94, "Each shot reacquires furthest instead of locking stale priority")
	var tie := enemy_at(scene, sniper.position + Vector2(-70, 0))
	expect(sniper._find_target() == near, "Equal distances retain stable tree order")
	near.health = 0
	expect(sniper._find_target() == tie, "Dead enemies cannot steal shots")
	tie.queue_free()
	expect(sniper._find_target() == far, "Queued deletion cannot steal shots")
	far.position = sniper.position + Vector2(0, 361)
	sniper.cooldown = 0
	sniper._process(0)
	expect(sniper.cooldown == sniper.IDLE_SEARCH_INTERVAL, "No target uses throttled idle search")
	far.position = sniper.position + Vector2(100, 0)
	scene.lantern.position = sniper.position + Vector2(110, 0)
	sniper.cooldown = 0
	sniper._process(0)
	expect(sniper.boosted and is_equal_approx(far.health, 89.5), "Lantern boundary boosts sniper damage by 50 percent")
	sniper._process(2.9)
	expect(is_equal_approx(far.health, 89.5), "Boosted shot respects its three-second interval")
	sniper._process(0.11)
	expect(is_equal_approx(far.health, 85.0), "Boost accelerates recharge without changing purchased stats")
	scene.damage_level = 5
	scene.fire_rate_level = 5
	scene.proximity_level = 5
	scene.configure_turret(sniper)
	expect(sniper.damage == 25.5 and sniper.fire_interval == 2.0, "Maximum upgrades retain sniper identity")
	sniper.cooldown = 0
	sniper._process(0)
	expect(far.health == 34.0, "Maximum proximity applies double damage")
	# A killed target is safely replaced on the next cycle.
	far.health = 1
	sniper.cooldown = 0
	sniper._process(0)
	expect(far.is_queued_for_deletion(), "Heavy shot can kill its target")
	sniper._process(1.1)
	expect(sniper.cooldown == sniper.IDLE_SEARCH_INTERVAL, "Killed targets do not leave a stale lock")
	# Real tree pause must freeze both the shared combat clock and shutters.
	scene.process_mode = Node.PROCESS_MODE_INHERIT
	scene.set_process(false)
	scene.lantern.set_process(false)
	scene.lantern.set_physics_process(false)
	sniper.cooldown = 1.0
	scene.get_node("PauseScreen").pause()
	await process_frame
	await process_frame
	expect(sniper.cooldown == 1.0, "Pause freezes sniper cooldown")
	scene.get_node("PauseScreen").resume()
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	scene.end_run(true)
	expect(sniper.cooldown == 0 and sniper.shot_time == 0 and not sniper.boosted, "End run clears animation and boost")
	expect(scene._valid_save(JSON.parse_string(FileAccess.get_file_as_string(path))), "Completed sniper run saves valid pending record metadata")
	scene.continue_to_preparation()
	var funds: float = scene.banked_energy
	build.begin_move(sniper)
	expect(build.sell_selected_turret() and scene.banked_energy == funds + 120, "Selling refunds original sniper price")
	expect(not build.sell_selected_turret(), "Cannot refund twice")
	build.begin_placement("sniper")
	expect(build.try_place(Vector2(350, 300)), "Can repurchase sniper")
	build.reset_layout()
	expect(get_nodes_in_group("turrets").size() == 1 and get_nodes_in_group("turrets")[0].turret_type == "damage", "Reset preserves free starter")
	scene.free()
	await process_frame
	DirAccess.remove_absolute(path)
	if failures == 0:
		print("PASS: Watchlight mouse/controller, placement, prices/refunds, saves/records, upgrades, furthest targeting, boundaries, ties/dead targets, aim, cadence, boosts, pause and reset")
	quit(1 if failures else 0)
