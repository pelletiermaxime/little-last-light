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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	menu.hide()
	reset_button.pressed.connect(_ask_reset)
	reset_cancel.pressed.connect(_cancel_reset)
	reset_confirm.pressed.connect(_confirm_reset)

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
	if reset_pending:
		_cancel_reset()
		return
	menu.hide()
	if is_instance_valid(return_focus) and return_focus.is_visible_in_tree():
		return_focus.grab_focus()
	GameAudio.play(&"back")


func _refresh_reset_view() -> void:
	for child in menu.get_node("Center/Panel/Padding/Content").get_children():
		child.visible = not reset_pending
	reset_confirmation.visible = reset_pending
	reset_button.visible = not reset_pending and get_parent().phase == get_parent().Phase.PREPARATION
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
