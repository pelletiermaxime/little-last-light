extends "res://turret.gd"

const FLIGHT_TIME := 0.45
const SPLASH_RADIUS := 65.0
const FLASH_TIME := 0.25
const AMBER := Color("#ffc16b")
var pending_time: float = 0.0
var launched_damage: float = 0.0


func _init() -> void:
	turret_type = "ember"
	attack_range = 220.0
	fire_interval = 3.0
	damage = 1.0


func reset_attack() -> void:
	super.reset_attack()
	pending_time = 0.0
	launched_damage = 0.0


func _process(delta: float) -> void:
	var was_animating := pending_time > 0.0 or shot_time > 0.0
	var was_boosted := boosted
	boosted = in_boost_range()
	var multiplier: float = get_parent().proximity_multiplier() if boosted else 1.0
	cooldown = maxf(0.0, cooldown - delta * multiplier)
	shot_time = maxf(0.0, shot_time - delta)
	if pending_time > 0.0:
		pending_time = maxf(0.0, pending_time - delta)
		if pending_time == 0.0:
			_release_attack()
	if cooldown == 0.0 and pending_time == 0.0:
		var target := _find_target()
		if target != null:
			# Snapshot the landing point, so movement or a killed target cannot steer the coal.
			shot_endpoint = target.global_position
			# Damage belongs to the launched coal, even if the lantern moves during flight.
			launched_damage = damage * multiplier
			pending_time = FLIGHT_TIME
			cooldown = fire_interval
		else:
			cooldown = IDLE_SEARCH_INTERVAL
	if was_animating or pending_time > 0.0 or shot_time > 0.0 or boosted or was_boosted:
		queue_redraw()


func _release_attack() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.is_queued_for_deletion() or enemy.health <= 0.0:
			continue
		if enemy.global_position.distance_squared_to(shot_endpoint) <= SPLASH_RADIUS * SPLASH_RADIUS:
			enemy.take_damage(launched_damage)
	shot_time = FLASH_TIME
	get_node("/root/GameAudio").play(&"shot")


func _draw() -> void:
	_draw_boost()
	draw_arc(Vector2.ZERO, attack_range, 0.0, TAU, 64, Color(1.0, 0.7, 0.35, 0.12), 1.0, true)
	var progress := 1.0 - pending_time / FLIGHT_TIME
	var flash := shot_time / FLASH_TIME
	var landing := to_local(shot_endpoint)
	if pending_time > 0.0:
		# Broken perimeter is the damage footprint, not acquisition range.
		for segment in range(12):
			var angle := TAU * segment / 12.0
			draw_arc(landing, SPLASH_RADIUS, angle, angle + TAU / 18.0, 6, Color(1.0, 0.75, 0.4, 0.55), 1.5, true)
		var coal := landing * progress + Vector2.UP * sin(progress * PI) * 40.0
		draw_circle(coal, 9.0, Color(1.0, 0.6, 0.15, 0.12))
		draw_circle(coal, 4.0, AMBER)
		draw_circle(coal, 1.5, Color("#fff3d4"))
	if flash > 0.0:
		draw_circle(landing, SPLASH_RADIUS, Color(1.0, 0.7, 0.3, flash * 0.15))
		draw_arc(landing, SPLASH_RADIUS, 0.0, TAU, 48, Color(1.0, 0.85, 0.6, flash), 2.0, true)
		for ray in range(8):
			var direction := Vector2.from_angle(TAU * ray / 8.0)
			draw_line(landing + direction * 12.0, landing + direction * (20.0 + 25.0 * (1.0 - flash)), Color(1.0, 0.8, 0.4, flash), 2.0, true)
	draw_circle(Vector2.ZERO, 13.0, Color("#594337"))
	draw_arc(Vector2(0, -3), 11.0, 0.0, PI, 20, AMBER, 3.0, true)
	draw_line(Vector2(-12, -3), Vector2(12, -3), AMBER, 2.0, true)
	draw_circle(Vector2(0, -4), 4.0, Color("#fff0c4"))
