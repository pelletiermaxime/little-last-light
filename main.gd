extends Node2D

const ENEMY_SCENE: PackedScene = preload("res://enemy.tscn")
const SPAWN_INTERVALS: Array[float] = [4.0, 2.0, 0.8]

@onready var lantern: Node2D = $Lantern

var spawn_progress: float = 0.0
var defeat_screen: Control
var defeat_label: Label
var restart_button: Button


func _ready() -> void:
	# Start beside the lantern, then stay here when the lantern moves.
	$Turret.position = lantern.position + Vector2(80.0, 0.0)
	lantern.died.connect(_on_lantern_died)
	_create_defeat_screen()


func _create_defeat_screen() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	# Only this menu stays interactive when the game is paused.
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	defeat_screen = Control.new()
	layer.add_child(defeat_screen)
	defeat_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.05, 0.9)
	defeat_screen.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	defeat_screen.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	center.add_child(column)
	defeat_label = Label.new()
	defeat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	defeat_label.add_theme_font_size_override("font_size", 28)
	column.add_child(defeat_label)
	restart_button = Button.new()
	restart_button.text = "Try again (R)"
	restart_button.custom_minimum_size = Vector2(240, 52)
	restart_button.add_theme_font_size_override("font_size", 22)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_R
	restart_button.shortcut = Shortcut.new()
	restart_button.shortcut.events = [key]
	restart_button.pressed.connect(_restart_run)
	column.add_child(restart_button)
	defeat_screen.hide()


func _on_lantern_died() -> void:
	defeat_label.text = "The light went out\n\nSurvived %d seconds" % int(lantern.elapsed)
	defeat_screen.show()
	restart_button.grab_focus()
	get_tree().paused = true


func _restart_run() -> void:
	# Reloading creates fresh health, energy, enemies, and turret cooldowns.
	get_tree().paused = false
	get_tree().reload_current_scene()


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
