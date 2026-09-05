extends Node2D

const BRIGHTNESS_NAMES: Array[String] = ["Low", "Medium", "High"]
const ENERGY_RATES: Array[float] = [1.0, 3.0, 6.0]
const LIGHT_SCALES: Array[float] = [1.0, 1.4, 1.9]

@export var move_speed: float = 220.0

var elapsed: float = 0.0
var brightness: int = 0
var energy: float = 0.0

var status_label: Label


func _ready() -> void:
	get_viewport().size_changed.connect(_keep_inside_viewport)
	_center_in_viewport()

	# A CanvasLayer keeps the interface separate from world positioning.
	var hud := CanvasLayer.new()
	add_child(hud)

	status_label = Label.new()
	status_label.position = Vector2(24.0, 24.0)
	status_label.add_theme_font_size_override("font_size", 20)
	hud.add_child(status_label)

	_update_status()


func _process(delta: float) -> void:
	elapsed += delta
	energy += ENERGY_RATES[brightness] * delta

	_update_status()
	queue_redraw()


func _physics_process(delta: float) -> void:
	# get_vector keeps diagonal movement the same speed as straight movement.
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	position += direction * move_speed * delta
	_keep_inside_viewport()


func _keep_inside_viewport() -> void:
	var screen_size := get_viewport_rect().size
	var margin := Vector2.ONE * 16.0
	position = position.clamp(margin, (screen_size - margin).max(margin))


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_SPACE:
			brightness = (brightness + 1) % BRIGHTNESS_NAMES.size()
			_update_status()
			get_viewport().set_input_as_handled()


func _center_in_viewport() -> void:
	position = get_viewport_rect().size / 2.0


func _update_status() -> void:
	status_label.text = (
		"Brightness: %s\nEnergy: %d  (+%.0f / second)\n\nWASD / Arrows: move lantern\nSpace: change brightness"
		% [
			BRIGHTNESS_NAMES[brightness],
			int(energy),
			ENERGY_RATES[brightness],
		]
	)


func _draw() -> void:
	var pulse: float = 1.0 + sin(elapsed * 2.0) * 0.08
	var glow_size: float = pulse * LIGHT_SCALES[brightness]

	draw_circle(Vector2.ZERO, 70.0 * glow_size, Color(1.0, 0.65, 0.2, 0.04))
	draw_circle(Vector2.ZERO, 48.0 * glow_size, Color(1.0, 0.65, 0.2, 0.08))
	draw_circle(Vector2.ZERO, 30.0 * glow_size, Color(1.0, 0.65, 0.2, 0.16))

	draw_circle(Vector2.ZERO, 12.0 * pulse, Color("#ffbd59"))
	draw_circle(Vector2.ZERO, 6.0 * pulse, Color("#fff2cf"))
