extends "res://turret.gd"

const PULSE_INTERVAL: float = 3.0
const PULSE_RANGE: float = 175.0
const SLOW_FACTOR: float = 0.55
const SLOW_DURATION: float = 1.3
const FLASH_DURATION: float = 0.45
var slow_factor: float = SLOW_FACTOR
var slow_duration: float = SLOW_DURATION


func _init() -> void:
	turret_type = "pulse"
	attack_range = PULSE_RANGE
	fire_interval = PULSE_INTERVAL
	damage = 0.0


func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	var was_pulsing := shot_time > 0.0
	shot_time = maxf(0.0, shot_time - delta)
	if cooldown <= 0.0:
		var hit := false
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy.is_queued_for_deletion() or enemy.health <= 0.0:
				continue
			if global_position.distance_squared_to(enemy.global_position) <= attack_range * attack_range:
				enemy.apply_slow(slow_factor, slow_duration)
				hit = true
		cooldown = fire_interval if hit else IDLE_SEARCH_INTERVAL
		if hit:
			shot_time = FLASH_DURATION
			get_node("/root/GameAudio").play(&"shot")
	if was_pulsing or shot_time > 0.0:
		queue_redraw()


func _draw() -> void:
	draw_arc(Vector2.ZERO, attack_range, 0.0, TAU, 64, Color(0.4, 1.0, 0.75, 0.18), 1.0, true)
	draw_circle(Vector2.ZERO, 13.0, Color("#285c51"))
	draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 24, Color("#8ff0c4"), 3.0, true)
	draw_circle(Vector2.ZERO, 3.0, Color("#d2ffe9"))
	if shot_time > 0.0:
		var progress := 1.0 - shot_time / FLASH_DURATION
		draw_arc(Vector2.ZERO, lerpf(15.0, attack_range, progress), 0.0, TAU, 64, Color(0.55, 1.0, 0.8, 1.0 - progress), 3.0, true)
