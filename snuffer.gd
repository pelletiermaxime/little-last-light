extends "res://enemy.gd"

signal defeated

enum Attack { ARRIVAL, VOLLEY_WARNING, VOLLEY, RING_WARNING, RINGS, RECOVERY }
const DROPLET = preload("res://enemy_droplet.gd")
const VOLLEY_INTERVAL := 0.32
const VOLLEY_COUNT := 8
const RING_COUNT := 36
const MAX_PROJECTILES := 180
const DRIFT_SPEED := 85.0
const DESPERATION_SPEED_MULTIPLIER := 2.5
const RECOVERY_TIME := 1.8
const DESPERATION_RECOVERY_TIME := 1.2

var attack: Attack = Attack.ARRIVAL
var remaining := 3.0
var arrival_remaining := 3.0
var enraged := false
var desperate := false
var desperation_announcement := 0.0
var volley_next := true
var shots_fired := 0
var ring_angle := 0.0
var rings_this_pattern := 1
var drift_step := 0
var drift_destination := Vector2.ZERO


func _ready() -> void:
	max_health = 1200.0
	super._ready()
	add_to_group("bosses")
	add_to_group("final_bosses")


func _process(delta: float) -> void:
	if delta <= 0.0 or health <= 0.0 or is_queued_for_deletion() or not is_instance_valid(target) or not target.running:
		return
	desperation_announcement = maxf(0.0, desperation_announcement - delta)
	while delta > 0.0 and health > 0.0 and target.running:
		var step := minf(delta, remaining)
		if attack == Attack.RECOVERY:
			# Drift between patterns, never charge or deal body-contact damage.
			var drift_speed := DRIFT_SPEED * (DESPERATION_SPEED_MULTIPLIER if desperate else 1.0)
			global_position = global_position.move_toward(drift_destination, drift_speed * step)
		if attack == Attack.VOLLEY_WARNING:
			heading = global_position.direction_to(target.global_position)
		remaining -= step
		delta -= step
		arrival_remaining = remaining if attack == Attack.ARRIVAL else 0.0
		if remaining <= 0.0 and target.running:
			_advance_attack()
	queue_redraw()


func _advance_attack() -> void:
	match attack:
		Attack.ARRIVAL, Attack.RECOVERY:
			shots_fired = 0
			if volley_next:
				attack = Attack.VOLLEY_WARNING
			else:
				attack = Attack.RING_WARNING
				ring_angle = global_position.direction_to(target.global_position).angle()
				rings_this_pattern = 3 if enraged else 1
			volley_next = not volley_next
			remaining = 1.0
		Attack.VOLLEY_WARNING, Attack.VOLLEY:
			if shots_fired < VOLLEY_COUNT:
				attack = Attack.VOLLEY
				_fire_volley()
				shots_fired += 1
				remaining = VOLLEY_INTERVAL
			else:
				_begin_recovery()
		Attack.RING_WARNING, Attack.RINGS:
			if shots_fired < rings_this_pattern:
				attack = Attack.RINGS
				_fire_ring()
				shots_fired += 1
				# Offset the next full ring by half a droplet spacing.
				if shots_fired < rings_this_pattern:
					ring_angle += PI / RING_COUNT
				remaining = 0.85
			else:
				_begin_recovery()


func _begin_recovery() -> void:
	attack = Attack.RECOVERY
	remaining = DESPERATION_RECOVERY_TIME if desperate else RECOVERY_TIME
	var arena: Rect2 = get_parent().get_arena_rect().grow(-64.0)
	drift_step += 1
	drift_destination = (arena.get_center() + Vector2.from_angle(drift_step * PI / 2.0) * minf(150.0, arena.size.y * 0.25)).clamp(arena.position, arena.end)


func _fire_volley() -> void:
	# Each volley aims anew; every droplet keeps its original velocity afterward.
	heading = global_position.direction_to(target.global_position)
	if heading.is_zero_approx():
		heading = Vector2.DOWN
	for spread in [-0.28, -0.14, 0.0, 0.14, 0.28]:
		_emit_droplet(heading.rotated(spread), 215.0, Color("#90e6ff"))


func _fire_ring() -> void:
	for index in range(RING_COUNT):
		var angle := ring_angle + TAU * index / RING_COUNT
		_emit_droplet(Vector2.from_angle(angle), 165.0, Color("#e4c5ff"))


func _emit_droplet(direction: Vector2, projectile_speed: float, color: Color) -> void:
	if get_tree().get_nodes_in_group("enemy_projectiles").size() >= MAX_PROJECTILES:
		return
	var droplet := DROPLET.new()
	droplet.target = target
	droplet.velocity = direction * projectile_speed
	droplet.tint = color
	droplet.position = global_position + direction * 42.0
	get_parent().add_child(droplet)


func take_damage(amount: float) -> void:
	if health <= 0.0 or is_queued_for_deletion() or amount <= 0.0 or attack == Attack.ARRIVAL:
		return
	super.take_damage(amount)
	# Low health adds overlapping rings, not faster unannounced shots.
	if not enraged and health <= max_health * 0.5:
		enraged = true
		body.queue_redraw()
	if not desperate and health > 0.0 and health <= max_health / 3.0:
		desperate = true
		desperation_announcement = 3.0
		# Preserve any active warning/volley. Only recovery is accelerated.
		if attack == Attack.RECOVERY:
			remaining = minf(remaining, DESPERATION_RECOVERY_TIME)
		body.queue_redraw()
	if health <= 0.0:
		defeated.emit()


func attack_caption() -> String:
	if desperation_announcement > 0.0:
		return "DESPERATION · faster!"
	match attack:
		Attack.ARRIVAL: return "Drawn to the last light"
		Attack.VOLLEY_WARNING: return "VOLLEY · get ready"
		Attack.VOLLEY: return "VOLLEY · keep moving"
		Attack.RING_WARNING: return "RINGS · spread out"
		Attack.RINGS: return "RINGS · weave through"
		_: return "RECOVERY · reposition"


func _draw_body() -> void:
	# A floating shell with a luminous reservoir and visible firing ports.
	body.draw_circle(Vector2.ZERO, 35, Color("#333b5e"))
	body.draw_arc(Vector2.ZERO, 34, 0, TAU, 48, Color("#d8b6ed") if enraged else Color("#8fbbd4"), 3.0, true)
	if desperate:
		# Permanent bright corona distinguishes phase three after the announcement.
		body.draw_arc(Vector2.ZERO, 39, 0, TAU, 48, Color("#ffb47d"), 3.0, true)
		for index in range(8):
			var ray := Vector2.from_angle(TAU * index / 8.0)
			body.draw_line(ray * 38, ray * 48, Color("#ffb47d"), 2.0, true)
	for index in range(6):
		var point := Vector2.from_angle(TAU * index / 6.0) * 30
		body.draw_circle(point, 8, Color("#516b91"))
		body.draw_circle(point, 3, Color("#b7eeff"))
	body.draw_circle(Vector2.ZERO, 19, Color("#457eab"))
	body.draw_circle(Vector2(-4, -4), 10, Color("#c0efff"))


func _draw() -> void:
	if attack == Attack.RING_WARNING or attack == Attack.RINGS:
		draw_arc(Vector2.ZERO, 62, 0, TAU, 48, Color("#e4c5ff"), 3.0, true)
	elif attack == Attack.VOLLEY_WARNING:
		draw_dashed_line(heading * 42, heading * 230, Color("#90e6ff"), 2.0, 12, true)
		draw_arc(Vector2.ZERO, 46, 0, TAU, 48, Color("#90e6ff"), 2.0, true)
	elif attack == Attack.ARRIVAL:
		draw_arc(Vector2.ZERO, 52, 0, TAU, 48, Color("#90e6ff"), 3.0, true)
	elif attack == Attack.RECOVERY:
		draw_arc(Vector2.ZERO, 44, 0, TAU, 48, Color("#b2d8bc"), 2.0, true)
