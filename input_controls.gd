extends Node

# Last child of Main: receives input before menus or gameplay can consume it.
# Prompts and controller routing share the same InputMap actions.
var prompts: Node
var main: Node2D
var repeat_direction := 0
var repeat_left := 0.0
var menu_stick := Vector2.ZERO
var menu_axis := -1
var last_focus_id := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	main = get_parent()
	prompts = get_node("/root/ControllerIcons")
	# Feed the addon first: handled menu events do not reach earlier autoloads.
	prompts.set_process_input(false)
	prompts.input_type_changed.connect(_input_type_changed)
	# LinkButton defaults to accessibility-only focus in this Godot version.
	for button in main.get_node("GameHUD").leaderboard.find_children("*", "BaseButton", true, false):
		button.focus_mode = Control.FOCUS_ALL


func using_controller() -> bool:
	return prompts.get_last_input_type() == prompts.InputType.CONTROLLER


func _input_type_changed(_input_type: int, _controller: int) -> void:
	main.get_node("BuildController").using_controller = using_controller()
	repeat_direction = 0
	menu_stick = Vector2.ZERO
	menu_axis = -1
	main.get_node("BuildController")._update_interface()
	refresh_prompts()
	var prep = main.get_node("PreparationUI")
	if using_controller() and _menu_open() and not (main.phase == main.Phase.PREPARATION and prep.view == prep.View.PLACEMENT):
		if get_viewport().gui_get_focus_owner() == null:
			move_focus(1)


func _exit_tree() -> void:
	if is_instance_valid(prompts):
		prompts.set_process_input(true)


func _input(event: InputEvent) -> void:
	prompts._input(event)
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


func hint(action: String) -> String:
	return prompts.parse_path_to_tts(action)


func icon_for(action: String) -> Texture2D:
	return prompts.parse_path(action) if using_controller() else null


func decorate(button: Button, action: String) -> void:
	# Standard menu confirmation needs no icon; show only dedicated shortcuts.
	button.icon = icon_for(action) if action != "confirm_placement" else null
	button.add_theme_constant_override("icon_max_width", 24)
	button.tooltip_text = "%s · %s" % [button.text, hint(action)] if using_controller() and action != "confirm_placement" else button.text


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
	pause.keys.visible = not using_controller()
	decorate(main.get_node("ResultsScreen").continue_button, "confirm_placement")
	var indicator = main.get_node("GameHUD").brightness_indicator
	indicator.tooltip_text = "Brightness · %s to cycle" % hint("cycle_brightness") if using_controller() else "Click to cycle brightness"
	indicator.prompt_icon = icon_for("cycle_brightness")
	indicator.queue_redraw()
