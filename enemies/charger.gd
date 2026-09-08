extends "res://enemies/enemy.gd"

enum State { APPROACH, WARNING, CHARGING, RECOVERY }

@export var approach_speed: float = 60.0
@export var trigger_distance: float = 190.0
@export var warning_duration: float = 0.9
@export var locked_warning_duration: float = 0.4
@export var warning_turn_speed: float = PI / 2.0
@export var charge_speed: float = 380.0
@export var charge_duration: float = 0.7
@export var recovery_duration: float = 1.0
@export var charge_damage: float = 12.0

var state: State = State.APPROACH
var state_remaining: float = 0.0


func _create_body() -> void:
	# Chargers draw their own animated warning and diamond, not the basic body.
	pass


func _ready() -> void:
	super._ready()
	add_to_group("chargers")


func _process(delta: float) -> void:
	if not is_instance_valid(target) or delta <= 0.0 or is_queued_for_deletion():
		return
	var movement_time := _consume_slow(delta)
	if state == State.APPROACH:
		var distance := global_position.distance_to(target.global_position)
		heading = global_position.direction_to(target.global_position)
		if heading.is_zero_approx():
			heading = Vector2.DOWN
		if distance > trigger_distance:
			global_position += heading * minf(approach_speed * movement_time, distance - trigger_distance)
			queue_redraw()
			return
		# Track slowly first, then hold the final aim before charging.
		state = State.WARNING
		state_remaining = warning_duration

	# Split long frames at state boundaries so warning time is never charge time.
	var remaining := delta
	while remaining > 0.0:
		var step := minf(remaining, state_remaining)
		if state == State.WARNING and state_remaining > locked_warning_duration:
			# Only the tracking part of this step can turn, even on a long frame.
			var tracking_step := minf(step, state_remaining - locked_warning_duration)
			var desired := global_position.direction_to(target.global_position)
			if not desired.is_zero_approx():
				var max_turn := warning_turn_speed * tracking_step
				heading = heading.rotated(clampf(heading.angle_to(desired), -max_turn, max_turn)).normalized()
		if state == State.CHARGING:
			var movement := heading * charge_speed * assist_movement_factor * step
			var overlapping := global_position.distance_to(target.global_position) <= CONTACT_DISTANCE
			var fraction := 0.0 if overlapping else _first_contact_fraction(movement)
			global_position += movement * fraction
			if overlapping or fraction < 1.0 or global_position.distance_to(target.global_position) <= CONTACT_DISTANCE:
				# A charge hits once and stops. Recovery gives the player space.
				state = State.RECOVERY
				state_remaining = recovery_duration
				target.take_damage(charge_damage)
				queue_redraw()
				return
		remaining -= step
		state_remaining = maxf(0.0, state_remaining - step)
		if state_remaining <= 0.0:
			match state:
				State.WARNING:
					state = State.CHARGING
					state_remaining = charge_duration
				State.CHARGING:
					state = State.RECOVERY
					state_remaining = recovery_duration
				State.RECOVERY:
					state = State.APPROACH
					break
	queue_redraw()


func _draw() -> void:
	var forward := heading if not heading.is_zero_approx() else Vector2.DOWN
	var side := forward.orthogonal()
	var color := Color("#ffad62")
	if state == State.WARNING:
		var progress := 1.0 - state_remaining / maxf(warning_duration, 0.001)
		var end := forward * charge_speed * assist_movement_factor * charge_duration
		var locked := state_remaining <= locked_warning_duration
		if get_node("/root/DisplaySettings").strong_danger_cues:
			draw_line(forward * 18, end, Color("#080d13"), 7.0, true)
			draw_dashed_line(forward * 18, end, Color.WHITE, 3.0, 12.0, true)
			draw_line(end - forward * 14 + side * 9, end, Color.WHITE, 3.0, true)
			draw_line(end - forward * 14 - side * 9, end, Color.WHITE, 3.0, true)
		draw_line(Vector2.ZERO, end, Color(1.0, 0.65, 0.3, 0.25 if locked else 0.12), CONTACT_DISTANCE * 2.0)
		if locked:
			draw_line(forward * 18.0, end, Color("#fff1cb"), 3.0, true)
		else:
			draw_dashed_line(forward * 18.0, end, Color("#ffd78c"), 2.0, 9.0)
		draw_arc(Vector2.ZERO, 19.0, -PI / 2.0, -PI / 2.0 + TAU * progress, 48, Color("#ffe6ac"), 3.0, true)
		color = color.lerp(Color("#fff1cb"), progress)
	elif state == State.CHARGING:
		draw_line(-forward * 30.0, Vector2.ZERO, Color("#ffcf7a"), 5.0, true)
	elif state == State.RECOVERY:
		color = Color("#846951")
	# A pointed diamond is distinct from the round purple basic enemies.
	draw_colored_polygon(PackedVector2Array([forward * 15.0, side * 11.0, -forward * 12.0, -side * 11.0]), color)
	draw_circle(forward * 5.0, 3.0, Color("#362939"))
	if max_health > 1.0:
		draw_rect(Rect2(-12, -26, 24, 3), Color("#35414e"))
		draw_rect(Rect2(-12, -26, 24 * health / max_health, 3), Color("#ffcf7a"))
