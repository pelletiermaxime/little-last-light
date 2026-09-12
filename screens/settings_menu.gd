extends Control

signal closed

var touch_layout := false

@onready var volume_button: Button = $Center/Panel/Padding/Content/VolumeButton
@onready var sound_button: Button = $Center/Panel/Padding/Content/SoundButton
@onready var display_mode_button: Button = $Center/Panel/Padding/Content/DisplayModeButton
@onready var fps_button: Button = $Center/Panel/Padding/Content/FPSButton
@onready var vsync_button: Button = $Center/Panel/Padding/Content/VSyncButton

func _ready() -> void:
	if OS.has_feature("web"):
		$Center/Panel/Padding/Content/DisplayNote.text = "Display mode and VSync follow your browser. FPS is also limited by your display's refresh rate."
	GameAudio.settings_changed.connect(_refresh_audio_labels)
	DisplaySettings.changed.connect(_refresh_display_labels)
	resized.connect(_fit_content)
	$Center/Panel.minimum_size_changed.connect(_fit_content.call_deferred)
	refresh()
	_fit_content.call_deferred()
	if is_visible_in_tree():
		volume_button.grab_focus()

func refresh() -> void:
	_refresh_audio_labels()
	_refresh_display_labels()
	_fit_content.call_deferred()

func _fit_content() -> void:
	# Keep Back outside the scaled card so it stays thumb-sized on every page.
	var top_inset := 80.0
	var touch := get_node_or_null("../../TouchLayer/TouchControls")
	if touch != null and touch.enabled and not touch_layout:
		_enable_touch_layout()
	if touch_layout:
		$Center.position = Vector2(maxf(16.0, (size.x - 660.0) / 2.0), top_inset)
		$Center.size = Vector2(minf(660.0, size.x - 32.0), maxf(1.0, size.y - top_inset - 16.0))
		return
	var minimum: Vector2 = $Center/Panel.get_combined_minimum_size()
	var available := (size - Vector2(32, top_inset + 16)).max(Vector2.ONE)
	var factor := minf(1.0, minf(available.x / minimum.x, available.y / minimum.y))
	$Center.scale = Vector2.ONE * factor
	$Center.position = Vector2(0, top_inset)
	$Center.size = Vector2(size.x, maxf(1.0, size.y - top_inset - 16)) / factor


func _enable_touch_layout() -> void:
	touch_layout = true
	# Retain the existing node paths and signal connections when replacing the
	# desktop centering container with a swipeable phone viewport.
	var panel := $Center/Panel
	$Center.remove_child(panel)
	$Center.free()
	var scroller := ScrollContainer.new()
	scroller.name = "Center"
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroller.follow_focus = true
	add_child(scroller)
	move_child(scroller, 1)
	scroller.add_child(panel)
	panel.custom_minimum_size.x = 0
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	for control in panel.find_children("*", "Control", true, false):
		if control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			control.mouse_filter = Control.MOUSE_FILTER_PASS
	for button in panel.find_children("*", "Button", true, false):
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _on_back_button_pressed() -> void:
	closed.emit()

func _on_volume_button_pressed() -> void:
	GameAudio.set_volume(fmod(GameAudio.volume + 0.25, 1.25))
	_refresh_audio_labels()
	GameAudio.play(&"confirm")


func _on_sound_button_pressed() -> void:
	GameAudio.set_muted(not GameAudio.muted)
	_refresh_audio_labels()
	GameAudio.play(&"confirm")

func _refresh_audio_labels() -> void:
	volume_button.text = "Volume: %d%%" % roundi(GameAudio.volume * 100)
	sound_button.text = "Sound: Off" if GameAudio.muted else "Sound: On"

func _refresh_display_labels() -> void:
	var desktop := DisplaySettings.desktop_controls()
	display_mode_button.disabled = not desktop
	vsync_button.disabled = not desktop
	display_mode_button.text = "Display mode: %s" % DisplaySettings.display_mode if desktop else "Display mode: Browser controlled"
	vsync_button.text = ("VSync: On" if DisplaySettings.vsync else "VSync: Off") if desktop else "VSync: Browser controlled"
	var limit := DisplaySettings.fps_limit
	fps_button.text = "FPS limit: Unlimited" if limit == 0 else "FPS limit: %d" % limit

func _on_display_mode_button_pressed() -> void:
	var modes := DisplaySettings.DISPLAY_MODES
	var next_index := (modes.find(DisplaySettings.display_mode) + 1) % modes.size()
	DisplaySettings.set_display_mode(modes[next_index])
	_refresh_display_labels()
	GameAudio.play(&"confirm")

func _on_fps_button_pressed() -> void:
	var limits := DisplaySettings.FPS_LIMITS
	var next_index := (limits.find(DisplaySettings.fps_limit) + 1) % limits.size()
	DisplaySettings.set_fps_limit(limits[next_index])
	_refresh_display_labels()
	GameAudio.play(&"confirm")

func _on_vsync_button_pressed() -> void:
	DisplaySettings.set_vsync(not DisplaySettings.vsync)
	_refresh_display_labels()
	GameAudio.play(&"confirm")
