extends "res://enemy.gd"

# Experimental alternatives for the same encounter slot, selected by the launcher.
enum Kind { RAINKEEPER, TIDEKEEPER, WICKWATCHER }
enum Attack { ARRIVAL, RECOVERY, WARNING, ACTIVE, STALK }

const DROPLET = preload("res://enemy_droplet.gd")
const NAMES := ["THE RAINKEEPER", "THE TIDEKEEPER", "THE WICKWATCHER"]
const POOL_RADIUS := 100.0
const POOL_WARNING := 0.85
const POOL_DURATION := 3.0
const POOL_DPS := 8.0
const RAIN_STRIKES := 3
const RAIN_STRIKE_INTERVAL := 0.35
const RAIN_RECOVERY := 1.5
const FRONT_SPEED := 150.0
const GAP_WIDTH := 150.0
const RUSH_SPEED := 360.0
const RUSH_DURATION := 0.75
const CHARGE_RATES := [-0.35, 0.18, 0.42]

var kind: Kind = Kind.RAINKEEPER
var attack: Attack = Attack.ARRIVAL
var remaining := 3.0
var arrival_remaining := 3.0
var mark := Vector2.ZERO
var rain_strikes := 0
var rain_pools: Array[Dictionary] = []
var charge := 0.0
var vertical_front := false
var front_forward := true
var front_gap := 0.0
var front_origin := 0.0
var front_warning := 1.5
var front_extent := 0.0
var front_travel := 0.0
var front_arena_size := Vector2.ZERO
var projectiles: Array[Node2D] = []


func _ready() -> void:
	max_health = 900.0
	speed = 78.0
	contact_distance = 30.0
	contact_damage_per_second = 0.0
	slow_susceptibility = 0.5
	super._ready()
	add_to_group("bosses")
	add_to_group("prototype_bosses")
	z_index = 2


func _create_body() -> void:
	# Animated silhouette and world-space tells share one redraw.
	pass


func boss_title() -> String:
	return NAMES[kind]


func attack_caption() -> String:
	if attack == Attack.ARRIVAL:
		return "Incoming!"
	match kind:
		Kind.RAINKEEPER:
			if attack == Attack.WARNING: return "Rain %d/%d · keep moving" % [rain_strikes + 1, RAIN_STRIKES]
			if attack == Attack.ACTIVE: return "Rain falling · keep clear"
			return "Recovering · return to your turrets"
		Kind.TIDEKEEPER:
			if attack == Attack.WARNING: return "Tide forming · find the opening"
			if attack == Attack.ACTIVE: return "Cross through the opening"
			return "Recovering"
		Kind.WICKWATCHER:
			if attack == Attack.STALK: return "Light wakes it · %d%%" % int(charge * 100)
			if attack == Attack.WARNING: return "Rush locked · step aside"
			if attack == Attack.ACTIVE: return "Rushing"
			return "Shell open · recovering"
	return ""


func _process(delta: float) -> void:
	if delta <= 0.0 or health <= 0.0 or is_queued_for_deletion() or not is_instance_valid(target) or not target.running:
		return
	if kind == Kind.TIDEKEEPER and attack in [Attack.WARNING, Attack.ACTIVE] and get_parent().get_arena_rect().size != front_arena_size:
		# A resized window must not crop the only opening out of the arena.
		_recover()
	var time_left := delta
	# Consume state boundaries separately: warning time can never deal damage.
	while time_left > 0.000001 and not is_queued_for_deletion() and target.running:
		var step := time_left
		if attack == Attack.STALK:
			var rate: float = CHARGE_RATES[target.brightness]
			if rate > 0.0:
				step = minf(step, (1.0 - charge) / rate)
			charge = clampf(charge + rate * step, 0.0, 1.0)
		else:
			step = minf(step, remaining)
		var movement_time := _consume_slow(step)
		if kind == Kind.RAINKEEPER:
			_tick_rain(step)
		if attack == Attack.RECOVERY or attack == Attack.STALK:
			_drift(movement_time)
		elif attack == Attack.ACTIVE:
			if kind == Kind.WICKWATCHER:
				_rush(step)
				if attack == Attack.RECOVERY:
					time_left -= step
					continue
		time_left -= step
		if attack == Attack.STALK:
			if charge >= 1.0:
				_lock_rush()
		else:
			remaining = maxf(0.0, remaining - step)
			if remaining <= 0.000001:
				_advance()
	arrival_remaining = remaining if attack == Attack.ARRIVAL else 0.0
	queue_redraw()


func _drift(movement_time: float) -> void:
	var offset: Vector2 = target.global_position - global_position
	# Approach the defense, but never push through the lantern on contact.
	global_position += offset.normalized() * minf(speed * movement_time, maxf(0.0, offset.length() - 90.0))
	global_position = global_position.clamp(Vector2(36, 36), (get_parent().get_arena_rect().size - Vector2(36, 36)).max(Vector2(36, 36)))


func _advance() -> void:
	match attack:
		Attack.ARRIVAL, Attack.RECOVERY:
			if kind == Kind.WICKWATCHER:
				attack = Attack.STALK
			else:
				rain_strikes = 0
				attack = Attack.WARNING
				mark = target.global_position
				remaining = POOL_WARNING
				if kind == Kind.TIDEKEEPER:
					_prepare_front()
		Attack.WARNING:
			attack = Attack.ACTIVE
			match kind:
				Kind.RAINKEEPER:
					rain_pools.append({"point": mark, "remaining": POOL_DURATION})
					rain_strikes += 1
					remaining = RAIN_STRIKE_INTERVAL
				Kind.TIDEKEEPER:
					_fire_front()
					remaining = (front_travel + 64.0) / FRONT_SPEED
				Kind.WICKWATCHER: remaining = RUSH_DURATION
		Attack.ACTIVE:
			if kind == Kind.RAINKEEPER and rain_strikes < RAIN_STRIKES:
				mark = target.global_position
				attack = Attack.WARNING
				remaining = POOL_WARNING
			else:
				_recover()


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


func _recover() -> void:
	attack = Attack.RECOVERY
	remaining = RAIN_RECOVERY if kind == Kind.RAINKEEPER else 2.0
	charge = 0.0
	_retire_projectiles()


func _prepare_front() -> void:
	vertical_front = not vertical_front
	var size: Vector2 = get_parent().get_arena_rect().size
	front_arena_size = size
	front_extent = size.x if vertical_front else size.y
	front_travel = size.y if vertical_front else size.x
	var player_axis: float = target.position.x if vertical_front else target.position.y
	var player_depth: float = target.position.y if vertical_front else target.position.x
	front_forward = player_depth >= front_travel / 2.0
	front_origin = 0.0 if front_forward else front_travel
	# Alternate an opening on either side; retain room for the entire hitbox.
	front_gap = clampf(front_extent * (0.3 if front_forward else 0.7), GAP_WIDTH / 2.0 + 16.0, maxf(GAP_WIDTH / 2.0 + 16.0, front_extent - GAP_WIDTH / 2.0 - 16.0))
	# Give even the most distant legal position time to reach the gap before release.
	front_warning = maxf(1.5, absf(player_axis - front_gap) / target.move_speed + 0.6)
	remaining = front_warning


func _fire_front() -> void:
	_retire_projectiles()
	# Closely spaced cores form a ribbon; the wide omitted section is the route.
	var count := int(ceil(front_extent / 20.0)) + 1
	for index in range(count):
		var across := minf(index * 20.0, front_extent)
		if absf(across - front_gap) < GAP_WIDTH / 2.0:
			continue
		var droplet := DROPLET.new()
		droplet.target = target
		droplet.position = Vector2(across, front_origin) if vertical_front else Vector2(front_origin, across)
		droplet.velocity = (Vector2.DOWN if vertical_front else Vector2.RIGHT) * FRONT_SPEED * (1.0 if front_forward else -1.0)
		droplet.lifetime = (front_travel + 64.0) / FRONT_SPEED
		droplet.damage = 10.0
		get_parent().add_child(droplet)
		projectiles.append(droplet)


func _lock_rush() -> void:
	mark = target.global_position
	heading = global_position.direction_to(mark)
	if heading.is_zero_approx(): heading = Vector2.DOWN
	attack = Attack.WARNING
	remaining = 1.2


func _rush(step: float) -> void:
	var arena: Rect2 = get_parent().get_arena_rect().grow(-30.0)
	var destination := (global_position + heading * RUSH_SPEED * step).clamp(arena.position, arena.end)
	var movement := destination - global_position
	var overlaps := global_position.distance_to(target.global_position) <= contact_distance
	var fraction := 0.0 if overlaps else _first_contact_fraction(movement)
	global_position += movement * fraction
	if overlaps or fraction < 1.0 or global_position.distance_to(target.global_position) <= contact_distance:
		target.take_damage(12.0)
		_recover()


func _retire_projectiles() -> void:
	for droplet in projectiles:
		if is_instance_valid(droplet) and not droplet.is_queued_for_deletion(): droplet.retire()
	projectiles.clear()


func take_damage(amount: float) -> void:
	if attack == Attack.ARRIVAL: return
	super.take_damage(amount)
	if health <= 0.0:
		rain_pools.clear()
		_retire_projectiles()


func _draw() -> void:
	var pale := Color("#a6ebee")
	if kind == Kind.RAINKEEPER:
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
	elif kind == Kind.TIDEKEEPER:
		draw_arc(Vector2.ZERO, 30, 0.2, TAU - 0.2, 48, Color("#388fa3"), 17.0, true)
		if attack == Attack.WARNING:
			var begin := Vector2(0, front_origin) if vertical_front else Vector2(front_origin, 0)
			var along := Vector2.RIGHT if vertical_front else Vector2.DOWN
			var inset := Vector2(0, 8 if front_forward else -8) if vertical_front else Vector2(8 if front_forward else -8, 0)
			begin += inset
			var gap_start := begin + along * (front_gap - GAP_WIDTH / 2.0)
			var gap_end := begin + along * (front_gap + GAP_WIDTH / 2.0)
			draw_dashed_line(to_local(begin), to_local(gap_start), pale, 4.0, 12.0)
			draw_dashed_line(to_local(gap_end), to_local(begin + along * front_extent), pale, 4.0, 12.0)
			for endpoint in [gap_start, gap_end]:
				draw_arc(to_local(endpoint), 8, 0, TAU, 24, Color("#ffe0a3"), 3.0, true)
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(0, -38), Vector2(30, 12), Vector2(18, 30), Vector2(-18, 30), Vector2(-30, 12)]), Color("#29495f"))
		if attack == Attack.RECOVERY:
			draw_circle(Vector2.ZERO, 18, pale)
		for index in range(3):
			var filled := charge * 3.0 >= index + 1 or attack == Attack.WARNING or attack == Attack.ACTIVE
			draw_line(Vector2(-16 + index * 16, -10), Vector2(-16 + index * 16, 7), Color("#ffe0a3") if filled else Color("#517786"), 5.0, true)
		if attack == Attack.WARNING:
			var end := (global_position + heading * RUSH_SPEED * RUSH_DURATION).clamp(Vector2(30, 30), get_parent().get_arena_rect().size - Vector2(30, 30))
			draw_line(Vector2.ZERO, to_local(end), Color(0.55, 0.9, 1.0, 0.12), contact_distance * 2)
			draw_dashed_line(Vector2.ZERO, to_local(end), pale, 3.0, 12.0)
		elif attack == Attack.ACTIVE:
			draw_line(-heading * 50, Vector2.ZERO, pale, 5.0, true)
	for eye in [-1, 1]:
		draw_circle(Vector2(eye * 10, 13), 3, Color("#e2f7bd"))
	if attack == Attack.ARRIVAL:
		draw_arc(Vector2.ZERO, 46, 0, TAU, 64, pale, 3.0, true)
