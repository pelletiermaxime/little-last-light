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
var hint: Label
var overview: Label
var start_button: Button
var bar: VBoxContainer
var selected_turret: Node2D
var placement_hint: Label
var sidebar: ColorRect


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
	# Background sits below the lantern HUD; controls stay above it.
	var background_layer := CanvasLayer.new()
	background_layer.layer = 2
	add_child(background_layer)
	sidebar = ColorRect.new()
	sidebar.color = Color("#1b2533")
	background_layer.add_child(sidebar)
	sidebar.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	overview = Label.new()
	overview.add_theme_font_size_override("font_size", 18)
	overview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bar.add_child(overview)
	hint = Label.new()
	hint.add_theme_font_size_override("font_size", 18)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bar.add_child(hint)
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
	cancel_button.hide()
	_layout_sidebar()
	get_viewport().size_changed.connect(_layout_sidebar)
	_update_interface()


func _layout_sidebar() -> void:
	var arena: Rect2 = main.get_arena_rect()
	sidebar.position = Vector2(arena.end.x, 0)
	sidebar.size = Vector2(main.SIDEBAR_WIDTH, arena.size.y)
	bar.position = Vector2(arena.end.x + 20, 260)
	bar.size = Vector2(280, 0)


func _process(_delta: float) -> void:
	_update_interface()
	if placing:
		preview.global_position = get_global_mouse_position()
		var reason := placement_error(preview.global_position)
		var valid := reason.is_empty()
		preview.modulate = Color(0.6, 1.0, 0.7, 0.65) if valid else Color(1.0, 0.3, 0.3, 0.65)
		placement_hint.text = ("Click to move here · Free" if is_instance_valid(selected_turret) else "Click to build · %d energy" % int(turret_cost())) if valid else reason
		placement_hint.modulate = Color("#a5edb7") if valid else Color("#ffb4a8")
		placement_hint.reset_size()
		var mouse := get_viewport().get_mouse_position()
		var limit := (get_viewport_rect().size - placement_hint.size - Vector2(8, 8)).max(Vector2(8, 8))
		placement_hint.position = (mouse + Vector2(20, 24)).clamp(Vector2(8, 8), limit)


func turret_cost() -> float:
	var purchased := maxi(0, get_tree().get_nodes_in_group("turrets").size() - 1)
	return BASE_TURRET_COST + purchased * EXTRA_TURRET_COST


func _update_interface() -> void:
	# Parent _ready() has not run during this child's _ready(), so keep reads simple.
	var preparing: bool = main.phase == main.Phase.PREPARATION
	build_button.visible = preparing
	start_button.visible = preparing
	start_button.disabled = placing
	build_button.text = "Build turret — %d energy (B)" % int(turret_cost())
	build_button.disabled = placing or main.banked_energy < turret_cost()
	overview.text = ("Energy available: %d\n%s" % [int(main.banked_energy), main.summary]) if preparing else ("Saved energy: %d · Building unlocks after this run" % int(main.banked_energy))
	if not main.save_message.is_empty():
		overview.text += "\n" + main.save_message
	if placing:
		hint.text = "Move turret for free · Click to confirm · Esc to cancel" if is_instance_valid(selected_turret) else "Place new turret · Click to buy · Esc to cancel"
	elif not preparing:
		hint.text = "New enemies: %d hits · Tougher every 30s · Brightness attracts more" % int(main.current_enemy_health())
	elif main.banked_energy < turret_cost():
		hint.text = "Click a turret to move it · Need %d more energy to buy" % int(ceil(turret_cost() - main.banked_energy))
	else:
		hint.text = "Click a turret to move it, or buy another with B"


func _unhandled_input(event: InputEvent) -> void:
	if main.phase != main.Phase.PREPARATION:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_B:
			begin_placement()
			get_viewport().set_input_as_handled()
		elif placing and event.keycode == KEY_ESCAPE:
			cancel_placement()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ENTER:
			main.start_run()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = get_canvas_transform().affine_inverse() * event.position
		if placing:
			try_place(point)
		else:
			for turret in get_tree().get_nodes_in_group("turrets"):
				if point.distance_to(turret.global_position) <= 20.0:
					begin_move(turret)
					break
		get_viewport().set_input_as_handled()


func begin_placement() -> void:
	if placing or main.phase != main.Phase.PREPARATION or main.banked_energy < turret_cost():
		return
	selected_turret = null
	_show_preview()


func begin_move(turret: Node2D) -> void:
	if placing or main.phase != main.Phase.PREPARATION or not is_instance_valid(turret) or not turret.is_in_group("turrets"):
		return
	selected_turret = turret
	selected_turret.hide()
	_show_preview()


func _show_preview() -> void:
	placing = true
	preview.global_position = get_global_mouse_position()
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
