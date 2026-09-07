extends "res://turret.gd"

const VISUAL = preload("res://sniper_visual.gd")
const STAT_MULTIPLIER: float = 3.0
const SNIPER_RANGE: float = 360.0
var visual: Node2D
var aim_target: Node2D
var aim_angle: float = 0.0


func _init() -> void:
	turret_type = "sniper"
	attack_range = SNIPER_RANGE
	damage = 3.0
	fire_interval = 4.5


func _ready() -> void:
	visual = VISUAL.new()
	visual.design = VISUAL.Design.WATCHLIGHT
	add_child(visual)


func _find_target() -> Node2D:
	var furthest: Node2D = null
	var furthest_distance_squared: float = -1.0
	var range_squared := attack_range * attack_range
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if enemy == null or enemy.is_queued_for_deletion() or enemy.health <= 0.0:
			continue
		var distance_squared := global_position.distance_squared_to(enemy.global_position)
		# Strict comparison preserves tree order for equal-distance targets.
		if distance_squared <= range_squared and distance_squared > furthest_distance_squared:
			furthest = enemy
			furthest_distance_squared = distance_squared
	aim_target = furthest
	if furthest != null:
		# Capture the angle before take_damage can remove a killed enemy.
		aim_angle = (furthest.global_position - global_position).angle()
	return furthest


func _process(delta: float) -> void:
	super._process(delta)
	# Keep the aperture aligned with the actual flash, then follow the surviving
	# target while recharging. The next shot always reselects the furthest enemy.
	if shot_time <= 0.0 and is_instance_valid(aim_target) and not aim_target.is_queued_for_deletion():
		aim_angle = (aim_target.global_position - global_position).angle()
	queue_redraw()


func _draw() -> void:
	_draw_boost()
	draw_arc(Vector2.ZERO, attack_range, 0.0, TAU, 96, Color(1.0, 0.9, 0.65, 0.10), 1.0, true)
	if is_instance_valid(visual):
		visual.charge = clampf(1.0 - cooldown / fire_interval, 0.0, 1.0)
		visual.flash = shot_time / 0.12
		visual.aim_angle = aim_angle
		visual.shot_endpoint = to_local(shot_endpoint)
		visual.queue_redraw()
