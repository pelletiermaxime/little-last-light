extends CanvasLayer

enum View { HOME, PLACEMENT, UPGRADES, RECORDS }
const STYLE = preload("res://ui/ui_style.gd")

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
var slow_buttons: Dictionary = {}
var upgrade_progress: Dictionary = {}
var upgrade_summaries: Dictionary = {}
var upgrade_panel: MarginContainer
var upgrade_groups: GridContainer
var energy_button: Button
var proximity_button: Button
var placement_stats: Dictionary = {}


func _ready() -> void:
	layer = 6
	main = get_parent()
	build = main.get_node("BuildController")
	card = $Card
	scroll = $Card/Padding
	content = $Card/Padding/Content
	title = $Card/Padding/Content/Title
	balance = $Card/Padding/Content/Balance
	description = $Card/Padding/Content/Description
	actions = $Card/Padding/Content/Actions
	footer = $Card/Padding/Content/Footer
	records_host = $Card/Padding/Content/RecordsHost
	place_button = $Card/Padding/Content/Actions/PlaceButton
	upgrades_button = $Card/Padding/Content/Actions/UpgradesButton
	back_button = $Card/Padding/Content/Footer/BackButton
	hide_button = $Card/Padding/Content/Footer/HideButton
	records_button = $Card/Padding/Content/Footer/RecordsButton
	settings_button = $Card/Padding/Content/Footer/SettingsButton
	show_button = $ShowButton
	place_button.pressed.connect(func(): open_view(View.PLACEMENT))
	upgrades_button.pressed.connect(func(): open_view(View.UPGRADES))
	back_button.pressed.connect(go_back)
	slow_buttons = {
		"slow_rate": actions.get_node("SlowRateButton"),
		"slow_strength": actions.get_node("SlowStrengthButton"),
		"slow_duration": actions.get_node("SlowDurationButton"),
	}
	for kind in slow_buttons:
		slow_buttons[kind].pressed.connect(main.buy_upgrade.bind(kind))
	energy_button = Button.new()
	energy_button.name = "EnergyGainButton"
	actions.add_child(energy_button)
	energy_button.pressed.connect(main.buy_upgrade.bind("energy"))
	proximity_button = Button.new()
	proximity_button.name = "ProximityPowerButton"
	actions.add_child(proximity_button)
	proximity_button.pressed.connect(main.buy_upgrade.bind("proximity"))
	hide_button.pressed.connect(_toggle_controls)
	show_button.pressed.connect(_toggle_controls)
	records_button.pressed.connect(func(): open_view(View.RECORDS))
	settings_button.pressed.connect(func(): main.get_node("SettingsScreen").open(settings_button))
	# Preparation changes background opacity; never mutate the shared Theme.
	card_style = card.get_theme_stylebox("panel").duplicate()
	card.add_theme_stylebox_override("panel", card_style)
	for parent in [actions, footer]:
		for button in parent.get_children():
			for state in ["normal", "hover", "pressed", "disabled"]:
				button.add_theme_stylebox_override(state, button.get_theme_stylebox(state).duplicate())
	_create_placement_stats()
	_create_upgrade_groups()
	get_viewport().size_changed.connect(refresh)
	refresh()
	build.start_button.call_deferred("grab_focus")


func _create_placement_stats() -> void:
	var buttons := {"damage": build.build_button, "pulse": build.pulse_button, "sniper": build.sniper_button, "ember": build.ember_button}
	for kind in buttons:
		# Read the scene defaults once, before upgrades or proximity are applied.
		var turret: Node2D = main.turret_scene(kind).instantiate()
		var cadence := "pulse" if kind == "pulse" else "shot"
		var text := "%s dmg · %.0f range · %ss/%s" % [String.num(turret.damage, 1).trim_suffix(".0"), turret.attack_range, String.num(turret.fire_interval, 1).trim_suffix(".0"), cadence]
		if kind == "pulse":
			text += "\n%.0f%% slow · lasts %ss" % [(1.0 - turret.slow_factor) * 100, String.num(turret.slow_duration, 1).trim_suffix(".0")]
		elif kind == "ember":
			text += "\n65 splash · 0.45s flight"
		else:
			text += "\n" + ("Furthest target" if kind == "sniper" else "Nearest target")
		var label := STYLE.label(text, 12, Color("#bfd0d8"))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		actions.add_child(label)
		actions.move_child(label, buttons[kind].get_index() + 1)
		placement_stats[kind] = label
		turret.free()


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
	elif view != View.PLACEMENT:
		var controls := main.get_node_or_null("Controls")
		if controls != null and controls.is_node_ready():
			controls.focus_default()
	elif view == View.PLACEMENT:
		var focused := get_viewport().gui_get_focus_owner()
		if focused != null:
			focused.release_focus()


func go_back() -> void:
	var previous := view
	open_view(View.HOME)
	match previous:
		View.UPGRADES:
			upgrades_button.grab_focus()
		View.RECORDS:
			records_button.grab_focus()
		View.PLACEMENT:
			place_button.grab_focus()


func _create_upgrade_groups() -> void:
	upgrade_panel = $Card/Padding/Content/UpgradePanel
	upgrade_groups = upgrade_panel.get_node("Groups")
	var groups := {
		"Damage turrets": {"damage": build.damage_button, "fire_rate": build.rate_button},
		"Slow turrets": slow_buttons,
		"Lantern": {"health": build.health_button, "energy": energy_button, "proximity": proximity_button},
	}
	for group_name in groups:
		var group := VBoxContainer.new()
		group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		group.add_theme_constant_override("separation", 8)
		upgrade_groups.add_child(group)
		group.add_child(STYLE.label(group_name, 18, Color("#ffd17b")))
		var summary := STYLE.label("", 12)
		summary.custom_minimum_size.y = 34
		group.add_child(summary)
		upgrade_summaries[group_name] = summary
		for kind in groups[group_name]:
			var item := VBoxContainer.new()
			item.add_theme_constant_override("separation", 5)
			group.add_child(item)
			var button: Button = groups[group_name][kind]
			button.set_meta("upgrade_kind", kind)
			button.reparent(item)
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.custom_minimum_size.y = 52
			button.add_theme_font_size_override("font_size", 15)
			for state in ["normal", "hover", "pressed", "disabled", "focus"]:
				var style: StyleBox = button.get_theme_stylebox(state).duplicate()
				style.content_margin_top = 6
				style.content_margin_bottom = 6
				style.content_margin_left = 10
				style.content_margin_right = 10
				button.add_theme_stylebox_override(state, style)
			var progress := HBoxContainer.new()
			progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
			progress.add_theme_constant_override("separation", 6)
			item.add_child(progress)
			for level in range(main.MAX_UPGRADE_LEVEL):
				var segment := ColorRect.new()
				segment.custom_minimum_size = Vector2(18, 4)
				segment.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
				progress.add_child(segment)
			var label := STYLE.label("", 12)
			label.autowrap_mode = TextServer.AUTOWRAP_OFF
			progress.add_child(label)
			upgrade_progress[kind] = progress
	# Explicit neighbors keep compact, differently wrapped labels from making
	# native arrow navigation jump diagonally into the next column.
	var columns := [[build.damage_button, build.rate_button], [slow_buttons.slow_rate, slow_buttons.slow_strength, slow_buttons.slow_duration], [build.health_button, energy_button, proximity_button]]
	for column in range(columns.size()):
		for row in range(columns[column].size()):
			var button: Button = columns[column][row]
			button.focus_neighbor_top = button.get_path_to(columns[column][maxi(0, row - 1)])
			button.focus_neighbor_bottom = button.get_path_to(columns[column][row + 1] if row + 1 < columns[column].size() else back_button)
			var left: Array = columns[maxi(0, column - 1)]
			var right: Array = columns[mini(columns.size() - 1, column + 1)]
			button.focus_neighbor_left = button.get_path_to(left[mini(row, left.size() - 1)])
			button.focus_neighbor_right = button.get_path_to(right[mini(row, right.size() - 1)])


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
	if not preparing:
		return
	var home := view == View.HOME
	var placement := view == View.PLACEMENT
	for label in placement_stats.values():
		label.visible = placement
	var upgrades := view == View.UPGRADES
	var records := view == View.RECORDS
	place_button.visible = home
	upgrades_button.visible = home
	build.start_button.visible = home
	build.start_button.text = "Start run"
	build.build_button.visible = placement
	build.build_button.text = "Damage turret · %d" % int(build.turret_cost())
	build.pulse_button.visible = placement
	build.pulse_button.text = "Slow turret · %d" % int(build.turret_cost("pulse"))
	build.sniper_button.visible = placement
	build.sniper_button.text = "Watchlight · %d" % int(build.turret_cost("sniper"))
	build.ember_button.visible = placement
	build.ember_button.text = "Ember Pot · %d" % int(build.turret_cost("ember"))
	build.cancel_button.visible = placement and build.placing
	build.cancel_button.text = "Cancel placement" if build.using_controller else "Cancel placement · Esc"
	back_button.text = "Done" if build.using_controller else "Done · Esc"
	if upgrades:
		back_button.text = "Back" if build.using_controller else "Back · Esc"
	hide_button.text = "Hide controls" if build.using_controller else "Hide controls · Tab"
	show_button.text = "Show controls" if build.using_controller else "Show controls · Tab"
	if build.using_controller:
		for button in [build.damage_button, build.rate_button, build.health_button]:
			button.text = button.text.replace(" (Confirm)", "")
		build.sell_button.text = build.sell_button.text.replace(" (R1 / RB)", "")
	build.sell_button.visible = placement and is_instance_valid(build.selected_turret)
	build.reset_button.visible = placement and not build.placing
	build.reset_button.text = "Refund layout · +%d" % int(build.layout_refund())
	upgrade_panel.visible = upgrades
	build.damage_button.visible = upgrades
	build.rate_button.visible = upgrades
	build.health_button.visible = upgrades
	energy_button.visible = upgrades
	energy_button.disabled = build.placing or main.energy_level >= main.MAX_UPGRADE_LEVEL or main.banked_energy < main.upgrade_cost("energy")
	energy_button.text = "Energy gain · +125% · MAX" if main.energy_level >= main.MAX_UPGRADE_LEVEL else "Energy gain · +%d%% to +%d%%\n%d energy" % [main.energy_level * 25, (main.energy_level + 1) * 25, int(main.upgrade_cost("energy"))]
	proximity_button.visible = upgrades
	proximity_button.disabled = build.placing or main.proximity_level >= main.MAX_UPGRADE_LEVEL or main.banked_energy < main.upgrade_cost("proximity")
	proximity_button.text = "Proximity · ×2.0 damage & rate · MAX" if main.proximity_level >= main.MAX_UPGRADE_LEVEL else "Proximity · ×%.1f to ×%.1f damage & rate\n%d energy" % [main.proximity_multiplier(), main.proximity_multiplier() + 0.1, int(main.upgrade_cost("proximity"))]
	_refresh_slow_upgrades()
	var levels: Dictionary = main.upgrade_levels()
	for kind in upgrade_progress:
		var progress: HBoxContainer = upgrade_progress[kind]
		for level in range(main.MAX_UPGRADE_LEVEL):
			progress.get_child(level).color = Color("#ffd17b") if level < levels[kind] else Color("#354955")
		progress.get_child(main.MAX_UPGRADE_LEVEL).text = " %d/%d" % [levels[kind], main.MAX_UPGRADE_LEVEL]
	upgrade_summaries["Damage turrets"].text = "Basic: %.1f damage · %.2f shots/s\nWatchlight: %.1f damage · %.2f shots/s\nEmber Pot: %.1f damage · %.2f shots/s" % [main.turret_damage(), main.turret_shots_per_second(), main.turret_damage() * 3.0, main.turret_shots_per_second() / 3.0, main.turret_damage(), main.turret_shots_per_second() / 2.0]
	upgrade_summaries["Slow turrets"].text = "%.0f%% slow · lasts %.2fs\nActivates every %.1fs" % [main.slow_strength() * 100, main.slow_duration(), main.slow_interval()]
	upgrade_summaries["Lantern"].text = "%.0f maximum HP\n+%d%% passive & boss energy" % [main.lantern_max_health(), main.energy_level * 25]
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
	title.add_theme_font_size_override("font_size", 18 if placement else (22 if upgrades else 26))
	balance.add_theme_font_size_override("font_size", 14 if upgrades else 16)
	description.add_theme_font_size_override("font_size", 14 if upgrades else 16)
	content.add_theme_constant_override("separation", 8 if upgrades else 12)
	balance.visible = not placement
	if placement:
		title.text = "Arrange your defense · %d energy" % int(main.banked_energy)
	description.text = "Place your defense. Choose your upgrades. See how long your light lasts." if home else ("Click a turret to move or sell it. Use the buttons to buy." if placement else ("Permanent improvements for every future run." if upgrades else "Best: %s · %s" % [hud.format_time(main.best_time), main.game_version]))
	if placement:
		description.text = "Base stats before upgrades or proximity. Click a turret to move or sell."
	elif upgrades:
		title.text = "Improve your defense"
		description.text = "Permanent upgrades for every turret of its type and your lantern."
	if placement and build.placing:
		description.text = "Place through the card background. Tab hides all controls. Esc cancels."
	if build.using_controller and placement:
		description.text = "Base stats before upgrades or proximity.\nStick: cursor · D-pad: toolbar\nConfirm: place · Back: done"
	if not main.save_message.is_empty():
		description.text = main.save_message
	var size := get_viewport().get_visible_rect().size
	actions.columns = 1
	footer.columns = 1
	var width := minf(660 if home else (280 if placement else 420), size.x - 32)
	var height := minf(280 if home else (440 if placement else 460), size.y - 32)
	if size.x < 700:
		height = minf(410 if home else 460, size.y - 32)
	if upgrades:
		# Keep every group visible together. Small windows scale the complete card.
		width = maxf(900, minf(1060, size.x - 32))
		height = minf(580, size.y - 32)
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


func _refresh_slow_upgrades() -> void:
	var labels := {
		"slow_rate": "Activation · every %.2fs to %.2fs" % [main.slow_interval(), main.slow_interval() - 0.15],
		"slow_strength": "Strength · %.0f%% to %.0f%% slower" % [main.slow_strength() * 100, main.slow_strength() * 100 + 5],
		"slow_duration": "Duration · %.2fs to %.2fs" % [main.slow_duration(), main.slow_duration() + 0.15],
	}
	var capped := {
		"slow_rate": "Activation · every %.1fs · MAX" % main.slow_interval(),
		"slow_strength": "Strength · %.0f%% slower · MAX" % (main.slow_strength() * 100),
		"slow_duration": "Duration · %.2fs · MAX" % main.slow_duration(),
	}
	for kind in slow_buttons:
		var button: Button = slow_buttons[kind]
		var at_cap: bool = main.slow_levels[kind] >= main.MAX_UPGRADE_LEVEL
		button.visible = view == View.UPGRADES
		button.disabled = build.placing or at_cap or main.banked_energy < main.upgrade_cost(kind)
		button.text = capped[kind] if at_cap else "%s\n%d energy" % [labels[kind], int(main.upgrade_cost(kind))]


func _fit_layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	STYLE.fit_card(card, viewport_size, view == View.PLACEMENT)
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
