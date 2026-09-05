extends Node2D

const ENEMY_SCENE: PackedScene = preload("res://enemy.tscn")
const SPAWN_INTERVALS: Array[float] = [4.0, 2.0, 0.8]

@onready var lantern: Node2D = $Lantern

var spawn_progress: float = 0.0


func _ready() -> void:
	# Start beside the lantern, then stay here when the lantern moves.
	$Turret.position = lantern.position + Vector2(80.0, 0.0)


func _process(delta: float) -> void:
	var interval: float = SPAWN_INTERVALS[lantern.brightness]
	spawn_progress += delta / interval

	if spawn_progress >= 1.0:
		spawn_progress -= 1.0
		_spawn_enemy()


func _spawn_enemy() -> void:
	var enemy := ENEMY_SCENE.instantiate() as Node2D
	enemy.target = lantern

	add_child(enemy)
	enemy.global_position = _random_edge_position()


func _random_edge_position() -> Vector2:
	var screen_size: Vector2 = get_viewport_rect().size
	var margin: float = 16.0
	var edge: int = randi_range(0, 3)

	match edge:
		0: # Left
			return Vector2(
				margin,
				randf_range(margin, screen_size.y - margin)
			)
		1: # Right
			return Vector2(
				screen_size.x - margin,
				randf_range(margin, screen_size.y - margin)
			)
		2: # Top
			return Vector2(
				randf_range(margin, screen_size.x - margin),
				margin
			)
		_: # Bottom
			return Vector2(
				randf_range(margin, screen_size.x - margin),
				screen_size.y - margin
			)
