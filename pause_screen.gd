extends CanvasLayer

var main: Node2D
var overlay: ColorRect
var resume_button: Button
var end_run_button: Button
var summary: Label
var keys: Label
var settings_button: Button


func _ready() -> void:
	# This one branch must keep receiving input while SceneTree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	main = get_parent()
	overlay = ColorRect.new()
	overlay.color = Color(0.025, 0.04, 0.06, 0.85)
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Block clicks from reaching the brightness buttons underneath.
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(360, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#18242e")
	style.set_corner_radius_all(12)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	card.add_theme_stylebox_override("panel", style)
	center.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	card.add_child(column)
	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("#ffcf7a"))
	column.add_child(title)
	summary = Label.new()
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.add_theme_font_size_override("font_size", 18)
	column.add_child(summary)
	var note := Label.new()
	note.text = "Take your time. The run is frozen."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", Color("#9aaebc"))
	column.add_child(note)
	resume_button = Button.new()
	resume_button.text = "Resume"
	resume_button.custom_minimum_size.y = 48
	resume_button.pressed.connect(resume)
	column.add_child(resume_button)
	end_run_button = Button.new()
	end_run_button.text = "End Run"
	end_run_button.custom_minimum_size.y = 48
	end_run_button.tooltip_text = "Keep your earned energy and return to turret preparation."
	end_run_button.pressed.connect(end_run)
	column.add_child(end_run_button)
	var end_note := Label.new()
	end_note.text = "End Run keeps all energy earned."
	end_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_note.add_theme_font_size_override("font_size", 14)
	end_note.add_theme_color_override("font_color", Color("#9aaebc"))
	column.add_child(end_note)
	settings_button = Button.new()
	settings_button.text = "Settings"
	settings_button.custom_minimum_size.y = 44
	settings_button.pressed.connect(func(): main.get_node("SettingsScreen").open(settings_button))
	column.add_child(settings_button)
	keys = Label.new()
	keys.text = "Esc / P to resume"
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keys.add_theme_font_size_override("font_size", 14)
	keys.add_theme_color_override("font_color", Color("#9aaebc"))
	column.add_child(keys)
	overlay.hide()


func _input(event: InputEvent) -> void:
	if main.phase != main.Phase.RUNNING or event.is_echo():
		return
	if event.is_action_pressed("pause_run"):
		if get_tree().paused:
			resume()
		else:
			pause()
		get_viewport().set_input_as_handled()
	elif get_tree().paused and event.is_action_pressed("cancel_placement"):
		resume()
		get_viewport().set_input_as_handled()


func pause() -> void:
	if main.phase != main.Phase.RUNNING:
		return
	get_node("/root/GameAudio").stop_combat()
	get_node("/root/GameAudio").play(&"confirm")
	var lantern = main.get_node("Lantern")
	main.get_node("GameHUD").refresh()
	summary.text = "%s survived · %d energy earned" % [main.get_node("GameHUD").format_time(lantern.elapsed), int(lantern.energy)]
	get_tree().paused = true
	overlay.show()
	resume_button.grab_focus()


func resume() -> void:
	if overlay.visible:
		get_node("/root/GameAudio").play(&"back")
	get_tree().paused = false
	overlay.hide()
	resume_button.release_focus()
	end_run_button.release_focus()


func end_run() -> void:
	if not get_tree().paused or main.phase != main.Phase.RUNNING:
		return
	# Use the same banking, cleanup, and saving path as death.
	main.end_run(true)
	resume()
