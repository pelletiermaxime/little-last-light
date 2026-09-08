extends "res://enemies/enemy.gd"

enum Attack { ARRIVAL, RECOVERY, WARNING, ACTIVE }

const POOL_RADIUS := 100.0
const POOL_WARNING := 0.85
const POOL_DURATION := 3.0
const POOL_DPS := 8.0
const RAIN_STRIKES := 3
const RAIN_STRIKE_INTERVAL := 0.35
const RAIN_RECOVERY := 1.5

var attack: Attack = Attack.ARRIVAL
var remaining := 3.0
var arrival_remaining := 3.0
var mark := Vector2.ZERO
var rain_strikes := 0
var rain_pools: Array[Dictionary] = []


func _ready() -> void:
	max_health = 900.0
	speed = 78.0
	contact_distance = 30.0
	contact_damage_per_second = 0.0
	slow_susceptibility = 0.5
	super._ready()
	add_to_group("bosses")
	add_to_group("rainkeepers")
	z_index = 2


func _create_body() -> void:
	# Animated silhouette and world-space tells share one redraw.
	pass


func boss_title() -> String:
	return "THE RAINKEEPER"


func attack_caption() -> String:
	match attack:
		Attack.ARRIVAL: return "Incoming!"
		Attack.WARNING: return "Rain %d/%d · keep moving" % [rain_strikes + 1, RAIN_STRIKES]
		Attack.ACTIVE: return "Rain falling · keep clear"
		_: return "Recovering · return to your turrets"


func _process(delta: float) -> void:
	if delta <= 0.0 or health <= 0.0 or is_queued_for_deletion() or not is_instance_valid(target) or not target.running:
		return
	var time_left := delta
	# Warning time cannot damage; older pools retain their own expiry clocks.
	while time_left > 0.000001 and not is_queued_for_deletion() and target.running:
		var step := minf(time_left, remaining)
		var movement_time := _consume_slow(step)
		_tick_rain(step)
		if attack == Attack.RECOVERY:
			_drift(movement_time)
		time_left -= step
		remaining = maxf(0.0, remaining - step)
		if remaining <= 0.000001:
			_advance()
	arrival_remaining = remaining if attack == Attack.ARRIVAL else 0.0
	queue_redraw()


func _drift(movement_time: float) -> void:
	var offset: Vector2 = target.global_position - global_position
	global_position += offset.normalized() * minf(speed * movement_time, maxf(0.0, offset.length() - 90.0))
	global_position = global_position.clamp(Vector2(36, 36), (get_parent().get_arena_rect().size - Vector2(36, 36)).max(Vector2(36, 36)))


func _advance() -> void:
	match attack:
		Attack.ARRIVAL, Attack.RECOVERY:
			rain_strikes = 0
			_mark_strike()
		Attack.WARNING:
			attack = Attack.ACTIVE
			rain_pools.append({"point": mark, "remaining": POOL_DURATION})
			rain_strikes += 1
			remaining = RAIN_STRIKE_INTERVAL
		Attack.ACTIVE:
			if rain_strikes < RAIN_STRIKES:
				_mark_strike()
			else:
				attack = Attack.RECOVERY
				remaining = RAIN_RECOVERY


func _mark_strike() -> void:
	mark = target.global_position
	attack = Attack.WARNING
	remaining = POOL_WARNING


func _tick_rain(step: float) -> void:
	# Old pools obstruct the return route, but overlap never multiplies damage.
	var exposure := 0.0
	for pool in rain_pools:
		if target.global_position.distance_to(pool.point) <= POOL_RADIUS + 10.0:
			exposure = maxf(exposure, minf(step, pool.remaining))
		pool.remaining -= step
	rain_pools = rain_pools.filter(func(pool: Dictionary): return pool.remaining > 0.0)
	if exposure > 0.0:
		target.take_damage(POOL_DPS * exposure)


func take_damage(amount: float) -> void:
	if attack == Attack.ARRIVAL: return
	super.take_damage(amount)
	if health <= 0.0:
		rain_pools.clear()


func _draw() -> void:
	var pale := Color("#a6ebee")
	draw_circle(Vector2.ZERO, 32, Color("#246780"))
	draw_circle(Vector2(-8, -6), 23, Color("#388fa3"))
	draw_circle(Vector2(-12, -13), 8, pale)
	for pool in rain_pools:
		var point := to_local(pool.point)
		var fade: float = minf(1.0, pool.remaining / 0.5)
		draw_circle(point, POOL_RADIUS, Color(0.12, 0.5, 0.66, 0.48 * fade))
		draw_arc(point, POOL_RADIUS, 0, TAU, 64, Color(pale, fade), 2.0, true)
		draw_arc(point, 35, 0, PI, 32, Color(pale, fade), 2.0, true)
	if attack == Attack.WARNING:
		var point := to_local(mark)
		draw_arc(point, POOL_RADIUS, 0, TAU, 64, pale, 3.0, true)
		draw_arc(point, POOL_RADIUS * remaining / POOL_WARNING, 0, TAU, 64, pale, 2.0, true)
		draw_dashed_line(Vector2.ZERO, point, Color(pale, 0.45), 1.5, 10.0)
		draw_circle(point + Vector2(0, -70 * remaining / POOL_WARNING), 5.0, pale)
	for eye in [-1, 1]:
		draw_circle(Vector2(eye * 10, 13), 3, Color("#e2f7bd"))
	if attack == Attack.ARRIVAL:
		draw_arc(Vector2.ZERO, 46, 0, TAU, 64, pale, 3.0, true)
