extends Node2D

const CONTACT_DISTANCE: float = 20.0
const CONTACT_TOLERANCE: float = 0.1

@export var speed: float = 45.0
@export var contact_damage_per_second: float = 15.0
@export var max_health: float = 1.0

var health: float

var target: Node2D


func _ready() -> void:
	health = max_health
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
	if speed <= 0.0:
		return

	var step: float = minf(speed * delta, distance - CONTACT_DISTANCE)
	var time_to_contact: float = (distance - CONTACT_DISTANCE) / speed
	global_position = global_position.move_toward(
		target.global_position,
		step
	)
	# Count time after arriving this frame, not just contact at its beginning.
	# Otherwise a moving lantern can escape every pre-movement damage check.
	var contact_time: float = maxf(0.0, delta - time_to_contact)
	if contact_time > 0.0:
		target.take_damage(contact_damage_per_second * contact_time)


func take_damage(amount: float) -> void:
	if health <= 0.0 or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	if health <= 0.0:
		queue_free()
	queue_redraw()


func _draw() -> void:
	# A little purple creature with two bright eyes.
	draw_circle(Vector2.ZERO, 10.0, Color("#826caa"))
	draw_circle(Vector2(-3.0, -2.0), 2.0, Color("#ffe0a3"))
	draw_circle(Vector2(3.0, -2.0), 2.0, Color("#ffe0a3"))
	if max_health > 1.0:
		draw_rect(Rect2(-12, -18, 24, 3), Color("#35414e"))
		draw_rect(Rect2(-12, -18, 24 * health / max_health, 3), Color("#efb17b"))
