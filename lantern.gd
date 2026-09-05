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



func _ready() -> void:
	health = max_health
	get_viewport().size_changed.connect(_keep_inside_viewport)
	_center_in_viewport()



func _process(delta: float) -> void:
	# Let the last hit fade after death instead of freezing a red flash in prep.
	if hit_flash > 0.0:
		hit_flash = maxf(0.0, hit_flash - delta)
		queue_redraw()
	if not running:
		return
	elapsed += delta
	energy += ENERGY_RATES[brightness] * delta

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


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event.is_action_pressed("cycle_brightness"):
		set_brightness((brightness + 1) % BRIGHTNESS_NAMES.size())
		get_viewport().set_input_as_handled()


func _center_in_viewport() -> void:
	position = get_parent().get_arena_rect().get_center()


func set_brightness(level: int) -> void:
	if not running or level < 0 or level >= BRIGHTNESS_NAMES.size():
		return
	brightness = level
	_update_status()
	queue_redraw()


func _update_status() -> void:
	var hud := get_parent().get_node_or_null("GameHUD")
	if hud != null and hud.is_node_ready():
		hud.refresh()


func _draw() -> void:
	var pulse: float = 1.0 + sin(elapsed * 2.0) * 0.08
	var glow_size: float = pulse * LIGHT_SCALES[brightness]

	draw_circle(Vector2.ZERO, 70.0 * glow_size, Color(1.0, 0.65, 0.2, 0.04))
	draw_circle(Vector2.ZERO, 48.0 * glow_size, Color(1.0, 0.65, 0.2, 0.08))
	draw_circle(Vector2.ZERO, 30.0 * glow_size, Color(1.0, 0.65, 0.2, 0.16))

	draw_circle(Vector2.ZERO, 12.0 * pulse, Color("#ffbd59"))
	draw_circle(Vector2.ZERO, 6.0 * pulse, Color("#fff2cf"))
	# One, two, or three rays make brightness readable without relying on color.
	for index in range(brightness + 1):
		var angle := -PI / 2.0 + (index - brightness / 2.0) * 0.45
		draw_line(Vector2.from_angle(angle) * 19.0, Vector2.from_angle(angle) * 25.0, Color("#ffe0a0"), 2.0, true)
	if hit_flash > 0.0:
		draw_circle(Vector2.ZERO, 14.0, Color(1.0, 0.35, 0.3, 0.65))
		draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 32, Color("#ff6b6b"), 3.0, true)
