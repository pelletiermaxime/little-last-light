extends CanvasLayer

enum View { HOME, PLACEMENT, UPGRADES, RECORDS }
const STYLE = preload("res://ui_style.gd")

var main: Node2D
var build: Node2D
var view: View = View.HOME
var card: PanelContainer
var scroll: MarginContainer
var content: VBoxContainer
var title: Label
var balance: Label
var description: Label
var actions: GridContainer
var footer: GridContainer
var place_button: Button
var upgrades_button: Button
var records_button: Button
var settings_button: Button
var back_button: Button
var hide_button: Button
var show_button: Button
var card_style: StyleBoxFlat
var records_host: VBoxContainer
var controls_hidden := false


func _ready() -> void:
	layer = 6
	main = get_parent()
	build = main.get_node("BuildController")
	card = PanelContainer.new()
	card_style = STYLE.panel()
	card.add_theme_stylebox_override("panel", card_style)
	add_child(card)
	scroll = MarginContainer.new()
	card.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	title = STYLE.label("Build your refuge", 26, Color("#ffcf7a"))
	content.add_child(title)
	balance = STYLE.label("", 16)
	content.add_child(balance)
	description = STYLE.label("", 14, Color("#a6bdc7"))
	content.add_child(description)
	actions = GridContainer.new()
	actions.add_theme_constant_override("h_separation", 10)
	actions.add_theme_constant_override("v_separation", 12)
	content.add_child(actions)
	place_button = _button("Place turrets", func(): open_view(View.PLACEMENT))
	upgrades_button = _button("Buy upgrades", func(): open_view(View.UPGRADES))
	for button in [build.start_button, build.build_button, build.cancel_button, build.sell_button, build.reset_button, build.damage_button, build.rate_button, build.health_button]:
		button.reparent(actions)
		button.custom_minimum_size.x = 0
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		STYLE.button(button, button == build.start_button)
	actions.move_child(build.start_button, 0)
	records_host = VBoxContainer.new()
	content.add_child(records_host)
	footer = GridContainer.new()
	footer.add_theme_constant_override("v_separation", 12)
	content.add_child(footer)
	back_button = _button("Done · Esc", func(): open_view(View.HOME), footer)
	hide_button = _button("Hide controls · Tab", _toggle_controls, footer)
	show_button = _button("Show controls · Tab", _toggle_controls, self)
	show_button.position = Vector2(16, 16)
	records_button = _button("Records", func(): open_view(View.RECORDS), footer)
	settings_button = _button("Settings", func(): main.get_node("SettingsScreen").open(settings_button), footer)
	build.quit_button.reparent(footer)
	build.quit_button.custom_minimum_size.x = 0
	build.quit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	STYLE.button(build.quit_button)
	# BuildController creates the actions; this card owns their presentation.
	build.bar.hide()
	get_viewport().size_changed.connect(refresh)
	refresh()
	build.start_button.call_deferred("grab_focus")


func _button(text: String, callback: Callable, parent: Node = null) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	STYLE.button(button)
	(parent if parent != null else actions).add_child(button)
	button.pressed.connect(callback)
	return button


func open_view(next: View) -> void:
	if main.phase != main.Phase.PREPARATION:
		return
	if view != next:
		get_node("/root/GameAudio").play(&"back" if next == View.HOME else &"confirm")
		build.cancel_placement(false)
		controls_hidden = false
	view = next
	refresh()
	if view == View.HOME:
		build.start_button.grab_focus()
	elif view == View.UPGRADES or view == View.RECORDS:
		var controls := main.get_node_or_null("Controls")
		if controls != null and controls.is_node_ready():
			controls.move_focus(1)
	elif view == View.PLACEMENT:
		var focused := get_viewport().gui_get_focus_owner()
		if focused != null:
			focused.release_focus()


func _toggle_controls() -> void:
	if view != View.PLACEMENT:
		return
	controls_hidden = not controls_hidden
	get_node("/root/GameAudio").play(&"confirm")
	refresh()


func refresh() -> void:
	if not is_instance_valid(card):
		return
	var preparing: bool = main.phase == main.Phase.PREPARATION
	card.visible = preparing and not (view == View.PLACEMENT and controls_hidden)
	show_button.visible = preparing and view == View.PLACEMENT and controls_hidden
	build.bar.hide()
	if not preparing:
		return
	var home := view == View.HOME
	var placement := view == View.PLACEMENT
	var upgrades := view == View.UPGRADES
	var records := view == View.RECORDS
	place_button.visible = home
	upgrades_button.visible = home
	build.start_button.visible = home
	build.start_button.text = "Start run"
	build.build_button.visible = placement
	build.build_button.text = "New turret · %d%s" % [int(build.turret_cost()), "" if build.using_controller else " (B)"]
	build.cancel_button.visible = placement and build.placing
	build.cancel_button.text = "Cancel placement" if build.using_controller else "Cancel placement · Esc"
	back_button.text = "Done" if build.using_controller else "Done · Esc"
	hide_button.text = "Hide controls" if build.using_controller else "Hide controls · Tab"
	show_button.text = "Show controls" if build.using_controller else "Show controls · Tab"
	if build.using_controller:
		for button in [build.damage_button, build.rate_button, build.health_button]:
			button.text = button.text.replace(" (Confirm)", "")
		build.sell_button.text = build.sell_button.text.replace(" (R1 / RB)", "")
	build.sell_button.visible = placement and is_instance_valid(build.selected_turret)
	build.reset_button.visible = placement and not build.placing
	build.reset_button.text = "Refund layout · +%d" % int(build.layout_refund())
	for button in [build.damage_button, build.rate_button, build.health_button]:
		button.visible = upgrades
	back_button.visible = not home and not (placement and build.placing)
	hide_button.visible = placement
	records_button.visible = home
	settings_button.visible = home
	build.quit_button.visible = home and not OS.has_feature("web")
	records_host.visible = records
	var hud = main.get_node("GameHUD")
	if hud.leaderboard.get_parent() != records_host and main.phase == main.Phase.PREPARATION:
		hud.leaderboard.reparent(records_host)
	var count := get_tree().get_nodes_in_group("turrets").size()
	balance.text = "%d energy  ·  %d turret%s  ·  %d HP" % [int(main.banked_energy), count, "" if count == 1 else "s", int(main.lantern_max_health())]
	title.text = "Build your refuge" if home else ("Arrange your defense" if placement else ("Make the light stronger" if upgrades else "Your records"))
	title.add_theme_font_size_override("font_size", 18 if placement else 26)
	balance.visible = not placement
	if placement:
		title.text = "Arrange your defense · %d energy" % int(main.banked_energy)
	description.text = "Place your defense. Choose your upgrades. See how long your light lasts." if home else ("Click a turret to move or sell it. B buys a new one." if placement else ("Permanent improvements for every future run." if upgrades else "Best: %s · %s" % [hud.format_time(main.best_time), main.game_version]))
	if placement and build.placing:
		description.text = "Place through the card background. Tab hides all controls. Esc cancels."
	if build.using_controller and placement:
		description.text = "Left stick: cursor · D-pad: toolbar
Confirm: select / place · Back: cancel / done"
	if not main.save_message.is_empty():
		description.text = main.save_message
	var size := get_viewport().get_visible_rect().size
	actions.columns = 1
	footer.columns = 1
	var width := minf(660 if home else (280 if placement else 420), size.x - 32)
	var height := minf(280 if home else (440 if placement else 460), size.y - 32)
	if size.x < 700:
		height = minf(410 if home else 460, size.y - 32)
	card.size = Vector2(width, height)
	card.position = Vector2(16 if placement else (size.x - width) / 2, (size.y - height) / 2)
	card_style.bg_color.a = 0.62 if home else (0.28 if placement else 0.94)
	call_deferred("_fit_layout")
	card_style.border_color.a = 0.4 if home or placement else 1.0
	card_style.shadow_color.a = 0.08 if home or placement else 0.3
	# Ignore background UI hits in placement; interactive buttons still receive clicks.
	for control in [card, scroll, content, actions, footer, records_host]:
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE if placement else Control.MOUSE_FILTER_PASS
	for parent in [actions, footer]:
		for child in parent.get_children():
			if child is Button:
				for state in ["normal", "hover", "pressed", "disabled"]:
					var style = child.get_theme_stylebox(state)
					style.bg_color.a = (0.8 if child == build.start_button else 0.45) if home or placement else 1.0

	var controls := main.get_node_or_null("Controls")
	if controls != null and controls.is_node_ready():
		controls.refresh_prompts()


func _fit_layout() -> void:
	STYLE.fit_card(card, get_viewport().get_visible_rect().size, view == View.PLACEMENT)
	_position_lantern()


func _position_lantern() -> void:
	if main.phase != main.Phase.PREPARATION:
		return
	# Wait until the scene has initialized its starting turret beside the lantern.
	# The home screen's presentation must not change that initial defense layout.
	if view == View.HOME:
		main.lantern.position = Vector2(card.position.x + card.size.x * card.scale.x / 2.0, maxf(32.0, card.position.y - 72.0))
	else:
		main.lantern._center_in_viewport()


func blocks_point(point: Vector2) -> bool:
	if show_button.visible and show_button.get_global_rect().has_point(point):
		return true
	if not card.visible or not card.get_global_rect().has_point(point):
		return false
	if view != View.PLACEMENT:
		return true
	for parent in [actions, footer]:
		for child in parent.get_children():
			if child is Button and child.is_visible_in_tree() and child.get_global_rect().has_point(point):
				return true
	return false


func activate_at(point: Vector2) -> void:
	if show_button.visible and show_button.get_global_rect().has_point(point):
		show_button.pressed.emit()
		return
	# The gamepad cursor can use the toolbar as well as select world turrets.
	for parent in [actions, footer]:
		for child in parent.get_children():
			if child is Button and child.is_visible_in_tree() and not child.disabled and child.get_global_rect().has_point(point):
				child.pressed.emit()
				return


func _input(event: InputEvent) -> void:
	if main.phase == main.Phase.PREPARATION and view == View.PLACEMENT and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_TAB:
		_toggle_controls()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if main.phase != main.Phase.PREPARATION or event.is_echo():
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_U:
		open_view(View.UPGRADES)
		get_viewport().set_input_as_handled()
