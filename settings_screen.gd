extends CanvasLayer

@onready var menu = $SettingsMenu
@onready var volume_button: Button = menu.volume_button
@onready var mute_button: Button = menu.sound_button
@onready var display_mode_button: Button = menu.display_mode_button
@onready var fps_button: Button = menu.fps_button
@onready var vsync_button: Button = menu.vsync_button
@onready var done_button: Button = menu.get_node("Center/Panel/Padding/Content/DoneButton")
var return_focus: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	menu.hide()

func is_open() -> bool:
	return menu.visible

func open(from: Control) -> void:
	return_focus = from
	menu.refresh()
	menu.show()
	volume_button.grab_focus()
	GameAudio.play(&"confirm")

func close() -> void:
	menu.hide()
	if is_instance_valid(return_focus) and return_focus.is_visible_in_tree():
		return_focus.grab_focus()
	GameAudio.play(&"back")

func _unhandled_input(_event: InputEvent) -> void:
	if is_open():
		get_viewport().set_input_as_handled()

func _on_settings_menu_closed() -> void:
	close()
