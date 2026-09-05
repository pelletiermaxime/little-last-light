extends Node2D

const TURRET_SCENE: PackedScene = preload("res://turret.tscn")
const TURRET_COST: float = 20.0
const PLACEMENT_MARGIN: float = 20.0
const TURRET_SPACING: float = 36.0

@onready var lantern: Node2D = get_parent().get_node("Lantern")

var placing: bool = false
var preview: Node2D
var build_button: Button
var cancel_button: Button
var hint: Label


func _ready() -> void:
	# Placement UI and preview work while the rest of the run is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	preview = TURRET_SCENE.instantiate()
	preview.process_mode = Node.PROCESS_MODE_DISABLED
	preview.remove_from_group("turrets")
	add_child(preview)
	preview.hide()
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var bar := VBoxContainer.new()
	layer.add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	bar.offset_left = 24
	bar.offset_top = -120
	bar.offset_right = 540
	bar.offset_bottom = -20
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint = Label.new()
	hint.add_theme_font_size_override("font_size", 18)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(hint)
	var buttons := HBoxContainer.new()
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(buttons)
	build_button = Button.new()
	build_button.text = "Build turret — %d energy (B)" % int(TURRET_COST)
	build_button.custom_minimum_size = Vector2(300, 44)
	build_button.focus_mode = Control.FOCUS_NONE
	build_button.pressed.connect(begin_placement)
	buttons.add_child(build_button)
	cancel_button = Button.new()
	cancel_button.text = "Cancel (Esc)"
	cancel_button.custom_minimum_size = Vector2(150, 44)
	cancel_button.focus_mode = Control.FOCUS_NONE
	cancel_button.pressed.connect(cancel_placement)
	buttons.add_child(cancel_button)
	cancel_button.hide()
	_update_interface()


func _process(_delta: float) -> void:
	_update_interface()
	if placing:
		preview.global_position = get_global_mouse_position()
		var valid := can_place_at(preview.global_position)
		preview.modulate = Color(0.6, 1.0, 0.7, 0.65) if valid else Color(1.0, 0.3, 0.3, 0.65)


func _update_interface() -> void:
	build_button.disabled = placing or lantern.health <= 0.0 or lantern.energy < TURRET_COST
	if placing:
		hint.text = "Paused · Left-click to place · Esc to cancel"
	elif lantern.health <= 0.0:
		hint.text = ""
	elif lantern.energy < TURRET_COST:
		hint.text = "Need %d more energy to build" % int(ceil(TURRET_COST - lantern.energy))
	else:
		hint.text = "Ready to expand your defense"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_B:
			begin_placement()
			get_viewport().set_input_as_handled()
		elif placing and event.keycode == KEY_ESCAPE:
			cancel_placement()
			get_viewport().set_input_as_handled()
	elif placing and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		try_place(get_canvas_transform().affine_inverse() * event.position)
		get_viewport().set_input_as_handled()


func begin_placement() -> void:
	if placing or get_tree().paused or lantern.health <= 0.0 or lantern.energy < TURRET_COST:
		return
	placing = true
	get_tree().paused = true
	preview.global_position = get_global_mouse_position()
	preview.show()
	cancel_button.show()
	_update_interface()


func can_place_at(point: Vector2) -> bool:
	var screen_size := get_viewport_rect().size
	if not Rect2(Vector2.ONE * PLACEMENT_MARGIN, screen_size - Vector2.ONE * PLACEMENT_MARGIN * 2.0).has_point(point):
		return false
	# Keep the HUD and purchase controls clear.
	if Rect2(0, 0, 460, 210).has_point(point) or Rect2(0, screen_size.y - 140, 560, 140).has_point(point):
		return false
	for turret in get_tree().get_nodes_in_group("turrets"):
		if point.distance_to(turret.global_position) < TURRET_SPACING:
			return false
	return true


func try_place(point: Vector2) -> bool:
	# Validate everything before spending: invalid clicks never cost energy.
	if not placing or lantern.health <= 0.0 or lantern.energy < TURRET_COST or not can_place_at(point):
		return false
	var turret := TURRET_SCENE.instantiate() as Node2D
	get_parent().add_child(turret)
	turret.global_position = point
	lantern.energy -= TURRET_COST
	lantern._update_status()
	cancel_placement()
	return true


func cancel_placement() -> void:
	if not placing:
		return
	placing = false
	preview.hide()
	cancel_button.hide()
	get_tree().paused = false
	_update_interface()
