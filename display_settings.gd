extends Node

signal changed
const FPS_LIMITS: Array[int] = [60, 100, 0]
const DISPLAY_MODES: Array[String] = ["Fullscreen", "Borderless fullscreen", "Windowed"]
const WINDOW_MODES: Array[int] = [DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN, DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_WINDOWED]
var fps_limit := 0
var vsync := true
var display_mode := "Windowed"
var windowed_size := Vector2i.ZERO
var windowed_maximized := false
var settings_path := "user://display-settings.cfg"
var resize_timer: Timer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	# The root Window applies its initial project settings as it enters the tree.
	# Restore after that initialization, before listening for user resizing.
	call_deferred("_restore_window")

func _restore_window() -> void:
	apply()
	if desktop_controls():
		resize_timer = Timer.new()
		resize_timer.one_shot = true
		resize_timer.wait_time = 0.4
		add_child(resize_timer)
		resize_timer.timeout.connect(remember_window_size)
		get_window().size_changed.connect(func(): resize_timer.start())

func remember_window_size() -> void:
	if desktop_controls() and _capture_window_state(get_window().mode, get_window().size):
		save_settings()

func _capture_window_state(mode: int, size: Vector2i) -> bool:
	# Maximized dimensions must not replace the size used when unmaximizing.
	# Fullscreen and minimized windows retain the last normal window state.
	if mode not in [Window.MODE_WINDOWED, Window.MODE_MAXIMIZED]:
		return false
	var maximized := mode == Window.MODE_MAXIMIZED
	var state_changed := maximized != windowed_maximized
	windowed_maximized = maximized
	if not maximized and size != windowed_size:
		windowed_size = size
		state_changed = true
	return state_changed

func fitted_window_size(available: Vector2i) -> Vector2i:
	var preferred := windowed_size
	if preferred.x <= 0 or preferred.y <= 0:
		preferred = Vector2i(Vector2(available) * 0.85)
	return preferred.min((available - Vector2i(32, 64)).max(Vector2i.ONE)).max(Vector2i.ONE)

func desktop_controls() -> bool:
	return not OS.has_feature("web") and DisplayServer.get_name() != "headless"

func set_fps_limit(value: int) -> void:
	if value not in FPS_LIMITS:
		return
	fps_limit = value
	Engine.max_fps = value
	save_settings()
	changed.emit()

func set_vsync(value: bool) -> void:
	vsync = value
	if desktop_controls():
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	save_settings()
	changed.emit()

func set_display_mode(value: String) -> void:
	if value not in DISPLAY_MODES:
		return
	if desktop_controls():
		_capture_window_state(get_window().mode, get_window().size)
	display_mode = value
	_apply_display_mode()
	save_settings()
	changed.emit()

func apply() -> void:
	Engine.max_fps = fps_limit
	if desktop_controls():
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
		_apply_display_mode()
	changed.emit()

func _apply_display_mode() -> void:
	if not desktop_controls():
		return
	_apply_window(get_window(), DisplayServer.screen_get_usable_rect())

func _apply_window(window: Window, available: Rect2i) -> void:
	# Use Window properties so later Godot updates cannot restore stale geometry.
	window.mode = WINDOW_MODES[DISPLAY_MODES.find(display_mode)]
	if display_mode == "Windowed":
		windowed_size = fitted_window_size(available.size)
		window.borderless = false
		window.size = windowed_size
		window.position = available.position + (available.size - windowed_size) / 2
		if windowed_maximized:
			window.mode = Window.MODE_MAXIMIZED

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return
	var saved_fps := int(config.get_value("display", "fps_limit", 0))
	fps_limit = saved_fps if saved_fps in FPS_LIMITS else 0
	vsync = bool(config.get_value("display", "vsync", true))
	var saved_mode := str(config.get_value("display", "mode", "Windowed"))
	display_mode = saved_mode if saved_mode in DISPLAY_MODES else "Windowed"
	windowed_size = config.get_value("display", "windowed_size", Vector2i.ZERO)
	windowed_maximized = bool(config.get_value("display", "windowed_maximized", false))
	# Replace the old fixed default once; keep previously chosen custom sizes.
	if not config.has_section_key("display", "window_size_version") and windowed_size == Vector2i(1280, 720):
		windowed_size = Vector2i.ZERO

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "fps_limit", fps_limit)
	config.set_value("display", "vsync", vsync)
	config.set_value("display", "mode", display_mode)
	config.set_value("display", "windowed_size", windowed_size)
	config.set_value("display", "windowed_maximized", windowed_maximized)
	config.set_value("display", "window_size_version", 1)
	var error := config.save(settings_path)
	if error != OK:
		push_warning("Could not save display preferences: %s" % error_string(error))
