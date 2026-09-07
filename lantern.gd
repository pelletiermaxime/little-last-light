extends Node2D

signal died

const BRIGHTNESS_NAMES: Array[String] = ["Low", "Medium", "High"]
const ENERGY_RATES: Array[float] = [1.0, 3.0, 6.0]
const LIGHT_SCALES: Array[float] = [1.0, 1.4, 1.9]
const WARD_FORM_SECONDS := 1.25
const WARD_CAPACITY := 8.0
const WARD_RECHARGE_DELAY := 3.0
const WARD_RECHARGE_RATE := 4.0
const MOVE_DEADZONE := 0.25

@export var move_speed: float = 220.0
@export var max_health: float = 25.0

var health: float
var running: bool = false
var hit_flash: float = 0.0

var elapsed: float = 0.0
var brightness: int = 0
var energy: float = 0.0
var ward_charge := 0.0
var ward_settle_time := 0.0
var ward_damage_delay := 0.0
var ward_broken := false
var ward_flash := 0.0


func reset_ward() -> void:
	ward_charge = 0.0
	ward_settle_time = 0.0
	ward_damage_delay = 0.0
	ward_broken = false
	ward_flash = 0.0
	queue_redraw()


func ward_active() -> bool:
	return running and ward_settle_time >= WARD_FORM_SECONDS and ward_charge > 0.0


func ward_status() -> String:
	if ward_settle_time == 0.0:
		return "Stand still to form ward"
	if ward_settle_time < WARD_FORM_SECONDS:
		return "Ward forming"
	if ward_broken:
		return "Ward broken · avoid damage"
	return "Ward %d / %d" % [int(ceil(ward_charge)), int(WARD_CAPACITY)]


func update_ward(delta: float, moving: bool) -> void:
	if not running or get_tree().paused:
		return
	ward_flash = maxf(0.0, ward_flash - delta)
	var previous_delay := ward_damage_delay
	ward_damage_delay = maxf(0.0, ward_damage_delay - delta)
	if moving:
		# Removing protection also discards its reserve. Repeated stops never refill it.
		ward_charge = 0.0
		ward_settle_time = 0.0
		ward_broken = false
	else:
		var formation_remaining := maxf(0.0, WARD_FORM_SECONDS - ward_settle_time)
		ward_settle_time = minf(WARD_FORM_SECONDS, ward_settle_time + delta)
		var recharge_time := maxf(0.0, delta - maxf(formation_remaining, previous_delay))
		ward_charge = minf(WARD_CAPACITY, ward_charge + recharge_time * WARD_RECHARGE_RATE)
		if ward_charge > 0.0:
			ward_broken = false
	queue_redraw()



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
	ward_damage_delay = WARD_RECHARGE_DELAY
	if ward_active():
		var absorbed := minf(amount, ward_charge)
		ward_charge -= absorbed
		amount -= absorbed
		ward_flash = 0.2
		ward_broken = ward_charge <= 0.0
		queue_redraw()
		if amount <= 0.0:
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
	# Use intent, including pushing into an arena edge; deadzone drift cannot move us.
	update_ward(delta, not direction.is_zero_approx())
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
	if running and ward_settle_time > 0.0:
		var forming := ward_settle_time < WARD_FORM_SECONDS
		var fraction := ward_settle_time / WARD_FORM_SECONDS if forming else ward_charge / WARD_CAPACITY
		var tint := Color("#a8e5df") if not ward_broken else Color("#ff806e")
		if ward_flash > 0.0:
			tint = Color.WHITE
		if forming or ward_broken:
			for index in range(8):
				draw_arc(Vector2.ZERO, 25.0, index * TAU / 8, (index + 0.6) * TAU / 8, 8, tint, 1.0, true)
		else:
			draw_arc(Vector2.ZERO, 25.0, 0, TAU, 48, Color(0.66, 0.9, 0.87, 0.2), 1.0, true)
		if fraction > 0.0:
			draw_arc(Vector2.ZERO, 25.0, -PI / 2, -PI / 2 + TAU * fraction, 48, tint, 2.0, true)
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
