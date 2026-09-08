extends Node2D

const LIFETIME: float = 8.0
const WARNING_TIME: float = 0.6
const RADIUS: float = 25.0
const DAMAGE_PER_SECOND: float = 8.0
const MAX_PUDDLES: int = 64

var target: Node2D
var puddles: Array[Dictionary] = []


func _ready() -> void:
	add_to_group("hazards")
	z_index = -1


func leave_puddle(point: Vector2) -> void:
	if puddles.size() >= MAX_PUDDLES:
		puddles.pop_front()
	puddles.append({"point": point, "age": 0.0})
	queue_redraw()


func _process(delta: float) -> void:
	if delta <= 0.0 or is_queued_for_deletion():
		return
	# Overlapping puddles are one hazard, not multiplied damage.
	var exposure := 0.0
	for puddle in puddles:
		var before: float = puddle.age
		puddle.age += delta
		if is_instance_valid(target) and target.global_position.distance_squared_to(puddle.point) <= pow(RADIUS + 10.0, 2):
			exposure = maxf(exposure, maxf(0.0, minf(puddle.age, LIFETIME) - maxf(before, WARNING_TIME)))
	puddles = puddles.filter(func(puddle: Dictionary): return puddle.age < LIFETIME)
	if is_instance_valid(target) and exposure > 0.0:
		target.take_damage(DAMAGE_PER_SECOND * exposure)
	queue_redraw()


func _draw() -> void:
	for puddle in puddles:
		var point := to_local(puddle.point)
		var warning: bool = puddle.age < WARNING_TIME
		var fade := minf(1.0, (LIFETIME - puddle.age) / 2.0)
		draw_circle(point, RADIUS, Color(0.12, 0.5, 0.66, (0.12 if warning else 0.38) * fade))
		draw_arc(point, RADIUS, 0, TAU, 24, Color(0.4, 0.85, 1.0, fade * 0.65), 1.5, true)
		if not warning:
			draw_arc(point + Vector2(-4, -2), 10, PI, TAU, 12, Color(0.55, 0.9, 1.0, fade * 0.45), 1.5, true)
