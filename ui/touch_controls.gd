extends Control

const STYLE = preload("res://ui/ui_style.gd")
const STICK_RADIUS := 58.0
const DEADZONE := 10.0

var enabled := false
var finger := -1
var origin := Vector2.ZERO
var offset := Vector2.ZERO
var action_fingers: Dictionary = {}
var brightness_button: Button
var pause_button: Button
var hint: Label
var main: Node2D


func _ready() -> void:
	main = get_parent().get_parent()
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	brightness_button = _button("Brightness", func(): main.lantern.set_brightness((main.lantern.brightness + 1) % 3))
	pause_button = _button("Pause", func(): main.get_node("PauseScreen").pause())
	hint = STYLE.label("Hold & slide to move", 14, Color("#ffdc9b"))
	add_child(hint)
	get_viewport().size_changed.connect(_layout)
	enabled = DisplayServer.is_touchscreen_available() or "--touch-controls" in OS.get_cmdline_user_args()
	if enabled:
		main.get_node("GameHUD").refresh.call_deferred()
	_layout()
	_process(0.0)


func _button(caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", STYLE.panel())
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(action)
	add_child(button)
	return button


func _layout() -> void:
	reset()
	if enabled:
		# Godot's desktop stretch baseline makes phone controls physically tiny.
		# Use CSS pixels on the web, including on high-DPI phone screens.
		var logical_size := get_window().size
		if OS.has_feature("web"):
			logical_size = Vector2i(int(JavaScriptBridge.eval("document.getElementById('canvas').clientWidth")), int(JavaScriptBridge.eval("document.getElementById('canvas').clientHeight")))
		if logical_size.x > 0 and logical_size.y > 0 and get_window().content_scale_size != logical_size:
			get_window().content_scale_size = logical_size
			if not main.is_node_ready():
				# Main places the free starting turret beside this initial position.
				main.get_node("Lantern")._center_in_viewport()
	var viewport_size := get_viewport_rect().size
	brightness_button.position = Vector2(viewport_size.x - 188, viewport_size.y - 100)
	brightness_button.size = Vector2(164, 76)
	pause_button.position = Vector2(viewport_size.x - 116, 20)
	pause_button.size = Vector2(92, 56)
	hint.position = Vector2(24, viewport_size.y - 44)
	hint.size = Vector2(220, 24)


func _active() -> bool:
	return main.phase == main.Phase.RUNNING and not get_tree().paused


func _process(_delta: float) -> void:
	var was_visible := visible
	visible = enabled and _active()
	if not visible:
		if was_visible or finger != -1 or not action_fingers.is_empty():
			reset()
	else:
		brightness_button.text = "Brightness\n" + main.lantern.BRIGHTNESS_NAMES[main.lantern.brightness]
		hint.visible = finger == -1


func reset() -> void:
	finger = -1
	offset = Vector2.ZERO
	action_fingers.clear()
	if is_instance_valid(main):
		main.get_node("Lantern").touch_direction = Vector2.ZERO
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		reset()
		if is_instance_valid(main) and enabled and _active():
			main.get_node("PauseScreen").pause()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not enabled:
		enabled = true
		_layout()
		main.get_node("GameHUD").refresh()
		_process(0.0)
	if not enabled or not _active():
		return
	# Combat owns real touch events. Do not let their synthesized mouse clicks
	# activate brightness twice or make a second finger steal the joystick.
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == finger:
		_move_stick(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		if event.index == finger and (not event.pressed or event.canceled):
			finger = -1
			offset = Vector2.ZERO
			main.lantern.touch_direction = Vector2.ZERO
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif action_fingers.has(event.index):
			var button: Button = action_fingers[event.index]
			if not event.pressed or event.canceled:
				action_fingers.erase(event.index)
				if not event.canceled and button.get_global_rect().has_point(event.position):
					button.pressed.emit()
			get_viewport().set_input_as_handled()
		elif event.pressed and not event.canceled:
			for button in [brightness_button, pause_button]:
				if button.get_global_rect().has_point(event.position):
					action_fingers[event.index] = button
					get_viewport().set_input_as_handled()
					return


func _unhandled_input(event: InputEvent) -> void:
	# Start only after GUI has had a chance to handle the touch.
	if not enabled or not _active() or finger != -1:
		return
	if event is InputEventScreenTouch and event.pressed and not event.canceled:
		var viewport_size := get_viewport_rect().size
		if event.position.x < viewport_size.x * 0.5 and event.position.y > 92:
			finger = event.index
			origin = event.position
			offset = Vector2.ZERO
			queue_redraw()
			get_viewport().set_input_as_handled()


func _move_stick(point: Vector2) -> void:
	offset = (point - origin).limit_length(STICK_RADIUS)
	var strength := clampf((offset.length() - DEADZONE) / (STICK_RADIUS - DEADZONE), 0.0, 1.0)
	main.lantern.touch_direction = offset.normalized() * strength
	queue_redraw()


func _draw() -> void:
	if finger == -1:
		return
	draw_circle(origin, STICK_RADIUS, Color(0.09, 0.14, 0.18, 0.5))
	draw_arc(origin, STICK_RADIUS, 0, TAU, 48, Color(1.0, 0.82, 0.5, 0.45), 2.0, true)
	draw_circle(origin + offset, 23, Color(1.0, 0.82, 0.5, 0.6))
