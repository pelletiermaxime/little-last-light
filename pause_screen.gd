extends CanvasLayer

var main: Node2D
var overlay: ColorRect
var resume_button: Button
var end_run_button: Button
var summary: Label
var keys: Label
var settings_button: Button


func _ready() -> void:
	show()
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	main = get_parent()
	overlay = $Overlay
	resume_button = $Overlay/Card/Content/ResumeButton
	end_run_button = $Overlay/Card/Content/EndRunButton
	settings_button = $Overlay/Card/Content/SettingsButton
	summary = $Overlay/Card/Content/Summary
	keys = $Overlay/Card/Content/Keys
	resume_button.pressed.connect(resume)
	end_run_button.pressed.connect(end_run)
	settings_button.pressed.connect(func(): main.get_node("SettingsScreen").open(settings_button))
	get_viewport().size_changed.connect(_layout)
	# Wrapped labels settle after container layout; refit when their height changes.
	$Overlay/Card.minimum_size_changed.connect(_layout.call_deferred)
	_layout.call_deferred()
	overlay.hide()

func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	$Overlay/Card.size = Vector2(minf(360, size.x - 32), 0)
	preload("res://ui_style.gd").fit_card($Overlay/Card, size)


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
	_layout.call_deferred()
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
