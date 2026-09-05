extends Node2D

const CONTACT_DISTANCE: float = 20.0
const CONTACT_TOLERANCE: float = 0.1

@export var speed: float = 45.0
@export var contact_damage_per_second: float = 15.0

var target: Node2D


func _ready() -> void:
	add_to_group("enemies")
	queue_redraw()
	

func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return

	var distance: float = global_position.distance_to(target.global_position)

	# Contact damage scales with time, so frame rate does not change its strength.
	# Movement can stop a fraction of a pixel outside the intended distance.
	if distance <= CONTACT_DISTANCE + CONTACT_TOLERANCE:
		target.take_damage(contact_damage_per_second * delta)
		return

	var step: float = minf(speed * delta, distance - CONTACT_DISTANCE)
	global_position = global_position.move_toward(
		target.global_position,
		step
	)


func _draw() -> void:
	# A little purple creature with two bright eyes.
	draw_circle(Vector2.ZERO, 10.0, Color("#826caa"))
	draw_circle(Vector2(-3.0, -2.0), 2.0, Color("#ffe0a3"))
	draw_circle(Vector2(3.0, -2.0), 2.0, Color("#ffe0a3"))
