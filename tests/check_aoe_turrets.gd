extends SceneTree

class Target extends Node2D:
	var health := 10.0
	func take_damage(amount: float) -> void:
		health -= amount

var failures := 0
var save_path := "/tmp/lll-aoe-%d.json" % OS.get_process_id()


func _initialize() -> void:
	call_deferred("check")


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func game() -> Node2D:
	var scene = load("res://main.tscn").instantiate()
	scene.save_path = save_path
	root.add_child(scene)
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	return scene


func target(scene: Node2D, point: Vector2) -> Target:
	var enemy := Target.new()
	scene.add_child(enemy)
	enemy.position = point
	enemy.add_to_group("enemies")
	return enemy


func check() -> void:
	ProjectSettings.set_setting("leaderboard/api_url", "")
	var scene := game()
	var build = scene.get_node("BuildController")
	var prep = scene.get_node("PreparationUI")
	prep.open_view(prep.View.PLACEMENT)
	press_ember()
	expect(not build.placing, "Ember shortcut respects insufficient funds")
	scene.banked_energy = 2000.0
	build._update_interface()
	build.sniper_button.grab_focus()
	press_ember()
	expect(build.placing and build.placement_type == "ember", "L3 selects Ember even with another toolbar button focused")
	expect(root.gui_get_focus_owner() == null, "Shortcut releases toolbar focus for placement")
	expect(build.ember_button.icon != null, "Ember displays its dedicated controller icon")
	build.cancel_placement()
	prep.open_view(prep.View.HOME)
	press_ember()
	expect(not build.placing, "Ember shortcut is limited to Place turrets")
	prep.open_view(prep.View.PLACEMENT)
	var kinds := ["ember"]
	for index in range(kinds.size()):
		var kind: String = kinds[index]
		build.ember_button.pressed.emit()
		expect(build.placing and build.preview.turret_type == kind, "Button previews " + kind)
		expect(build.preview.damage == 1.0, "Preview uses prototype stats")
		expect(build.try_place(Vector2(100 + index * 180, 100)), "Purchase " + kind)
		var turret = get_nodes_in_group("turrets").back()
		expect(turret.turret_type == kind and turret.purchase_cost == 60 + index * 25, "Type and paid cost " + kind)
		build.begin_move(turret)
		expect(build.preview.turret_type == kind, "Move preview retains shape")
		build.cancel_placement()
		scene.damage_level = 5
		scene.fire_rate_level = 5
		scene.configure_turret(turret)
		expect(turret.damage == scene.turret_damage() and is_equal_approx(turret.fire_interval, 2.0 / scene.turret_shots_per_second()), "Shared upgrades retain Ember's slower cadence")
		scene.damage_level = 0
		scene.fire_rate_level = 0
		scene.configure_turret(turret)
		var origin: Vector2 = turret.position
		var first := target(scene, origin + Vector2(70, 0))
		var second := target(scene, origin + Vector2(90, 10))
		var outside := target(scene, origin + Vector2(-150, 0))
		turret._process(0.01)
		expect(first.health == 10 and second.health == 10 and turret.pending_time > 0, "Wind-up never damages early")
		# A departing/deleted target must not drag the projectile or cancel its splash.
		first.free()
		first = target(scene, origin + Vector2(200, 0))
		turret._process(turret.FLIGHT_TIME + 0.001)
		expect(second.health == 9 and outside.health == 10, "Area damages included enemy once and excludes outside")
		expect(first.health == 10.0, "Impact uses current position with fixed landing point")
		turret._process(0.1)
		expect(second.health == 9, "Flash does not repeat damage")
		first.free()
		second.free()
		outside.free()
		turret.cooldown = 0.0
		turret._process(0.01)
		expect(turret.pending_time == 0.0 and turret.cooldown <= 0.1, "No targets means no attack")
		first = target(scene, origin + Vector2(50, 0))
		turret._process(0.11)
		expect(turret.pending_time > 0, "Next attack can start")
		turret.process_mode = Node.PROCESS_MODE_PAUSABLE
		var pending: float = turret.pending_time
		var cooldown: float = turret.cooldown
		paused = true
		await process_frame
		await process_frame
		expect(turret.pending_time == pending and turret.cooldown == cooldown, "Pause freezes charge and cooldown")
		paused = false
		scene._set_turrets_active(false)
		expect(turret.pending_time == 0 and turret.shot_time == 0, "Run reset cancels pending attacks and effects")
		first.free()
	# Watchlight must coexist with Ember in previews, saves and upgraded stats.
	build.sniper_button.pressed.emit()
	expect(build.preview.turret_type == "sniper", "Watchlight preview survives integration")
	expect(build.try_place(Vector2(460, 100)), "Watchlight can be purchased alongside Ember")
	var sniper = get_nodes_in_group("turrets").back()
	expect(sniper.damage == scene.turret_damage() * 3.0, "Watchlight retains upgrade multiplier")
	var ui = scene.get_node("PreparationUI")
	expect(ui.placement_stats.ember.text.contains("1 dmg") and ui.placement_stats.ember.text.contains("65 splash"), "Ember stats use the new placement details")
	expect(ui.placement_stats.sniper.text.contains("Furthest target"), "Watchlight placement details remain intact")
	scene.save_progress()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	expect(data.turret_types == ["damage", "ember", "sniper"] and scene._valid_save(data), "Mixed Ember and Watchlight save is valid")
	var layout: Dictionary = scene._run_turret_layout()
	expect(scene.PROGRESS_STORE.valid_run_layout(layout), "Record layout preserves new types")
	var panel = scene.get_node("GameHUD").leaderboard
	expect(panel._has_prototype_layout({"turretLayout": layout}), "Prototype records remain local")
	scene.free()
	await process_frame
	scene = game()
	expect(get_nodes_in_group("turrets").size() == 3, "All types reload")
	for index in range(1, 2):
		var turret = get_nodes_in_group("turrets")[index]
		expect(turret.turret_type == kinds[index - 1] and turret.damage == 1.0, "Reload retains type and base stats")
	build = scene.get_node("BuildController")
	var funds: float = scene.banked_energy
	expect(get_nodes_in_group("turrets").back().turret_type == "sniper", "Watchlight type reloads")
	var last = get_nodes_in_group("turrets")[1]
	var paid: float = last.purchase_cost
	build.begin_move(last)
	expect(build.sell_selected_turret() and scene.banked_energy == funds + paid, "Sale refunds saved purchase price")
	build.reset_layout()
	expect(get_nodes_in_group("turrets").size() == 1, "Layout refund removes prototypes")
	scene.free()
	await process_frame
	DirAccess.remove_absolute(save_path)
	if failures == 0:
		print("PASS: Ember controller/placement, timing, locked aim, area exclusions, single hits, upgrades, reset, save/reload, records and refunds")
	quit(1 if failures else 0)


func press_ember() -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_LEFT_STICK
	event.pressed = true
	root.push_input(event)
	event.pressed = false
	root.push_input(event)
