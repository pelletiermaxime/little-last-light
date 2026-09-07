extends CanvasLayer

@onready var menu = $SettingsMenu
@onready var volume_button: Button = menu.volume_button
@onready var mute_button: Button = menu.sound_button
@onready var display_mode_button: Button = menu.display_mode_button
@onready var fps_button: Button = menu.fps_button
@onready var vsync_button: Button = menu.vsync_button
@onready var done_button: Button = menu.get_node("Center/Panel/Padding/Content/DoneButton")
@onready var reset_button: Button = menu.get_node("Center/Panel/Padding/Content/ResetProgressButton")
@onready var reset_confirmation: VBoxContainer = menu.get_node("Center/Panel/Padding/Content/ResetConfirmation")
@onready var reset_cancel: Button = reset_confirmation.get_node("CancelButton")
@onready var reset_confirm: Button = reset_confirmation.get_node("ConfirmButton")
@onready var reset_warning: Label = reset_confirmation.get_node("Warning")
@onready var reset_warning_text: String = reset_warning.text
var return_focus: Control
var reset_pending := false
var assistance_open := false
@onready var assistance_button: Button = menu.get_node("Center/Panel/Padding/Content/AssistanceButton")
@onready var assistance_page: VBoxContainer = menu.get_node("Center/Panel/Padding/Content/AssistancePage")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	menu.hide()
	reset_button.pressed.connect(_ask_reset)
	reset_cancel.pressed.connect(_cancel_reset)
	reset_confirm.pressed.connect(_confirm_reset)
	assistance_button.pressed.connect(func(): _show_assistance(true))
	assistance_page.get_node("BackButton").pressed.connect(func(): _show_assistance(false))
	for pair in [["CheapUpgrades", "cheap_upgrades"], ["ShortNight", "short_night"], ["SlowEnemies", "slow_enemies"]]:
		assistance_page.get_node(pair[0]).toggled.connect(func(enabled: bool):
			get_parent().set_assist(pair[1], enabled)
			_refresh_assistance()
		)


func _show_assistance(opened: bool) -> void:
	assistance_open = opened
	_refresh_reset_view()
	_refresh_assistance()
	if opened:
		if get_parent().phase == get_parent().Phase.PREPARATION:
			assistance_page.get_node("CheapUpgrades").grab_focus()
		else:
			assistance_page.get_node("BackButton").grab_focus()
	else:
		assistance_button.grab_focus()


func _refresh_assistance() -> void:
	var main = get_parent()
	for pair in [["CheapUpgrades", "cheap_upgrades"], ["ShortNight", "short_night"], ["SlowEnemies", "slow_enemies"]]:
		var button: CheckButton = assistance_page.get_node(pair[0])
		button.set_pressed_no_signal(main.assists[pair[1]])
		button.disabled = main.phase != main.Phase.PREPARATION
	assistance_page.get_node("Status").text = "Eligible progress · assists off" if main.leaderboard_eligible() else "Assisted progress · leaderboards disabled"
	if main.phase != main.Phase.PREPARATION:
		assistance_page.get_node("Status").text += "\nSettings are locked until preparation."
	if not main.save_message.is_empty():
		assistance_page.get_node("Status").text += "\n" + main.save_message

func is_open() -> bool:
	return menu.visible

func open(from: Control) -> void:
	return_focus = from
	menu.refresh()
	menu.show()
	_refresh_reset_view()
	volume_button.grab_focus()
	GameAudio.play(&"confirm")

func close() -> void:
	if assistance_open:
		_show_assistance(false)
		return
	if reset_pending:
		_cancel_reset()
		return
	menu.hide()
	if is_instance_valid(return_focus) and return_focus.is_visible_in_tree():
		return_focus.grab_focus()
	GameAudio.play(&"back")


func _refresh_reset_view() -> void:
	for child in menu.get_node("Center/Panel/Padding/Content").get_children():
		child.visible = not reset_pending and not assistance_open
	reset_confirmation.visible = reset_pending
	assistance_page.visible = assistance_open
	assistance_button.text = "Assistance · assisted progress" if not get_parent().leaderboard_eligible() else "Assistance…"
	reset_button.visible = not reset_pending and not assistance_open and get_parent().phase == get_parent().Phase.PREPARATION
	menu._fit_content.call_deferred()


func _ask_reset() -> void:
	if not is_open() or get_parent().phase != get_parent().Phase.PREPARATION:
		return
	reset_pending = true
	reset_warning.text = reset_warning_text
	_refresh_reset_view()
	reset_cancel.grab_focus()
	GameAudio.play(&"confirm")


func _cancel_reset() -> void:
	reset_pending = false
	_refresh_reset_view()
	reset_button.grab_focus()
	GameAudio.play(&"back")


func _confirm_reset() -> void:
	if not reset_pending:
		return
	if get_parent().reset_progress():
		reset_confirm.disabled = true
		reset_cancel.disabled = true
	else:
		reset_warning.text = "Could not reset progress. Your current progress is unchanged. Check that the save location is writable and try again."

func _unhandled_input(_event: InputEvent) -> void:
	if is_open():
		get_viewport().set_input_as_handled()

func _on_settings_menu_closed() -> void:
	close()
