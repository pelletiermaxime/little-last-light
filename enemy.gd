extends Node2D

@export var speed: float = 45.0

var target: Node2D


func _ready() -> void:
	add_to_group("enemies")
	queue_redraw()
	

func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return

	var distance: float = global_position.distance_to(target.global_position)

	# Stop at the edge of the lantern for now.
	if distance <= 20.0:
		return

	var step: float = minf(speed * delta, distance - 20.0)
	global_position = global_position.move_toward(
		target.global_position,
		step
	)


func _draw() -> void:
	# A little purple creature with two bright eyes.
	draw_circle(Vector2.ZERO, 10.0, Color("#826caa"))
	draw_circle(Vector2(-3.0, -2.0), 2.0, Color("#ffe0a3"))
	draw_circle(Vector2(3.0, -2.0), 2.0, Color("#ffe0a3"))
