extends "res://enemy.gd"

const TRAIL_SCRIPT = preload("res://water_trail.gd")
const TRAIL_SPACING: float = 24.0
const ARRIVAL_TIME: float = 3.0

var arrival_remaining: float = ARRIVAL_TIME
var trail: Node2D
var last_puddle: Vector2


func _ready() -> void:
	max_health = 700.0
	speed = 78.0
	turn_speed = PI / 6.0
	contact_distance = 44.0
	contact_damage_per_second = 20.0
	super._ready()
	add_to_group("bosses")
	trail = TRAIL_SCRIPT.new()
	trail.target = target
	add_child(trail)
	last_puddle = global_position


func _process(delta: float) -> void:
	if delta <= 0.0 or health <= 0.0 or is_queued_for_deletion():
		return
	if arrival_remaining > 0.0:
		var warning_step := minf(delta, arrival_remaining)
		arrival_remaining -= warning_step
		delta -= warning_step
		queue_redraw()
		if delta <= 0.0:
			return
	super._process(delta)
	if is_queued_for_deletion() or not is_instance_valid(trail) or trail.is_queued_for_deletion():
		return
	# Space puddles by distance so a stationary boss cannot stack a lethal pool.
	var distance := last_puddle.distance_to(global_position)
	if distance >= TRAIL_SPACING:
		var direction := last_puddle.direction_to(global_position)
		for index in range(mini(64, int(distance / TRAIL_SPACING))):
			last_puddle += direction * TRAIL_SPACING
			trail.leave_puddle(last_puddle)


func take_damage(amount: float) -> void:
	super.take_damage(amount)
	if health <= 0.0 and is_instance_valid(trail):
		trail.process_mode = Node.PROCESS_MODE_DISABLED
		trail.queue_free()


func _draw_body() -> void:
	body.draw_circle(Vector2.ZERO, 34, Color("#246780"))
	body.draw_circle(Vector2(-8, 0), 26, Color("#388fa3"))
	body.draw_circle(Vector2(-13, -10), 9, Color("#61b9c7"))
	# Broad mouth and pale eyes distinguish the water creature from basic enemies.
	body.draw_circle(Vector2(24, 0), 12, Color("#123744"))
	body.draw_circle(Vector2(15, -15), 5, Color("#e2f7bd"))
	body.draw_circle(Vector2(15, 15), 5, Color("#e2f7bd"))
	body.draw_circle(Vector2(17, -15), 2, Color("#123744"))
	body.draw_circle(Vector2(17, 15), 2, Color("#123744"))


func _draw() -> void:
	draw_rect(Rect2(-38, -47, 76, 5), Color("#193344"))
	draw_rect(Rect2(-38, -47, 76 * health / max_health, 5), Color("#82e2ec"))
	if arrival_remaining > 0:
		draw_arc(Vector2.ZERO, 46, 0, TAU, 48, Color("#9be8ff"), 3, true)
