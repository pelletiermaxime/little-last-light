extends Node2D

signal died

const BRIGHTNESS_NAMES: Array[String] = ["Low", "Medium", "High"]
const ENERGY_RATES: Array[float] = [0.6, 1.2, 2.4]
const LIGHT_SCALES: Array[float] = [1.0, 1.4, 1.9]
const MOVE_DEADZONE := 0.25

@export var move_speed: float = 220.0
@export var max_health: float = 25.0

var health: float
var running: bool = false
var hit_flash: float = 0.0
var projectile_grace_remaining: float = 0.0

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
	projectile_grace_remaining = maxf(0.0, projectile_grace_remaining - delta)
	elapsed += delta
	energy += current_energy_rate() * delta

	queue_redraw()


func current_energy_rate() -> float:
	return ENERGY_RATES[brightness] * get_parent().energy_multiplier()


func take_projectile_damage(amount: float) -> void:
	if not running or health <= 0.0 or amount <= 0.0 or projectile_grace_remaining > 0.0:
		return
	# Overlapping droplets cost one hit, with time to move out of the pattern.
	projectile_grace_remaining = 0.35
	take_damage(amount)


func take_damage(amount: float) -> void:
	if not running or health <= 0.0 or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	get_node("/root/GameAudio").play(&"damage")
	hit_flash = 0.15
	# The HUD samples health at 10 Hz. A crowd must not rebuild the entire UI
	# once per contact per frame; death still refreshes immediately via end_run.
	queue_redraw()
	if health <= 0.0:
		died.emit()


func _physics_process(delta: float) -> void:
	if not running:
		return
	# get_vector keeps diagonal movement the same speed as straight movement.
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down", MOVE_DEADZONE)
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
	if not running or level < 0 or level >= BRIGHTNESS_NAMES.size() or level == brightness:
		return
	brightness = level
	get_node("/root/GameAudio").play(&"brightness")
	_update_status()
	queue_redraw()


func _update_status() -> void:
	var hud := get_parent().get_node_or_null("GameHUD")
	if hud != null and hud.is_node_ready():
		hud.refresh()


func _draw() -> void:
	if running:
		draw_arc(Vector2.ZERO, 110.0, 0.0, TAU, 64, Color(1.0, 0.75, 0.3, 0.22), 1.0, true)
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
