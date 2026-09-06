extends Label

var refresh_elapsed: float = 0.0


func _ready() -> void:
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	position = Vector2(12, get_viewport_rect().size.y - 28)


func _process(delta: float) -> void:
	refresh_elapsed += delta
	if refresh_elapsed < 1.0:
		return
	refresh_elapsed = 0.0
	text = "FPS: %d" % Engine.get_frames_per_second()
