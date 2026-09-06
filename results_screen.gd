extends CanvasLayer

const STYLE = preload("res://ui_style.gd")
var main: Node2D
var overlay: ColorRect
var card: PanelContainer
var title: Label
var stats: Label
var best: Label
var save_notice: Label
var summary_page: VBoxContainer
var content: VBoxContainer
var continue_button: Button
var page_button: Button
var showing_records := false


func _ready() -> void:
	main = get_parent()
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay = ColorRect.new()
	overlay.color = Color(0.025, 0.04, 0.06, 0.94)
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", STYLE.panel())
	overlay.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	card.add_child(column)
	summary_page = VBoxContainer.new()
	summary_page.add_theme_constant_override("separation", 16)
	column.add_child(summary_page)
	title = STYLE.label("", 30, Color("#ffcf7a"))
	stats = STYLE.label("", 24)
	best = STYLE.label("", 16, Color("#9aaebc"))
	for label in [title, stats, best]:
		summary_page.add_child(label)
	content = VBoxContainer.new()
	column.add_child(content)
	save_notice = STYLE.label("", 14, Color("#ff997d"))
	column.add_child(save_notice)
	# The footer never belongs to either page: Continue is always reachable.
	page_button = Button.new()
	STYLE.button(page_button)
	page_button.pressed.connect(func(): show_page(not showing_records))
	column.add_child(page_button)
	continue_button = Button.new()
	continue_button.text = "Continue to preparation"
	STYLE.button(continue_button, true)
	continue_button.pressed.connect(main.continue_to_preparation)
	column.add_child(continue_button)
	get_viewport().size_changed.connect(_layout)
	show_page(false)
	overlay.hide()


func show_page(records: bool) -> void:
	showing_records = records
	summary_page.visible = not records
	content.visible = records
	page_button.text = "Back to run summary" if records else ("Publish record / Leaderboard" if not main.leaderboard_profile.pending.is_empty() else "Leaderboard")
	call_deferred("_layout")


func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	card.size = Vector2(minf(500, viewport_size.x - 32), 0)
	STYLE.fit_card(card, viewport_size)


func show_results() -> void:
	var hud = main.get_node("GameHUD")
	title.text = "Run ended" if main.last_run.voluntary else "The light went out"
	stats.text = "Survived %s\n+%d energy earned" % [hud.format_time(main.last_run.duration), int(main.last_run.energy)]
	best.text = "%sBest: %s · %d energy available" % ["New personal best!\n" if main.last_run.new_best else "", hud.format_time(main.best_time), int(main.banked_energy)]
	hud.leaderboard.reparent(content)
	hud.leaderboard.refresh()
	hud.scroll.hide()
	main.get_node("BuildController")._update_interface()
	show_page(false)
	overlay.show()
	continue_button.grab_focus()


func hide_results() -> void:
	var hud = main.get_node("GameHUD")
	hud.leaderboard.reparent(main.get_node("PreparationUI").records_host)
	hud.scroll.show()
	overlay.hide()
	continue_button.release_focus()


func _process(_delta: float) -> void:
	if overlay.visible:
		save_notice.text = main.save_message
		save_notice.visible = not main.save_message.is_empty()
		_layout()


func _unhandled_input(event: InputEvent) -> void:
	if main.phase != main.Phase.RESULTS or event.is_echo():
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	if event.is_action_pressed("start_run") or event.is_action_pressed("cancel_placement"):
		if showing_records and event.is_action_pressed("cancel_placement"):
			show_page(false)
		else:
			main.continue_to_preparation()
		get_viewport().set_input_as_handled()
