extends Node2D

signal died

const BRIGHTNESS_NAMES: Array[String] = ["Low", "Medium", "High"]
const ENERGY_RATES: Array[float] = [1.0, 3.0, 6.0]
const LIGHT_SCALES: Array[float] = [1.0, 1.4, 1.9]

@export var move_speed: float = 220.0
@export var max_health: float = 100.0

var health: float
var running: bool = false
var hit_flash: float = 0.0

var elapsed: float = 0.0
var brightness: int = 0
var energy: float = 0.0

var status_label: Label


func _ready() -> void:
	health = max_health
	get_viewport().size_changed.connect(_keep_inside_viewport)
	_center_in_viewport()

	# A CanvasLayer keeps the interface separate from world positioning.
	var hud := CanvasLayer.new()
	hud.layer = 3
	add_child(hud)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(status_label)
	_layout_status()
	get_viewport().size_changed.connect(_layout_status)

	_update_status()


func _process(delta: float) -> void:
	if not running:
		return
	hit_flash = maxf(0.0, hit_flash - delta)
	elapsed += delta
	energy += ENERGY_RATES[brightness] * delta

	_update_status()
	queue_redraw()


func take_damage(amount: float) -> void:
	if not running or health <= 0.0 or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	hit_flash = 0.15
	_update_status()
	queue_redraw()
	if health <= 0.0:
		died.emit()


func _physics_process(delta: float) -> void:
	if not running:
		return
	# get_vector keeps diagonal movement the same speed as straight movement.
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	position += direction * move_speed * delta
	_keep_inside_viewport()


func _keep_inside_viewport() -> void:
	var screen_size: Vector2 = get_parent().get_arena_rect().size
	var margin := Vector2.ONE * 16.0
	position = position.clamp(margin, (screen_size - margin).max(margin))


func _unhandled_key_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_SPACE:
			brightness = (brightness + 1) % BRIGHTNESS_NAMES.size()
			_update_status()
			get_viewport().set_input_as_handled()


func _center_in_viewport() -> void:
	position = get_parent().get_arena_rect().get_center()


func _layout_status() -> void:
	status_label.position = Vector2(get_parent().get_arena_rect().end.x + 20.0, 24.0)
	status_label.size = Vector2(280, 220)


func _update_status() -> void:
	if not running:
		status_label.text = "PREPARATION\nHealth restored on Start run"
		return
	status_label.text = (
		"Health: %d / %d\nTime: %ds · Brightness: %s\nThis run: %d energy\n(+%.0f / second)\n\nWASD / Arrows: move\nSpace: brightness"
		% [
			int(ceil(health)),
			int(max_health),
			int(elapsed),
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
	if hit_flash > 0.0:
		draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 32, Color("#ff6b6b"), 3.0, true)
