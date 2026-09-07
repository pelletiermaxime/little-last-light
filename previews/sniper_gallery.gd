extends Node2D
## A save-free comparison scene. All six samples share one animation clock.

const Visual = preload("res://sniper_visual.gd")
const Style = preload("res://ui_style.gd")
const TITLES := ["Lenskeeper", "Needle of Dawn", "Watchlight"]
const SUBTITLES := ["A focused lantern", "A light spire", "A shuttered beacon"]
const DESCRIPTIONS := [
	"Curved brackets cradle a bright lens.\nA fine slit points toward the shot.",
	"Light climbs an anchored crystal.\nIts tip brightens as the shot returns.",
	"A narrow aperture slowly opens.\nThe shutters close after each shot.",
]
const INTERVAL: float = 4.5
const FLASH_DURATION: float = 0.12
var samples: Array[Node2D] = []
var clock: float = 3.0
var shot_remaining: float = 0.0
var playing: bool = true
var slow_motion: bool = false
var stage := Node2D.new()
var status: Label
var pause_button: Button


func _ready() -> void:
	add_child(stage)
	_label("THREE WAYS TO FOCUS THE LIGHT", Vector2(40, 28), 16, Color("#a4b7c3"))
	_label("Choose the sniper's silhouette", Vector2(40, 56), 32)
	_label("Same single-target shot. Same 4.5-second rhythm. Three visual treatments.", Vector2(40, 104), 17)
	for index in range(3):
		var x := 40.0 + index * 370.0
		var panel := Panel.new()
		panel.position = Vector2(x, 153)
		panel.size = Vector2(350, 444)
		panel.add_theme_stylebox_override("panel", Style.panel())
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(panel)
		_label("0%d  /  %s" % [index + 1, TITLES[index]], Vector2(x + 22, 171), 22)
		_label(SUBTITLES[index], Vector2(x + 22, 204), 16, Color("#a4b7c3"))
		_add_sample(index, Vector2(x + 175, 312), 4.0, false)
		_label("DETAIL  /  4×", Vector2(x + 22, 389), 13, Color("#a4b7c3"))
		_label("GAMEPLAY SIZE  /  1×", Vector2(x + 22, 427), 13, Color("#a4b7c3"))
		_add_sample(index, Vector2(x + 92, 481), 1.0, true)
		_label(DESCRIPTIONS[index], Vector2(x + 22, 536), 15)
	_button("Fire together  [Space]", Vector2(40, 617), fire_together)
	pause_button = _button("Pause  [P]", Vector2(277, 617), toggle_pause)
	var slow := CheckButton.new()
	slow.text = "Slow motion · ¼ speed"
	slow.position = Vector2(487, 617)
	slow.size = Vector2(230, 42)
	slow.toggled.connect(func(value: bool): slow_motion = value)
	stage.add_child(slow)
	status = _label("", Vector2(761, 627), 16, Color("#fff0cc"))
	_label("Existing defenses", Vector2(40, 699), 16, Color("#a4b7c3"))
	_reference("res://turret.tscn", Vector2(252, 710))
	_label("Basic light", Vector2(277, 698), 16)
	_reference("res://pulse_turret.tscn", Vector2(460, 710))
	_label("Slowing pulse", Vector2(485, 698), 16)
	_label("Visual study · no progress saved", Vector2(824, 699), 14, Color("#a4b7c3"))
	get_viewport().size_changed.connect(_fit)
	_fit()
	_update_samples()
	if "--capture-snipers" in OS.get_cmdline_user_args():
		_capture()


func _label(text: String, at: Vector2, size: int, color: Color = Color("#e8f1f1")) -> Label:
	var label := Style.label(text, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.position = at
	stage.add_child(label)
	return label


func _button(text: String, at: Vector2, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = Vector2(210, 42)
	button.pressed.connect(action)
	stage.add_child(button)
	return button


func _reference(path: String, at: Vector2) -> void:
	var reference: Node2D = load(path).instantiate()
	reference.position = at
	reference.attack_range = 0.0
	reference.process_mode = Node.PROCESS_MODE_DISABLED
	stage.add_child(reference)


func _add_sample(index: int, at: Vector2, zoom: float, with_shot: bool) -> void:
	var sample := Visual.new()
	sample.design = index
	sample.position = at
	sample.scale = Vector2.ONE * zoom
	sample.show_shot = with_shot
	stage.add_child(sample)
	samples.append(sample)
	if with_shot:
		var target := Node2D.new()
		target.position = at + sample.shot_endpoint
		stage.add_child(target)
		target.draw.connect(func():
			target.draw_circle(Vector2.ZERO, 10.0, Color("#826caa"))
			target.draw_circle(Vector2(-4, 3), 2.0, Color("#ffe0a3"))
			target.draw_circle(Vector2(-4, -3), 2.0, Color("#ffe0a3"))
		)
		# Keep the flash and its endpoint above the target body.
		sample.z_index = 1


func _fit() -> void:
	var available := get_viewport_rect().size
	stage.scale = Vector2.ONE * minf(available.x / 1152.0, available.y / 760.0)
	stage.position = (available - Vector2(1152, 760) * stage.scale) / 2.0


func _process(delta: float) -> void:
	if playing:
		var step := delta * (0.25 if slow_motion else 1.0)
		clock += step
		shot_remaining = maxf(0.0, shot_remaining - step)
		if clock >= INTERVAL:
			clock = fmod(clock, INTERVAL)
			shot_remaining = FLASH_DURATION
		_update_samples()


func _update_samples() -> void:
	for sample in samples:
		sample.charge = clampf(clock / INTERVAL, 0.0, 1.0)
		sample.flash = shot_remaining / FLASH_DURATION
		sample.queue_redraw()
	status.text = "%s · %s" % ["Playing" if playing else "Paused", "Firing" if shot_remaining > 0 else "Ready in %.1fs" % (INTERVAL - clock)]


func fire_together() -> void:
	clock = 0.0
	shot_remaining = FLASH_DURATION
	_update_samples()


func toggle_pause() -> void:
	playing = not playing
	pause_button.text = "Pause  [P]" if playing else "Resume  [P]"
	_update_samples()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			fire_together()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_P:
			toggle_pause()
			get_viewport().set_input_as_handled()


func _capture() -> void:
	if playing:
		toggle_pause()
	clock = INTERVAL
	_update_samples()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/lll-snipers-ready.png")
	fire_together()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/lll-snipers-firing.png")
	print("Captured sniper ready and firing states")
	get_tree().quit()
