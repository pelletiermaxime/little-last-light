extends CanvasLayer

const STYLE = preload("res://ui/ui_style.gd")
var game: Node2D
var panel: PanelContainer
var label: Label
var queue: Array[String] = []
var remaining := 0.0


func setup(owner_game: Node2D) -> void:
	game = owner_game
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", STYLE.panel())
	add_child(panel)
	label = STYLE.label("", 16, Color("#ffd17b"))
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	panel.add_child(label)
	panel.hide()
	game.achievements.unlocked.connect(show_unlock)
	get_viewport().size_changed.connect(_layout)


func show_unlock(id: String) -> void:
	queue.append(id)
	if remaining <= 0.0:
		_next()


func _next() -> void:
	if queue.is_empty():
		panel.hide()
		return
	var id: String = queue.pop_front()
	for entry in game.achievements.CATALOG:
		if entry.id == id:
			label.text = "ACHIEVEMENT UNLOCKED\n%s\n%s" % [entry.name, entry.description]
	remaining = 4.0
	panel.show()
	_layout()
	game.get_node("/root/GameAudio").play(&"upgrade")


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	panel.size = Vector2(minf(340.0, size.x - 32.0), 0)
	panel.position = Vector2(size.x - panel.size.x - 16.0, 16.0)


func _process(delta: float) -> void:
	if remaining <= 0.0:
		return
	remaining -= delta
	if remaining <= 0.0:
		_next()
