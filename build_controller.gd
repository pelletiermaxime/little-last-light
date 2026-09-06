extends Node2D

const TURRET_SCENE: PackedScene = preload("res://turret.tscn")
const BASE_TURRET_COST: float = 20.0
const EXTRA_TURRET_COST: float = 10.0
const PLACEMENT_MARGIN: float = 20.0
const TURRET_SPACING: float = 36.0

@onready var lantern: Node2D = get_parent().get_node("Lantern")
@onready var main: Node2D = get_parent()

var placing: bool = false
var preview: Node2D
var build_button: Button
var cancel_button: Button
var start_button: Button
var reset_button: Button
var quit_button: Button
var sell_button: Button
var damage_button: Button
var rate_button: Button
var health_button: Button
var bar: VBoxContainer
var selected_turret: Node2D
var placement_hint: Label
var controller_cursor: Vector2
var using_controller: bool = false
const CURSOR_SPEED: float = 360.0


func _ready() -> void:
	# Preparation uses an explicit phase; it does not pause the scene tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	preview = TURRET_SCENE.instantiate()
	preview.process_mode = Node.PROCESS_MODE_DISABLED
	preview.remove_from_group("turrets")
	add_child(preview)
	preview.hide()
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	placement_hint = Label.new()
	var tooltip_style := StyleBoxFlat.new()
	tooltip_style.bg_color = Color(0.025, 0.035, 0.05, 0.97)
	tooltip_style.content_margin_left = 8
	tooltip_style.content_margin_right = 8
	tooltip_style.content_margin_top = 5
	tooltip_style.content_margin_bottom = 5
	placement_hint.add_theme_stylebox_override("normal", tooltip_style)
	placement_hint.add_theme_font_size_override("font_size", 17)
	placement_hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	placement_hint.add_theme_constant_override("shadow_offset_x", 2)
	placement_hint.add_theme_constant_override("shadow_offset_y", 2)
	placement_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(placement_hint)
	placement_hint.hide()
	bar = VBoxContainer.new()
	layer.add_child(bar)
	bar.add_theme_constant_override("separation", 14)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(buttons)
	build_button = Button.new()
	build_button.text = "Build turret (B)"
	build_button.custom_minimum_size = Vector2(280, 44)
	build_button.focus_mode = Control.FOCUS_NONE
	build_button.pressed.connect(begin_placement)
	buttons.add_child(build_button)
	cancel_button = Button.new()
	cancel_button.text = "Cancel (Esc)"
	cancel_button.custom_minimum_size = Vector2(150, 44)
	cancel_button.focus_mode = Control.FOCUS_NONE
	cancel_button.pressed.connect(cancel_placement)
	buttons.add_child(cancel_button)
	start_button = Button.new()
	start_button.text = "Start run (Enter)"
	start_button.custom_minimum_size = Vector2(210, 44)
	start_button.focus_mode = Control.FOCUS_NONE
	start_button.pressed.connect(main.start_run)
	buttons.add_child(start_button)
	sell_button = Button.new()
	sell_button.custom_minimum_size.y = 44
	sell_button.focus_mode = Control.FOCUS_NONE
	sell_button.pressed.connect(sell_selected_turret)
	buttons.add_child(sell_button)
	damage_button = Button.new()
	damage_button.custom_minimum_size.y = 60
	damage_button.focus_mode = Control.FOCUS_NONE
	damage_button.pressed.connect(func(): main.buy_upgrade("damage"))
	buttons.add_child(damage_button)
	rate_button = Button.new()
	rate_button.custom_minimum_size.y = 60
	rate_button.focus_mode = Control.FOCUS_NONE
	rate_button.pressed.connect(func(): main.buy_upgrade("fire_rate"))
	buttons.add_child(rate_button)
	health_button = Button.new()
	health_button.custom_minimum_size.y = 60
	health_button.focus_mode = Control.FOCUS_NONE
	health_button.pressed.connect(func(): main.buy_upgrade("health"))
	buttons.add_child(health_button)
	reset_button = Button.new()
	reset_button.custom_minimum_size.y = 44
	reset_button.focus_mode = Control.FOCUS_NONE
	reset_button.tooltip_text = "Refund purchased turrets and restore the free starter. Global upgrades stay unlocked."
	reset_button.pressed.connect(reset_layout)
	buttons.add_child(reset_button)
	quit_button = Button.new()
	quit_button.text = "Quit Game"
	quit_button.custom_minimum_size.y = 44
	quit_button.focus_mode = Control.FOCUS_NONE
	quit_button.tooltip_text = "Save your progress and close the game."
	quit_button.pressed.connect(main.quit_game)
	buttons.add_child(quit_button)
	# The filled gold action makes the next run the clearest way forward.
	var primary := StyleBoxFlat.new()
	primary.bg_color = Color("#ffcf7a")
	primary.set_corner_radius_all(5)
	start_button.add_theme_stylebox_override("normal", primary)
	start_button.add_theme_color_override("font_color", Color("#17212b"))
	cancel_button.hide()
	controller_cursor = main.get_arena_rect().get_center()
	_update_interface()


func _process(delta: float) -> void:
	if using_controller and main.phase == main.Phase.PREPARATION and _in_placement_mode():
		# D-pad navigates the toolbar; only the active pad's stick moves the cursor.
		var device: int = main.get_node("Controls").active_device
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
		placement_hint.text = ((confirm + " to move here · Free") if is_instance_valid(selected_turret) else (confirm + " to build · %d energy" % int(turret_cost()))) if valid else reason
		placement_hint.modulate = Color("#a5edb7") if valid else Color("#ffb4a8")
		placement_hint.reset_size()
		var mouse := get_canvas_transform() * _cursor_position()
		var limit := (get_viewport_rect().size - placement_hint.size - Vector2(8, 8)).max(Vector2(8, 8))
		placement_hint.position = (mouse + Vector2(20, 24)).clamp(Vector2(8, 8), limit)


func turret_cost() -> float:
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
	bar.hide()
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
	damage_button.text = "Damage %.0f to %.0f (%s)\n%d energy" % [main.turret_damage(), main.turret_damage() + 1, "Confirm" if using_controller else "G", int(main.upgrade_cost("damage"))]
	rate_button.text = "Fire rate %.2f to %.2f/s (%s)\n%d energy" % [main.turret_shots_per_second(), main.turret_shots_per_second() + 0.25 / 1.5, "Confirm" if using_controller else "F", int(main.upgrade_cost("fire_rate"))]
	damage_button.disabled = placing or main.banked_energy < main.upgrade_cost("damage") or main.damage_level >= main.MAX_UPGRADE_LEVEL
	rate_button.disabled = placing or main.banked_energy < main.upgrade_cost("fire_rate") or main.fire_rate_level >= main.MAX_UPGRADE_LEVEL
	if main.damage_level >= main.MAX_UPGRADE_LEVEL:
		damage_button.text = "Damage %.0f · MAX" % main.turret_damage()
	if main.fire_rate_level >= main.MAX_UPGRADE_LEVEL:
		rate_button.text = "Fire rate %.2f/s · MAX" % main.turret_shots_per_second()
	health_button.text = "Lantern HP %.0f to %.0f (%s)\n%d energy" % [main.lantern_max_health(), main.lantern_max_health() + 15, "Confirm" if using_controller else "H", int(main.upgrade_cost("health"))]
	health_button.disabled = placing or main.banked_energy < main.upgrade_cost("health") or main.health_level >= main.MAX_UPGRADE_LEVEL
	if main.health_level >= main.MAX_UPGRADE_LEVEL:
		health_button.text = "Lantern HP %.0f · MAX" % main.lantern_max_health()
	start_button.disabled = placing
	build_button.text = "Build turret — %d energy (%s)" % [int(turret_cost()), "Confirm" if using_controller else "B"]
	cancel_button.text = "Cancel (%s)" % ("Back" if using_controller else "Esc")
	start_button.text = "Start run (%s)" % ("Menu" if using_controller else "Enter")
	build_button.disabled = placing or main.banked_energy < turret_cost()
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
	elif event.is_action_pressed("reset_layout"):
		reset_layout()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("sell_turret"):
		sell_selected_turret()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("upgrade_damage"):
		if not placing:
			main.get_node("PreparationUI").open_view(2)
		main.buy_upgrade("damage")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("upgrade_health"):
		if not placing:
			main.get_node("PreparationUI").open_view(2)
		main.buy_upgrade("health")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("upgrade_fire_rate"):
		if not placing:
			main.get_node("PreparationUI").open_view(2)
		main.buy_upgrade("fire_rate")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cancel_placement"):
		if placing:
			cancel_placement()
		else:
			main.get_node("PreparationUI").open_view(0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("start_run"):
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
		for turret in get_tree().get_nodes_in_group("turrets"):
			if point.distance_to(turret.global_position) <= 20.0:
				begin_move(turret)
				break


func begin_placement() -> void:
	if main.phase == main.Phase.PREPARATION:
		main.get_node("PreparationUI").open_view(1)
	if placing or main.phase != main.Phase.PREPARATION or main.banked_energy < turret_cost():
		return
	selected_turret = null
	_show_preview()


func begin_move(turret: Node2D) -> void:
	if placing or main.phase != main.Phase.PREPARATION or not is_instance_valid(turret) or not turret.is_in_group("turrets"):
		return
	main.get_node("PreparationUI").open_view(1)
	selected_turret = turret
	selected_turret.hide()
	_show_preview()


func _show_preview() -> void:
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
		var cost := turret_cost()
		if main.banked_energy < cost:
			return false
		var turret := TURRET_SCENE.instantiate() as Node2D
		turret.purchase_cost = cost
		main.configure_turret(turret)
		turret.process_mode = Node.PROCESS_MODE_DISABLED
		get_parent().add_child(turret)
		turret.global_position = point
		main.banked_energy -= cost
	cancel_placement()
	main.save_progress()
	return true


func cancel_placement() -> void:
	if not placing:
		return
	placing = false
	if is_instance_valid(selected_turret):
		selected_turret.show()
	selected_turret = null
	preview.hide()
	placement_hint.hide()
	cancel_button.hide()
	_update_interface()
