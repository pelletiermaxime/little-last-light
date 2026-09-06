extends Node

# Last child of Main: receives input before menus or gameplay can consume it.
# Prompts and controller routing share the same InputMap actions.
enum Family { KEYBOARD, PLAYSTATION, XBOX, GENERIC }
var family: Family = Family.KEYBOARD
var active_device: int = -1
var main: Node2D
var repeat_direction := 0
var repeat_left := 0.0
var menu_stick := Vector2.ZERO
var menu_axis := -1
var icons: Dictionary = {}
var last_focus_id := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	main = get_parent()
	Input.joy_connection_changed.connect(_connection_changed)
	# LinkButton defaults to accessibility-only focus in this Godot version.
	for button in main.get_node("GameHUD").leaderboard.find_children("*", "BaseButton", true, false):
		button.focus_mode = Control.FOCUS_ALL


static func detect_family(controller_name: String) -> Family:
	var name_lower := controller_name.to_lower()
	for fragment in ["playstation", "dualsense", "dualshock", "ps3", "ps4", "ps5", "sony"]:
		if name_lower.contains(fragment):
			return Family.PLAYSTATION
	if name_lower.contains("xbox") or name_lower.contains("xinput"):
		return Family.XBOX
	return Family.GENERIC


func _connection_changed(device: int, connected: bool) -> void:
	if not connected and device == active_device:
		set_device(Family.KEYBOARD)


func set_device(next: Family, device: int = -1) -> void:
	var changed := family != next or active_device != device
	family = next
	active_device = device
	main.get_node("BuildController").using_controller = family != Family.KEYBOARD
	if changed:
		repeat_direction = 0
		menu_stick = Vector2.ZERO
		menu_axis = -1
		main.get_node("BuildController")._update_interface()
		refresh_prompts()
		var prep = main.get_node("PreparationUI")
		if family != Family.KEYBOARD and _menu_open() and not (main.phase == main.Phase.PREPARATION and prep.view == prep.View.PLACEMENT):
			if get_viewport().gui_get_focus_owner() == null:
				move_focus(1)


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed or event is InputEventJoypadMotion and absf(event.axis_value) > 0.3:
		set_device(detect_family(Input.get_joy_name(event.device)), event.device)
	elif event is InputEventKey and event.pressed or event is InputEventMouseButton and event.pressed or event is InputEventMouseMotion and event.relative.length() > 2.0:
		set_device(Family.KEYBOARD)
	if event is not InputEventJoypadButton and event is not InputEventJoypadMotion:
		return
	var preparation = main.get_node("PreparationUI")
	var placement: bool = main.phase == main.Phase.PREPARATION and preparation.view == preparation.View.PLACEMENT and not get_tree().paused
	if event is InputEventJoypadMotion:
		if event.axis not in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
			return
		menu_stick[event.axis] = event.axis_value
		if placement:
			if absf(event.axis_value) > 0.3:
				_release_focus()
		elif _menu_open():
			# Keep the active axis until released. Neutral/jitter events from
			# the other axis must not reset the held direction's repeat delay.
			if menu_axis == -1 or absf(menu_stick[menu_axis]) <= 0.5:
				menu_axis = JOY_AXIS_LEFT_X if absf(menu_stick.x) > absf(menu_stick.y) else JOY_AXIS_LEFT_Y
			var value: float = menu_stick[menu_axis]
			var direction := int(signf(value)) if absf(value) > 0.5 else 0
			if direction != repeat_direction:
				repeat_direction = direction
				repeat_left = 0.35
				if direction != 0:
					move_focus(direction)
			get_viewport().set_input_as_handled()
		return
	if not event.pressed:
		# Keep GUI's built-in ui_accept from also activating on release.
		if _menu_open():
			get_viewport().set_input_as_handled()
		return
	if not _menu_open():
		return # Combat actions remain in Lantern and PauseScreen.
	if event.is_action_pressed("pause_run") and get_tree().paused:
		main.get_node("PauseScreen").resume()
	elif event.is_action_pressed("cancel_placement"):
		if get_tree().paused:
			main.get_node("PauseScreen").resume()
		elif main.phase == main.Phase.RESULTS:
			var results = main.get_node("ResultsScreen")
			if results.showing_records:
				results.show_page(false)
			else:
				main.continue_to_preparation()
		elif main.get_node("BuildController").placing:
			main.get_node("BuildController").cancel_placement()
		else:
			preparation.open_view(preparation.View.HOME)
	elif event.is_action_pressed("confirm_placement"):
		var focused := get_viewport().gui_get_focus_owner()
		if focused is BaseButton and focused in menu_controls():
			focused.pressed.emit()
		elif placement:
			var build = main.get_node("BuildController")
			build._select_or_place(build.controller_cursor)
		else:
			move_focus(1)
	elif event.is_action_pressed("build_turret") and main.phase == main.Phase.PREPARATION and not get_tree().paused:
		main.get_node("BuildController").begin_placement()
		_release_focus()
	elif event.is_action_pressed("toggle_build_controls") and placement:
		preparation._toggle_controls()
		_release_focus()
	elif event.is_action_pressed("sell_turret") and placement:
		main.get_node("BuildController").sell_selected_turret()
	elif event.is_action_pressed("start_run") and main.phase == main.Phase.PREPARATION:
		main.start_run()
	elif event.button_index in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_LEFT]:
		move_focus(-1)
	elif event.button_index in [JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_RIGHT]:
		move_focus(1)
	get_viewport().set_input_as_handled()
	refresh_prompts()


func _process(delta: float) -> void:
	var focused := get_viewport().gui_get_focus_owner()
	var focus_id := focused.get_instance_id() if focused != null else 0
	if focus_id != last_focus_id:
		last_focus_id = focus_id
		refresh_prompts()
	if not _menu_open():
		repeat_direction = 0
	if repeat_direction != 0 and _menu_open():
		var prep = main.get_node("PreparationUI")
		if main.phase == main.Phase.PREPARATION and prep.view == prep.View.PLACEMENT:
			repeat_direction = 0
			return
		repeat_left -= delta
		if repeat_left <= 0:
			move_focus(repeat_direction)
			repeat_left = 0.14


func _menu_open() -> bool:
	return get_tree().paused or main.phase != main.Phase.RUNNING


func _release_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()


func menu_controls() -> Array[Control]:
	var scope: Node = main.get_node("PreparationUI")
	if get_tree().paused:
		scope = main.get_node("PauseScreen")
	elif main.phase == main.Phase.RESULTS:
		scope = main.get_node("ResultsScreen")
	var controls: Array[Control] = []
	_collect_controls(scope, controls)
	return controls


func _collect_controls(node: Node, controls: Array[Control]) -> void:
	if node is Control and not node.is_visible_in_tree():
		return
	if node is BaseButton and not node.disabled and node.focus_mode == Control.FOCUS_ALL or node is LineEdit:
		controls.append(node)
	for child in node.get_children():
		_collect_controls(child, controls)


func move_focus(direction: int) -> void:
	var controls := menu_controls()
	if controls.is_empty():
		return
	var index := controls.find(get_viewport().gui_get_focus_owner())
	index = posmod(index + direction, controls.size()) if index >= 0 else (0 if direction > 0 else controls.size() - 1)
	controls[index].grab_focus()
	refresh_prompts()


func button_index(action: String) -> int:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			return event.button_index
	return -1


func hint(action: String) -> String:
	if family == Family.KEYBOARD:
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				return OS.get_keycode_string(event.physical_keycode if event.physical_keycode else event.keycode)
		return "Click"
	var index := button_index(action)
	if family == Family.PLAYSTATION:
		return {0: "Cross", 1: "Circle", 2: "Square", 3: "Triangle", 5: "R1", 6: "Options"}.get(index, "Confirm")
	if family == Family.XBOX:
		return {0: "A", 1: "B", 2: "X", 3: "Y", 5: "RB", 6: "Menu"}.get(index, "Confirm")
	return {0: "Bottom button", 1: "Right button", 2: "Left button", 3: "Top button", 5: "Right bumper", 6: "Menu"}.get(index, "Confirm")


func icon_for(action: String) -> Texture2D:
	if family == Family.KEYBOARD:
		return null
	var index := button_index(action)
	var key := "%d:%d" % [family, index]
	if icons.has(key):
		return icons[key]
	var shape := ""
	if index in [0, 1, 2, 3] and family == Family.PLAYSTATION:
		shape = ["<path d='M10 10L22 22M22 10L10 22' stroke='#90caff'/>", "<circle cx='16' cy='16' r='8' stroke='#ffa39d'/>", "<rect x='9' y='9' width='14' height='14' stroke='#efacde'/>", "<path d='M16 7L25 23H7Z' stroke='#9ae1b3'/>"][index]
	elif index in [0, 1, 2, 3] and family == Family.GENERIC:
		for i in range(4):
			var point: Vector2 = [Vector2(16, 24), Vector2(24, 16), Vector2(8, 16), Vector2(16, 8)][i]
			shape += "<circle cx='%d' cy='%d' r='3' fill='%s' stroke='none'/>" % [point.x, point.y, "#ffcf7a" if i == index else "#667985"]
	elif index == JOY_BUTTON_RIGHT_SHOULDER:
		var right_letter := "M6 23V9H11Q18 9 15 16H6M11 16L16 23"
		var suffix := "M21 12L24 9V23" if family == Family.PLAYSTATION else "M20 9V23H24Q30 23 27 16Q30 9 24 9ZM20 16H25"
		shape = "<path d='%s %s' stroke='#e8f1f1'/>" % [right_letter, suffix]
	else:
		# Use paths for letters: no font dependency or missing Unicode glyphs.
		shape = {0: "M10 23L16 9L22 23M12 19H20", 1: "M11 9V23H17Q24 23 21 17Q24 9 17 9ZM11 16H18", 2: "M10 9L22 23M22 9L10 23", 3: "M10 9L16 16L22 9M16 16V23", 5: "M8 22V10H13Q20 10 16 16H8M13 16L19 22M23 10V22", 6: "M9 10H23M9 16H23M9 22H23"}.get(index, "M10 16H22")
		shape = "<path d='%s' stroke='#e8f1f1'/>" % shape
	var svg := "<svg xmlns='http://www.w3.org/2000/svg' width='32' height='32' viewBox='0 0 32 32'><circle cx='16' cy='16' r='15' fill='#17232d' stroke='#637d8a'/><g fill='none' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'>%s</g></svg>" % shape
	var image := Image.new()
	image.load_svg_from_string(svg)
	var texture := ImageTexture.create_from_image(image)
	icons[key] = texture
	return texture


func decorate(button: Button, action: String) -> void:
	# Standard menu confirmation needs no icon; show only dedicated shortcuts.
	button.icon = icon_for(action) if action != "confirm_placement" else null
	button.add_theme_constant_override("icon_max_width", 24)
	button.tooltip_text = button.text if action == "confirm_placement" else "%s · %s" % [button.text, hint(action)]


func refresh_prompts() -> void:
	var prep = main.get_node("PreparationUI")
	var build = main.get_node("BuildController")
	for button in [prep.place_button, prep.upgrades_button, prep.records_button, prep.back_button, build.start_button, build.quit_button, build.reset_button, build.damage_button, build.rate_button, build.health_button]:
		decorate(button, "confirm_placement")
	for pair in [[build.build_button, "build_turret"], [build.cancel_button, "cancel_placement"], [prep.hide_button, "toggle_build_controls"], [prep.show_button, "toggle_build_controls"], [build.sell_button, "sell_turret"]]:
		decorate(pair[0], pair[1])
	for button in main.get_node("GameHUD").leaderboard.find_children("*", "Button", true, false):
		decorate(button, "confirm_placement")
	var pause = main.get_node("PauseScreen")
	decorate(pause.resume_button, "confirm_placement")
	decorate(pause.end_run_button, "confirm_placement")
	pause.keys.text = "Esc / P to resume"
	pause.keys.visible = family == Family.KEYBOARD
	decorate(main.get_node("ResultsScreen").continue_button, "confirm_placement")
	var indicator = main.get_node("GameHUD").brightness_indicator
	indicator.tooltip_text = "Brightness · %s to cycle" % hint("cycle_brightness")
	indicator.prompt_icon = icon_for("cycle_brightness")
	indicator.queue_redraw()
