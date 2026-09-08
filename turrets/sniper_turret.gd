extends "res://turrets/turret.gd"

const VISUAL = preload("res://turrets/sniper_visual.gd")
const STAT_MULTIPLIER: float = 3.0
const SNIPER_RANGE: float = 360.0
const TURN_SPEED: float = TAU
var visual: Node2D
var aim_target: Node2D
var aim_angle: float = 0.0
var target_search_remaining: float = 0.0
var fired_this_frame: bool = false


func _init() -> void:
	turret_type = "sniper"
	range_color = Color(1.0, 0.9, 0.65, 0.10)
	range_segments = 96
	attack_range = SNIPER_RANGE
	damage = 3.0
	fire_interval = 4.5


func _ready() -> void:
	super._ready()
	visual = VISUAL.new()
	add_child(visual)


func _find_target() -> Node2D:
	aim_target = _furthest_enemy()
	target_search_remaining = IDLE_SEARCH_INTERVAL
	if aim_target != null:
		# The shot must face its actual hit, even if priority changed since aiming.
		aim_angle = (aim_target.global_position - global_position).angle()
		fired_this_frame = true
	return aim_target


func _furthest_enemy() -> Node2D:
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
	return furthest


func _process(delta: float) -> void:
	fired_this_frame = false
	target_search_remaining = maxf(0.0, target_search_remaining - delta)
	var flash_remaining := shot_time
	super._process(delta)
	# Select after damage so a just-killed enemy cannot hold the reload aim.
	# Between shots, poll at the same bounded rate as the base turret's idle scan.
	if fired_this_frame or target_search_remaining <= 0.0:
		aim_target = _furthest_enemy()
		target_search_remaining = IDLE_SEARCH_INTERVAL
	# The flash stays aligned with the shot; use only time after its expiry to turn.
	if shot_time <= 0.0 and is_instance_valid(aim_target) and not aim_target.is_queued_for_deletion() and aim_target.health > 0.0 and global_position.distance_squared_to(aim_target.global_position) <= attack_range * attack_range:
		var desired_angle := (aim_target.global_position - global_position).angle()
		aim_angle = rotate_toward(aim_angle, desired_angle, TURN_SPEED * maxf(0.0, delta - flash_remaining))
	queue_redraw()


func _draw() -> void:
	_draw_boost()
	if is_instance_valid(visual):
		visual.charge = clampf(1.0 - cooldown / fire_interval, 0.0, 1.0)
		visual.flash = shot_time / 0.12
		visual.aim_angle = aim_angle
		visual.shot_endpoint = to_local(shot_endpoint)
		visual.queue_redraw()
