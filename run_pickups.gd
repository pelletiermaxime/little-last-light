extends Node2D

enum Kind { KINDLING, FLARE, SENTINEL, STILLNESS }

const NAMES := ["Kindling", "Flare", "Sentinel", "Stillness"]
const SENTINEL_SCRIPT = preload("res://sentinel.gd")
const STILLNESS_DURATION := 3.0

const FIRST_SPAWN := 12.0
const LAST_SPAWN := 180.0
const LIFETIME := 18.0
const KINDLING_DURATION := 8.0
const COLLECTION_RADIUS := 28.0
const MARKER_RADIUS := 20.0
const MIN_DISTANCE := 160.0
const FLARE_RADIUS := 180.0
const FLARE_DAMAGE := 8.0

var next_spawn := FIRST_SPAWN
var active := false
var kind: Kind = Kind.KINDLING
var pickup_position := Vector2.ZERO
var remaining := 0.0
var kindling_remaining := 0.0
var burst_remaining := 0.0
var burst_position := Vector2.ZERO
var notice_remaining := 0.0
var notice := ""
var explained_kinds: Dictionary = {}
var explain_current := false
var sentinel: Node2D
var stillness_remaining := 0.0
var frozen_enemies: Dictionary = {}
var status: Label
var rng := RandomNumberGenerator.new()
@onready var main: Node2D = get_parent()


func _ready() -> void:
	rng.randomize()
	z_index = 4
	var layer := CanvasLayer.new()
	add_child(layer)
	status = preload("res://ui_style.gd").label("", 16, Color("#ffe0a0"))
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(status)
	get_viewport().size_changed.connect(_layout)
	_layout()
	reset()


func _layout() -> void:
	var size := get_viewport_rect().size
	status.position = Vector2(16, size.y - 154)
	status.size = Vector2(size.x - 32, 60)
	# Resizing may move the marker, but never collects it from a menu callback.
	pickup_position = pickup_position.clamp(_spawn_rect().position, _spawn_rect().end)
	if is_instance_valid(sentinel):
		sentinel.position = sentinel.position.clamp(_spawn_rect().position, _spawn_rect().end)
	queue_redraw()


func _spawn_rect() -> Rect2:
	var size := get_viewport_rect().size
	# Keep labels clear of the top HUD and bottom brightness/status controls.
	var inset := Vector2(minf(90, size.x * 0.25), minf(180, size.y * 0.3))
	return Rect2(inset, (size - inset * 2.0).max(Vector2.ZERO))


func reset() -> void:
	_clear_sentinel()
	stillness_remaining = 0.0
	_thaw_enemies()
	active = false
	remaining = 0.0
	kindling_remaining = 0.0
	burst_remaining = 0.0
	notice_remaining = 0.0
	next_spawn = FIRST_SPAWN
	explained_kinds.clear()
	explain_current = false
	if is_instance_valid(status):
		status.hide()
	queue_redraw()


func consume_kindling(delta: float) -> float:
	var boosted := minf(delta, kindling_remaining)
	kindling_remaining = maxf(0.0, kindling_remaining - delta)
	return boosted


func _process(delta: float) -> void:
	if main.phase != main.Phase.RUNNING or get_tree().paused:
		return
	burst_remaining = maxf(0.0, burst_remaining - delta)
	stillness_remaining = maxf(0.0, stillness_remaining - delta)
	if stillness_remaining > 0.0:
		_freeze_enemies()
	else:
		_thaw_enemies()
	notice_remaining = maxf(0.0, notice_remaining - delta)
	if active:
		remaining = maxf(0.0, remaining - delta)
		if remaining <= 0.0:
			active = false
			notice = "Ember faded"
			notice_remaining = 2.0
		elif main.lantern.position.distance_to(pickup_position) <= COLLECTION_RADIUS:
			_collect()
	elif main.lantern.elapsed >= next_spawn and main.lantern.elapsed < LAST_SPAWN:
		# No catch-up burst after a long frame, expiry, or viewport too small.
		next_spawn = main.lantern.elapsed + rng.randf_range(24.0, 34.0)
		_spawn()
	_refresh_status()
	queue_redraw()


func _spawn() -> bool:
	var arena := _spawn_rect()
	for attempt in range(24):
		var point := Vector2(rng.randf_range(arena.position.x, arena.end.x), rng.randf_range(arena.position.y, arena.end.y))
		if point.distance_to(main.lantern.position) < MIN_DISTANCE:
			continue
		pickup_position = point
		kind = rng.randi_range(0, Kind.size() - 1) as Kind
		remaining = LIFETIME
		active = true
		explain_current = false
		return true
	return false


func _collect() -> void:
	if not active or main.phase != main.Phase.RUNNING or main.lantern.health <= 0.0:
		return
	active = false
	if kind == Kind.KINDLING:
		# Refresh rather than stack if cadence is shortened for a future experiment.
		kindling_remaining = KINDLING_DURATION
	elif kind == Kind.FLARE:
		burst_position = pickup_position
		burst_remaining = 0.45
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not enemy.is_queued_for_deletion() and enemy.global_position.distance_to(burst_position) <= FLARE_RADIUS:
				enemy.take_damage(FLARE_DAMAGE)
		notice = "Flare · nearby enemies hit"
		notice_remaining = 2.5
	elif kind == Kind.SENTINEL:
		_clear_sentinel()
		sentinel = SENTINEL_SCRIPT.new()
		sentinel.damage = maxf(4.0, main.turret_damage() * 2.0)
		sentinel.position = pickup_position
		add_child(sentinel)
	else:
		stillness_remaining = STILLNESS_DURATION
		_freeze_enemies()
	get_node("/root/GameAudio").play(&"upgrade")


func _clear_sentinel() -> void:
	if is_instance_valid(sentinel):
		sentinel.process_mode = Node.PROCESS_MODE_DISABLED
		sentinel.queue_free()
	sentinel = null


func _freeze_enemies() -> void:
	# Keep spawning at the ordinary cadence; new arrivals join the same freeze.
	# Disabling processing also stops contact damage and charger attack clocks.
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.is_queued_for_deletion() or frozen_enemies.has(enemy):
			continue
		frozen_enemies[enemy] = enemy.process_mode
		enemy.process_mode = Node.PROCESS_MODE_DISABLED


func _thaw_enemies() -> void:
	for enemy in frozen_enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			enemy.process_mode = frozen_enemies[enemy]
	frozen_enemies.clear()


func _refresh_status() -> void:
	status.text = ""
	var effects: Array[String] = []
	if kindling_remaining > 0.0:
		effects.append("Kindling · energy ×2 · %ds" % ceili(kindling_remaining))
	if stillness_remaining > 0.0:
		effects.append("Stillness · enemies frozen · %ds" % ceili(stillness_remaining))
	if is_instance_valid(sentinel) and not sentinel.is_queued_for_deletion():
		effects.append("Sentinel · %ds" % ceili(sentinel.remaining))
	status.text = "  /  ".join(effects)
	if status.text.is_empty() and notice_remaining > 0.0:
		status.text = notice
	if active:
		if not explained_kinds.has(kind):
			explained_kinds[kind] = true
			explain_current = true
		if explain_current:
			if kind == Kind.KINDLING:
				status.text = "Kindling · Walk into the diamond before it fades.\nDoubles passive energy for 8 seconds, including Energy Gain upgrades.\nBoss rewards stay unchanged."
			elif kind == Kind.FLARE:
				status.text = "Flare · Walk into the spark before it fades.\nDeals %d damage to enemies within %d pixels of the pickup.\nA single burst; projectiles and water remain." % [int(FLARE_DAMAGE), int(FLARE_RADIUS)]
			elif kind == Kind.SENTINEL:
				status.text = "Sentinel · Walk into the square before it fades.\nCreates a turret here for 12s: %d damage every 0.35s, 260-pixel range.\nDouble your turret damage (minimum 4); no proximity bonus." % int(maxf(4.0, main.turret_damage() * 2.0))
			else:
				status.text = "Stillness · Walk into the pause symbol before it fades.\nFreezes enemy movement and attacks across the arena for 3 seconds.\nYou and turrets keep moving and firing; existing water and shots remain dangerous."
	status.visible = not status.text.is_empty()


func _draw() -> void:
	var color := Color("#ffbd59")
	if active:
		var point := pickup_position
		var opacity := minf(1.0, remaining / 3.0)
		color.a = opacity
		draw_circle(point, 26, Color(1.0, 0.65, 0.2, 0.1 * opacity))
		draw_arc(point, MARKER_RADIUS, -PI / 2, -PI / 2 + TAU * remaining / LIFETIME, 48, color, 2, true)
		if kind == Kind.KINDLING:
			draw_colored_polygon(PackedVector2Array([point + Vector2(0, -9), point + Vector2(6, 0), point + Vector2(0, 9), point + Vector2(-6, 0)]), color)
		elif kind == Kind.FLARE:
			for ray in range(8):
				var direction := Vector2.from_angle(ray * TAU / 8.0)
				draw_line(point + direction * 4, point + direction * 10, color, 2, true)
		elif kind == Kind.SENTINEL:
			draw_rect(Rect2(point - Vector2(8, 8), Vector2(16, 16)), color, false, 2)
			draw_circle(point, 3, color)
		else:
			draw_line(point + Vector2(-4, -9), point + Vector2(-4, 9), color, 3, true)
			draw_line(point + Vector2(4, -9), point + Vector2(4, 9), color, 3, true)
		var caption := "%s · %ds" % [NAMES[kind], ceili(remaining)]
		var font := ThemeDB.fallback_font
		var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(font, point + Vector2(-width / 2, 37), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
	if burst_remaining > 0.0:
		var progress := 1.0 - burst_remaining / 0.45
		draw_circle(burst_position, FLARE_RADIUS, Color(1.0, 0.7, 0.3, 0.12 * (1.0 - progress)))
		draw_arc(burst_position, lerpf(MARKER_RADIUS, FLARE_RADIUS, progress), 0, TAU, 64, Color(1.0, 0.8, 0.4, 1.0 - progress), 3, true)
	if stillness_remaining > 0.0:
		for enemy in frozen_enemies:
			if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
				draw_arc(to_local(enemy.global_position), 19, 0, TAU, 24, Color("#bcecff"), 1.5, true)
