extends Node2D

# Reusable straight projectile. Shooters set direction/speed once at launch.
const HIT_RADIUS := 5.0
const PLAYER_HIT_RADIUS := 8.0
var target: Node2D
var velocity := Vector2.ZERO
var damage := 12.0
var lifetime := 8.0
var arming_remaining := 0.18
var tint := Color("#90e6ff")


func _ready() -> void:
	add_to_group("hazards")
	get_node("/root/DisplaySettings").changed.connect(queue_redraw)
	add_to_group("enemy_projectiles")
	z_index = 3
	rotation = velocity.angle()
	queue_redraw()


func _process(delta: float) -> void:
	if is_queued_for_deletion() or delta <= 0.0:
		return
	if not is_instance_valid(target) or not target.running:
		retire()
		return
	var step := minf(delta, lifetime)
	var before := global_position
	global_position += velocity * step
	# Visible launch grace prevents point-blank rings appearing inside you.
	var safe_step := minf(step, arming_remaining)
	arming_remaining -= safe_step
	var armed_start := before + velocity * safe_step
	if step > safe_step:
		var radius := HIT_RADIUS + PLAYER_HIT_RADIUS
		if armed_start.distance_to(target.global_position) <= radius or Geometry2D.segment_intersects_circle(armed_start, global_position, target.global_position, radius) >= 0.0:
			target.take_projectile_damage(damage)
			retire()
			return
	lifetime -= step
	var arena: Rect2 = get_parent().get_arena_rect().grow(32.0)
	if lifetime <= 0.0 or not arena.has_point(global_position):
		retire()


func retire() -> void:
	remove_from_group("hazards")
	remove_from_group("enemy_projectiles")
	process_mode = Node.PROCESS_MODE_DISABLED
	queue_free()


func _draw() -> void:
	# Bright core is the hitbox; the translucent halo is only visual.
	var display = get_node("/root/DisplaySettings")
	if not display.reduce_effects:
		draw_circle(Vector2.ZERO, 10, Color(tint, 0.13))
		draw_colored_polygon(PackedVector2Array([Vector2(-13, 0), Vector2(-2, -5), Vector2(-2, 5)]), tint)
	if display.strong_danger_cues:
		draw_circle(Vector2.ZERO, 8, Color("#080d13"))
	draw_circle(Vector2.ZERO, 6.0, tint)
	draw_circle(Vector2(1, -1), 2.5, Color("#f1fcff"))
	if display.strong_danger_cues:
		draw_arc(Vector2.ZERO, HIT_RADIUS, 0, TAU, 24, Color.WHITE, 2.0, true)
