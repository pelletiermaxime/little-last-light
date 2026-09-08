extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("check")

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func check() -> void:
	var path := "/tmp/lll-spacing-%d.json" % OS.get_process_id()
	var scene = load("res://main.tscn").instantiate()
	scene.save_path = path
	root.add_child(scene)
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	var starter = scene.get_node("Turret")
	starter.position = Vector2(300, 300)
	var tower = scene.TURRET_SCENE.instantiate()
	tower.purchase_cost = 20.0
	scene.add_child(tower)
	tower.position = Vector2(340, 300)
	scene.save_progress()
	scene.free()
	await process_frame
	scene = load("res://main.tscn").instantiate()
	scene.save_path = path
	root.add_child(scene)
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	var build = scene.get_node("BuildController")
	var prep = scene.get_node("PreparationUI")
	expect(scene.save_is_readable and scene.proximity_level == 0, "Same-version profile reloads")
	starter = get_nodes_in_group("turrets")[0]
	tower = get_nodes_in_group("turrets")[1]
	build.begin_move(tower)
	expect(not build.try_place(starter.position + Vector2(71, 0)), "Placement rejects less than 72 pixels")
	expect(build.try_place(starter.position + Vector2(72, 0)), "Exactly 72 pixels is allowed")
	expect(build.layout_refund() == 20.0 and scene.banked_energy == 0.0, "Relocation preserves historical costs and spends nothing")
	prep.open_view(prep.View.UPGRADES)
	scene.banked_energy = 10000.0
	build._update_interface()
	expect(prep.proximity_button.visible and not prep.proximity_button.disabled, "New upgrade is available in the Lantern group")
	for level in range(5):
		expect(scene.upgrade_cost("proximity") == 150.0 * pow(2.0, level), "Proximity price doubles each level")
		prep.proximity_button.pressed.emit()
		expect(scene.proximity_level == level + 1, "Button buys exactly one proximity level")
	expect(scene.proximity_multiplier() == 2.0 and not scene.buy_upgrade("proximity"), "Five levels cap both multipliers at two")
	expect(prep.proximity_button.disabled and prep.proximity_button.text.contains("MAX"), "Capped upgrade is labeled and disabled")
	scene.start_run()
	expect(scene.phase == scene.Phase.RUNNING, "Repaired layout starts normally")
	scene.lantern.position = tower.position
	scene.encounters._spawn_enemy()
	var enemy = get_nodes_in_group("enemies")[0]
	enemy.health = 100.0
	enemy.max_health = 100.0
	enemy.position = tower.position + Vector2(40, 0)
	tower.cooldown = 0.0
	tower._process(0.0)
	expect(enemy.health == 98.0, "Maximum proximity doubles actual shot damage")
	tower._process(0.75)
	expect(enemy.health == 96.0, "Maximum proximity doubles actual firing rate")
	scene.end_run(true)
	scene.free()
	await process_frame
	scene = load("res://main.tscn").instantiate()
	scene.save_path = path
	root.add_child(scene)
	expect(scene.proximity_level == 5 and scene.proximity_multiplier() == 2.0, "Proximity level survives saving and reopening")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for kind in scene.upgrade_levels():
		var valid := data.duplicate(true)
		valid.upgrades[kind] = 5
		expect(scene._valid_save(valid), "Every upgrade accepts level five")
		valid.upgrades[kind] = 6
		expect(not scene._valid_save(valid), "Every upgrade rejects level six")
	scene.free()
	DirAccess.remove_absolute(path)
	if failures == 0:
		print("PASS: spacing boundary, refunds, proximity purchase/cap, real shots and five-level persistence")
	quit(1 if failures else 0)
