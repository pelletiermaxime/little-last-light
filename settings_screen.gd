extends CanvasLayer

const STYLE = preload("res://ui_style.gd")
var overlay: ColorRect
var card: PanelContainer
var volume_button: Button
var mute_button: Button
var display_mode_button: Button
var fps_button: Button
var vsync_button: Button
var done_button: Button
var return_focus: Control
var audio: Node
var display: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	audio = get_node("/root/GameAudio")
	display = get_node("/root/DisplaySettings")
	overlay = ColorRect.new()
	overlay.color = Color(0.025, 0.04, 0.06, 0.96)
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", STYLE.panel())
	overlay.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	card.add_child(column)
	column.add_child(STYLE.label("Settings", 28, Color("#ffcf7a")))
	column.add_child(STYLE.label("Audio", 18, Color("#a6bdc7")))
	volume_button = _button(column, func():
		audio.set_volume(fmod(audio.volume + 0.25, 1.25))
		audio.play(&"confirm")
	)
	mute_button = _button(column, func():
		audio.set_muted(not audio.muted)
		audio.play(&"confirm")
	)
	column.add_child(STYLE.label("Display", 18, Color("#a6bdc7")))
	display_mode_button = _button(column, func():
		var choices: Array[String] = display.DISPLAY_MODES
		display.set_display_mode(choices[(choices.find(display.display_mode) + 1) % choices.size()])
		audio.play(&"confirm")
	)
	fps_button = _button(column, func():
		var choices: Array[int] = display.FPS_LIMITS
		display.set_fps_limit(choices[(choices.find(display.fps_limit) + 1) % choices.size()])
		audio.play(&"confirm")
	)
	vsync_button = _button(column, func():
		display.set_vsync(not display.vsync)
		audio.play(&"confirm")
	)
	var note := "Display mode and VSync follow your browser. FPS is also limited by your display's refresh rate." if OS.has_feature("web") else "VSync may cap FPS at your display's refresh rate."
	column.add_child(STYLE.label(note, 14, Color("#a6bdc7")))
	done_button = _button(column, close)
	done_button.text = "Done"
	audio.settings_changed.connect(refresh)
	display.changed.connect(refresh)
	get_viewport().size_changed.connect(_layout)
	refresh()
	overlay.hide()

func _button(column: VBoxContainer, callback: Callable) -> Button:
	var button := Button.new()
	STYLE.button(button)
	column.add_child(button)
	button.pressed.connect(callback)
	return button

func is_open() -> bool:
	return is_instance_valid(overlay) and overlay.visible

func open(from: Control) -> void:
	return_focus = from
	refresh()
	overlay.show()
	volume_button.grab_focus()
	audio.play(&"confirm")
	call_deferred("_layout")

func close() -> void:
	overlay.hide()
	if is_instance_valid(return_focus) and return_focus.is_visible_in_tree():
		return_focus.grab_focus()
	audio.play(&"back")

func refresh() -> void:
	volume_button.text = "Volume: %d%%" % roundi(audio.volume * 100)
	mute_button.text = "Sound: Off" if audio.muted else "Sound: On"
	fps_button.text = "FPS limit: %s" % ("Unlimited" if display.fps_limit == 0 else str(display.fps_limit))
	display_mode_button.text = "Display mode: %s" % display.display_mode
	vsync_button.text = "VSync: On" if display.vsync else "VSync: Off"
	display_mode_button.disabled = not display.desktop_controls()
	vsync_button.disabled = not display.desktop_controls()
	if OS.has_feature("web"):
		display_mode_button.text = "Display mode: Browser window"
		vsync_button.text = "VSync: Browser controlled"
	call_deferred("_layout")

func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	card.size = Vector2(minf(440, size.x - 32), 0)
	STYLE.fit_card(card, size)

func _unhandled_input(_event: InputEvent) -> void:
	if is_open():
		get_viewport().set_input_as_handled()
