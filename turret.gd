extends Node2D

# Idle turrets poll at most ten times per second, even with a large swarm.
const IDLE_SEARCH_INTERVAL: float = 0.1

@export var attack_range: float = 220.0
@export var fire_interval: float = 1.5
@export var damage: float = 1.0
var purchase_cost: float = 0.0

var cooldown: float = 0.0
var shot_time: float = 0.0
var shot_endpoint: Vector2 = Vector2.ZERO


func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	var was_firing := shot_time > 0.0
	shot_time = maxf(0.0, shot_time - delta)
	if was_firing and shot_time <= 0.0:
		queue_redraw()

	if cooldown <= 0.0:
		var enemy: Node2D = _find_nearest_enemy()

		if enemy != null:
			shot_endpoint = enemy.global_position
			shot_time = 0.12
			cooldown = fire_interval
			enemy.take_damage(damage)
			queue_redraw()
		else:
			cooldown = IDLE_SEARCH_INTERVAL


func _find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var nearest_distance_squared: float = attack_range * attack_range

	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D

		if enemy == null or enemy.is_queued_for_deletion():
			continue

		var distance_squared: float = global_position.distance_squared_to(
			enemy.global_position
		)

		if distance_squared < nearest_distance_squared:
			nearest = enemy
			nearest_distance_squared = distance_squared

	return nearest


func _draw() -> void:
	# A faint circle shows how far the turret can shoot.
	draw_arc(
		Vector2.ZERO,
		attack_range,
		0.0,
		TAU,
		64,
		Color(0.4, 0.8, 1.0, 0.15),
		1.0,
		true
	)

	# Turret body.
	draw_circle(Vector2.ZERO, 13.0, Color("#36566f"))
	draw_circle(Vector2.ZERO, 7.0, Color("#9bddff"))

	# A short flash connects the turret to its last target.
	if shot_time > 0.0:
		draw_line(
			Vector2.ZERO,
			to_local(shot_endpoint),
			Color("#bcecff"),
			2.0,
			true
		)
