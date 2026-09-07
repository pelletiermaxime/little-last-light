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
var dawn_tween: Tween
var normal_overlay_color: Color


func _ready() -> void:
	show()
	main = get_parent()
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay = $Overlay
	normal_overlay_color = overlay.color
	card = $Overlay/Card
	summary_page = $Overlay/Card/Content/SummaryPage
	title = $Overlay/Card/Content/SummaryPage/Title
	stats = $Overlay/Card/Content/SummaryPage/Stats
	best = $Overlay/Card/Content/SummaryPage/Best
	content = $Overlay/Card/Content/RecordsHost
	save_notice = $Overlay/Card/Content/SaveNotice
	page_button = $Overlay/Card/Content/PageButton
	continue_button = $Overlay/Card/Content/ContinueButton
	page_button.pressed.connect(func(): show_page(not showing_records))
	continue_button.pressed.connect(main.continue_to_preparation)
	get_viewport().size_changed.connect(_layout)
	show_page(false)
	overlay.hide()


func show_page(records: bool) -> void:
	if overlay.visible and showing_records != records:
		get_node("/root/GameAudio").play(&"confirm" if records else &"back")
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
	if main.last_run.duration > main.final_boss_time:
		stats.text = "Run time %s · night survived %s\n+%d energy earned" % [hud.format_time(main.last_run.duration), hud.format_time(main.last_run.survival), int(main.last_run.energy)]
	if main.last_run.get("victory", false):
		title.text = "Dawn has come"
		stats.text = "The Snuffer defeated\nClear time %s · night survived %s\n+%d energy earned" % [hud.format_time(main.last_run.duration), hud.format_time(main.last_run.survival), int(main.last_run.energy)]
	if main.last_run.get("boss_bonus", 0.0) > 0.0:
		stats.text += "\nIncludes %d energy from the Drencher" % int(main.last_run.boss_bonus)
	best.text = "%sBest: %s · %d energy available" % ["New personal best!\n" if main.last_run.new_best else "", hud.format_time(main.best_time), int(main.banked_energy)]
	if main.last_run.get("victory", false):
		best.text = "%sFastest clear: %s · %d energy available" % ["New clear record!\n" if main.last_run.new_best else "", hud.format_time(main.version_clears[main.game_version]), int(main.banked_energy)]
		if is_instance_valid(dawn_tween):
			dawn_tween.kill()
		overlay.color = Color(0.75, 0.53, 0.30, 0.22)
		dawn_tween = create_tween()
		dawn_tween.tween_property(overlay, "color", normal_overlay_color, 2.0)
	hud.leaderboard.reparent(content)
	hud.leaderboard.refresh()
	hud.scroll.hide()
	main.get_node("BuildController")._update_interface()
	show_page(false)
	overlay.show()
	continue_button.grab_focus()


func hide_results() -> void:
	if is_instance_valid(dawn_tween):
		dawn_tween.kill()
	overlay.color = normal_overlay_color
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
