extends Node2D

const TURRET_SCENE: PackedScene = preload("res://turrets/turret.tscn")
const BASE_TURRET_COST: float = 60.0
const EXTRA_TURRET_COST: float = 25.0
const PLACEMENT_MARGIN: float = 20.0
const TURRET_SPACING: float = 72.0

@onready var lantern: Node2D = get_parent().get_node("Lantern")
@onready var main: Node2D = get_parent()

var placing: bool = false
var preview: Node2D
var build_button: Button
var pulse_button: Button
var sniper_button: Button
var ember_button: Button
var placement_type: String = "damage"
var cancel_button: Button
var start_button: Button
var reset_button: Button
var quit_button: Button
var sell_button: Button
var damage_button: Button
var rate_button: Button
var health_button: Button
var selected_turret: Node2D
var placement_hint: Label
var controller_cursor: Vector2
var using_controller: bool = false
const CURSOR_SPEED: float = 360.0


func _ready() -> void:
	# Preparation uses an explicit phase; it does not pause the scene tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	preview = TURRET_SCENE.instantiate()
	preview.range_preview = true
	preview.process_mode = Node.PROCESS_MODE_DISABLED
	preview.remove_from_group("turrets")
	main.configure_turret(preview)
	add_child(preview)
	preview.hide()
	placement_hint = $PlacementUI/PlacementHint
	var preparation := main.get_node("PreparationUI")
	var actions := preparation.get_node("Card/Padding/Content/Actions")
	build_button = actions.get_node("BuildButton")
	pulse_button = actions.get_node("PulseButton")
	sniper_button = actions.get_node("SniperButton")
	cancel_button = actions.get_node("CancelButton")
	start_button = actions.get_node("StartButton")
	sell_button = actions.get_node("SellButton")
	reset_button = actions.get_node("ResetButton")
	damage_button = actions.get_node("DamageButton")
	rate_button = actions.get_node("RateButton")
	health_button = actions.get_node("HealthButton")
	quit_button = preparation.get_node("Card/Padding/Content/Footer/QuitButton")
	build_button.pressed.connect(begin_placement)
	pulse_button.pressed.connect(func(): begin_placement("pulse"))
	sniper_button.pressed.connect(func(): begin_placement("sniper"))
	ember_button = Button.new()
	ember_button.name = "EmberButton"
	actions.add_child(ember_button)
	actions.move_child(ember_button, sniper_button.get_index() + 1)
	ember_button.pressed.connect(begin_placement.bind("ember"))
	cancel_button.pressed.connect(cancel_placement)
	start_button.pressed.connect(main.start_run)
	sell_button.pressed.connect(sell_selected_turret)
	reset_button.pressed.connect(reset_layout)
	damage_button.pressed.connect(func(): main.buy_upgrade("damage"))
	rate_button.pressed.connect(func(): main.buy_upgrade("fire_rate"))
	health_button.pressed.connect(func(): main.buy_upgrade("health"))
	quit_button.pressed.connect(main.quit_game)
	cancel_button.hide()
	controller_cursor = main.get_arena_rect().get_center()
	_update_interface()


func _process(delta: float) -> void:
	if using_controller and main.phase == main.Phase.PREPARATION and _in_placement_mode():
		# D-pad navigates the toolbar; only the active pad's stick moves the cursor.
		var device: int = get_node("/root/ControllerIcons")._last_controller
		var direction := Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
		if direction.length() <= 0.3 or get_viewport().gui_get_focus_owner() != null:
			direction = Vector2.ZERO
		direction = direction.limit_length()
		var arena: Rect2 = main.get_arena_rect()
		controller_cursor = (controller_cursor + direction * CURSOR_SPEED * delta).clamp(arena.position, arena.end - Vector2.ONE)
	queue_redraw()
	_update_interface()
	if placing:
		preview.global_position = _cursor_position()
		var reason := placement_error(preview.global_position)
		var valid := reason.is_empty()
		preview.modulate = Color(0.6, 1.0, 0.7, 0.65) if valid else Color(1.0, 0.3, 0.3, 0.65)
		var confirm: String = main.get_node("Controls").hint("confirm_placement") if using_controller else "Click"
		if main.get_node("PreparationUI").using_touch():
			confirm = "Tap"
		placement_hint.text = ((confirm + " to move here · Free") if is_instance_valid(selected_turret) else (confirm + " to build · %d energy" % int(turret_cost(placement_type)))) if valid else reason
		placement_hint.modulate = Color("#a5edb7") if valid else Color("#ffb4a8")
		placement_hint.reset_size()
		var mouse := get_canvas_transform() * _cursor_position()
		var limit := (get_viewport_rect().size - placement_hint.size - Vector2(8, 8)).max(Vector2(8, 8))
		placement_hint.position = (mouse + Vector2(20, 24)).clamp(Vector2(8, 8), limit)


func turret_cost(_kind: String = "damage") -> float:
	var purchased := maxi(0, get_tree().get_nodes_in_group("turrets").size() - 1)
	return BASE_TURRET_COST + purchased * EXTRA_TURRET_COST


func layout_refund() -> float:
	var refund := 0.0
	for turret in get_tree().get_nodes_in_group("turrets"):
		refund += turret.purchase_cost
	return refund


func sell_selected_turret() -> bool:
	if main.phase != main.Phase.PREPARATION or not placing or not is_instance_valid(selected_turret):
		return false
	if not selected_turret.is_in_group("turrets") or selected_turret.purchase_cost <= 0.0:
		return false
	var sold := selected_turret
	var refund: float = sold.purchase_cost
	cancel_placement()
	# Saving and a second click must see the removal immediately.
	sold.remove_from_group("turrets")
	sold.queue_free()
	main.banked_energy += refund
	main.save_progress()
	_update_interface()
	lantern._update_status()
	return true


func reset_layout() -> bool:
	if main.phase != main.Phase.PREPARATION:
		return false
	var turrets := get_tree().get_nodes_in_group("turrets")
	if turrets.is_empty():
		return false
	var refund := layout_refund()
	# A preview is not a purchase. Restore any hidden moving turret first.
	cancel_placement()
	var starter := turrets[0] as Node2D
	for turret in turrets:
		if turret == starter:
			continue
		# Remove group membership now, so saving and a second click see one turret.
		turret.remove_from_group("turrets")
		turret.queue_free()
	var arena: Rect2 = main.get_arena_rect()
	starter.position = (arena.get_center() + Vector2(80, 0)).clamp(Vector2.ONE * PLACEMENT_MARGIN, arena.size - Vector2.ONE * PLACEMENT_MARGIN)
	starter.show()
	main.banked_energy += refund
	main.save_progress()
	_update_interface()
	lantern._update_status()
	return true


func _update_interface() -> void:
	# Parent _ready() has not run during this child's _ready(), so keep reads simple.
	var preparing: bool = main.phase == main.Phase.PREPARATION
	build_button.visible = preparing
	start_button.visible = preparing
	reset_button.visible = preparing
	# Browser players close their tab; SceneTree.quit cannot close it for them.
	quit_button.visible = preparing and not OS.has_feature("web")
	reset_button.text = "Reset layout · +%d (%s)" % [int(layout_refund()), "Confirm" if using_controller else "R"]
	sell_button.visible = preparing and is_instance_valid(selected_turret)
	if sell_button.visible:
		sell_button.disabled = selected_turret.purchase_cost <= 0.0
		sell_button.text = "Keep free starter turret" if sell_button.disabled else "Sell selected · +%d (%s)" % [int(selected_turret.purchase_cost), "R1 / RB" if using_controller else "X"]
	damage_button.text = "Damage %.1f to %.1f\n%d energy" % [main.turret_damage(), main.turret_damage() + 1.5, int(main.upgrade_cost("damage"))]
	rate_button.text = "Fire rate %.2f to %.2f/s\n%d energy" % [main.turret_shots_per_second(), main.turret_shots_per_second() + 0.25 / 1.5, int(main.upgrade_cost("fire_rate"))]
	damage_button.disabled = placing or main.banked_energy < main.upgrade_cost("damage") or main.damage_level >= main.MAX_UPGRADE_LEVEL
	rate_button.disabled = placing or main.banked_energy < main.upgrade_cost("fire_rate") or main.fire_rate_level >= main.MAX_UPGRADE_LEVEL
	if main.damage_level >= main.MAX_UPGRADE_LEVEL:
		damage_button.text = "Damage %.1f · MAX" % main.turret_damage()
	if main.fire_rate_level >= main.MAX_UPGRADE_LEVEL:
		rate_button.text = "Fire rate %.2f/s · MAX" % main.turret_shots_per_second()
	health_button.text = "Lantern HP %.0f to %.0f\n%d energy" % [main.lantern_max_health(), main.lantern_max_health() + 15, int(main.upgrade_cost("health"))]
	health_button.disabled = placing or main.banked_energy < main.upgrade_cost("health") or main.health_level >= main.MAX_UPGRADE_LEVEL
	if main.health_level >= main.MAX_UPGRADE_LEVEL:
		health_button.text = "Lantern HP %.0f · MAX" % main.lantern_max_health()
	start_button.disabled = placing
	build_button.text = "Build turret — %d energy" % int(turret_cost())
	cancel_button.text = "Cancel (%s)" % ("Back" if using_controller else "Esc")
	start_button.text = "Start run (%s)" % ("Menu" if using_controller else "Enter")
	build_button.disabled = placing or main.banked_energy < turret_cost()
	pulse_button.disabled = placing or main.banked_energy < turret_cost("pulse")
	sniper_button.disabled = placing or main.banked_energy < turret_cost("sniper")
	ember_button.disabled = placing or main.banked_energy < turret_cost("ember")
	var preparation := main.get_node_or_null("PreparationUI")
	if preparation != null and preparation.is_node_ready():
		preparation.refresh()


func _in_placement_mode() -> bool:
	var preparation := main.get_node_or_null("PreparationUI")
	return preparation != null and preparation.view == preparation.View.PLACEMENT


func _cursor_position() -> Vector2:
	return controller_cursor if using_controller else get_global_mouse_position()


func _draw() -> void:
	if not using_controller or main.phase != main.Phase.PREPARATION or not _in_placement_mode():
		return
	var point := to_local(controller_cursor)
	draw_arc(point, 10.0, 0.0, TAU, 32, Color.WHITE, 2.0)
	draw_line(point - Vector2(15, 0), point + Vector2(15, 0), Color.WHITE)
	draw_line(point - Vector2(0, 15), point + Vector2(0, 15), Color.WHITE)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	if main.phase != main.Phase.PREPARATION:
		return
	if event.is_action_pressed("build_turret"):
		begin_placement()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("build_pulse_turret"):
		begin_placement("pulse")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("build_sniper_turret"):
		begin_placement("sniper")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("reset_layout"):
		reset_layout()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("sell_turret"):
		sell_selected_turret()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cancel_placement"):
		if placing:
			cancel_placement()
		else:
			main.get_node("PreparationUI").go_back()
		get_viewport().set_input_as_handled()
	# Focused buttons confirm on release; do not start a run on their key press.
	elif event.is_action_pressed("start_run") and get_viewport().gui_get_focus_owner() == null:
		main.start_run()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("confirm_placement"):
		if _in_placement_mode():
			_select_or_place(controller_cursor)
		else:
			main.get_node("PreparationUI").open_view(1)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = get_canvas_transform().affine_inverse() * event.position
		_select_or_place(point)
		get_viewport().set_input_as_handled()


func _select_or_place(point: Vector2) -> void:
	if not _in_placement_mode():
		return
	var ui = main.get_node("PreparationUI")
	if ui.blocks_point(point):
		if using_controller:
			ui.activate_at(point)
		return
	if placing:
		try_place(point)
	else:
		var selection_radius := 32.0 if ui.using_touch() else 20.0
		for turret in get_tree().get_nodes_in_group("turrets"):
			if point.distance_to(turret.global_position) <= selection_radius:
				begin_move(turret)
				break


func begin_placement(kind: String = "damage") -> void:
	if kind not in ["damage", "pulse", "sniper", "ember"]:
		return
	if main.phase == main.Phase.PREPARATION:
		main.get_node("PreparationUI").open_view(1)
	if placing or main.phase != main.Phase.PREPARATION or main.banked_energy < turret_cost(kind):
		return
	selected_turret = null
	placement_type = kind
	_show_preview()


func begin_move(turret: Node2D) -> void:
	if placing or main.phase != main.Phase.PREPARATION or not is_instance_valid(turret) or not turret.is_in_group("turrets"):
		return
	main.get_node("PreparationUI").open_view(1)
	selected_turret = turret
	placement_type = turret.turret_type
	selected_turret.hide()
	_show_preview()


func _show_preview() -> void:
	preview.free()
	preview = main.turret_scene(placement_type).instantiate()
	preview.range_preview = true
	preview.process_mode = Node.PROCESS_MODE_DISABLED
	preview.remove_from_group("turrets")
	main.configure_turret(preview)
	add_child(preview)
	placing = true
	preview.global_position = _cursor_position()
	preview.show()
	placement_hint.show()
	cancel_button.show()
	_update_interface()


func can_place_at(point: Vector2) -> bool:
	return placement_error(point).is_empty()


func placement_error(point: Vector2) -> String:
	var arena: Rect2 = main.get_arena_rect()
	if not arena.has_point(point):
		return "Place inside the arena"
	if not arena.grow(-PLACEMENT_MARGIN).has_point(point):
		return "Too close to the arena edge"
	for turret in get_tree().get_nodes_in_group("turrets"):
		if turret == selected_turret:
			continue
		if point.distance_to(turret.global_position) < TURRET_SPACING:
			return "Too close to another turret"
	return ""


func try_place(point: Vector2) -> bool:
	# Validate everything before spending: invalid clicks never cost energy.
	if not placing or main.phase != main.Phase.PREPARATION or not can_place_at(point):
		return false
	if is_instance_valid(selected_turret):
		selected_turret.global_position = point
	else:
		var cost := turret_cost(placement_type)
		if main.banked_energy < cost:
			return false
		var turret := main.turret_scene(placement_type).instantiate() as Node2D
		turret.purchase_cost = cost
		main.configure_turret(turret)
		turret.process_mode = Node.PROCESS_MODE_DISABLED
		get_parent().add_child(turret)
		turret.global_position = point
		main.banked_energy -= cost
		main.achievements.unlock("first_tower")
	cancel_placement(false)
	main.save_progress()
	get_node("/root/GameAudio").play(&"place")
	return true


func cancel_placement(with_sound: bool = true) -> void:
	if not placing:
		return
	if with_sound:
		get_node("/root/GameAudio").play(&"back")
	placing = false
	if is_instance_valid(selected_turret):
		selected_turret.show()
	selected_turret = null
	preview.hide()
	placement_hint.hide()
	cancel_button.hide()
	_update_interface()
