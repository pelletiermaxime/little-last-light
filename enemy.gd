extends Node2D

const CONTACT_DISTANCE: float = 20.0
const CONTACT_TOLERANCE: float = 0.1

@export var speed: float = 85.0
# 75 degrees per second: a half-turn takes 2.4 seconds.
@export var turn_speed: float = 5.0 * PI / 12.0
@export var contact_damage_per_second: float = 15.0
@export var max_health: float = 1.0

var health: float

var target: Node2D
var heading: Vector2 = Vector2.ZERO


func _ready() -> void:
	health = max_health
	add_to_group("enemies")
	queue_redraw()
	

func _process(delta: float) -> void:
	if not is_instance_valid(target) or delta <= 0.0:
		return

	var distance: float = global_position.distance_to(target.global_position)

	# Contact damage scales with time, so frame rate does not change its strength.
	# Movement can stop a fraction of a pixel outside the intended distance.
	if distance <= CONTACT_DISTANCE + CONTACT_TOLERANCE:
		target.take_damage(contact_damage_per_second * delta)
		return
	if speed <= 0.0:
		return

	var desired := global_position.direction_to(target.global_position)
	# Initialize on the first movement, after Main has set the spawn position.
	if heading.is_zero_approx():
		heading = desired
	var max_turn := maxf(0.0, turn_speed) * delta
	heading = heading.rotated(clampf(heading.angle_to(desired), -max_turn, max_turn)).normalized()
	var movement := heading * speed * delta
	var fraction := _first_contact_fraction(movement)
	global_position += movement * fraction
	# Only the part of the frame spent touching the lantern deals damage.
	# A curved approach may miss it entirely, even when it is very close.
	if fraction < 1.0:
		target.take_damage(contact_damage_per_second * delta * (1.0 - fraction))
	queue_redraw()


func _first_contact_fraction(movement: Vector2) -> float:
	# Intersect this frame's movement segment with the contact circle. Checking
	# only the endpoint could skip right through the lantern on a long frame.
	var entry := Geometry2D.segment_intersects_circle(
		global_position, global_position + movement,
		target.global_position, CONTACT_DISTANCE
	)
	return entry if entry >= 0.0 else 1.0


func take_damage(amount: float) -> void:
	if health <= 0.0 or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	if health <= 0.0:
		queue_free()
	queue_redraw()


func _draw() -> void:
	# Eyes face the direction of travel, making pursuit commitment visible.
	var forward := heading if not heading.is_zero_approx() else Vector2.UP
	var side := forward.orthogonal()
	draw_circle(Vector2.ZERO, 10.0, Color("#826caa"))
	draw_circle(forward * 4.0 - side * 3.0, 2.0, Color("#ffe0a3"))
	draw_circle(forward * 4.0 + side * 3.0, 2.0, Color("#ffe0a3"))
	if max_health > 1.0:
		draw_rect(Rect2(-12, -18, 24, 3), Color("#35414e"))
		draw_rect(Rect2(-12, -18, 24 * health / max_health, 3), Color("#efb17b"))
