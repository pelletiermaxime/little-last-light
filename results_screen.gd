extends CanvasLayer

var main: Node2D
var overlay: ColorRect
var card: PanelContainer
var title: Label
var stats: Label
var best: Label
var save_notice: Label
var content: VBoxContainer
var continue_button: Button


func _ready() -> void:
	main = get_parent()
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay = ColorRect.new()
	overlay.color = Color(0.025, 0.04, 0.06, 0.94)
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card = PanelContainer.new()
	overlay.add_child(card)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#18242e")
	style.set_corner_radius_all(12)
	style.set_content_margin_all(24)
	card.add_theme_stylebox_override("panel", style)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	scroll.add_child(content)
	title = _label(30, Color("#ffcf7a"))
	stats = _label(24, Color("#eff3f0"))
	best = _label(16, Color("#9aaebc"))
	save_notice = _label(14, Color("#ff997d"))
	continue_button = Button.new()
	continue_button.text = "Continue to preparation"
	continue_button.custom_minimum_size.y = 48
	continue_button.pressed.connect(main.continue_to_preparation)
	content.add_child(continue_button)
	get_viewport().size_changed.connect(_layout)
	_layout()
	overlay.hide()


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(label)
	return label


func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	card.size = Vector2(minf(500, viewport_size.x - 32), minf(590, viewport_size.y - 32))
	card.position = (viewport_size - card.size) / 2.0


func show_results() -> void:
	var hud = main.get_node("GameHUD")
	title.text = "Run ended" if main.last_run.voluntary else "The light went out"
	stats.text = "Survived %s\n+%d energy earned" % [hud.format_time(main.last_run.duration), int(main.last_run.energy)]
	best.text = "%sBest: %s · %d energy available" % ["New personal best!\n" if main.last_run.new_best else "", hud.format_time(main.best_time), int(main.banked_energy)]
	# Move the existing panel, preserving in-flight requests and retry state.
	hud.leaderboard.reparent(content)
	content.move_child(hud.leaderboard, continue_button.get_index())
	hud.leaderboard.refresh()
	hud.scroll.hide()
	main.get_node("BuildController")._update_interface()
	overlay.show()
	continue_button.grab_focus()


func hide_results() -> void:
	var hud = main.get_node("GameHUD")
	hud.leaderboard.reparent(hud.panel)
	hud.panel.move_child(hud.leaderboard, main.get_node("BuildController").bar.get_index())
	hud.scroll.show()
	overlay.hide()
	continue_button.release_focus()


func _process(_delta: float) -> void:
	if overlay.visible:
		save_notice.text = main.save_message
		save_notice.visible = not main.save_message.is_empty()


func _unhandled_input(event: InputEvent) -> void:
	if main.phase != main.Phase.RESULTS or event.is_echo():
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	if event.is_action_pressed("start_run") or event.is_action_pressed("cancel_placement"):
		main.continue_to_preparation()
		get_viewport().set_input_as_handled()
