extends VBoxContainer

const STYLE = preload("res://ui/ui_style.gd")
var game: Node2D
var rows: Dictionary = {}
var progress: Label
var status: Label
var retry_button: Button


func setup(owner_game: Node2D) -> void:
	game = owner_game
	add_theme_constant_override("separation", 12)
	progress = STYLE.label("", 16, Color("#ffd17b"))
	add_child(progress)
	for entry in game.achievements.CATALOG:
		var row := STYLE.label("", 15)
		add_child(row)
		rows[entry.id] = row
	status = STYLE.label("", 12, Color("#bfd0d8"))
	add_child(status)
	retry_button = Button.new()
	retry_button.text = "Sync achievements"
	retry_button.custom_minimum_size.y = 44
	retry_button.pressed.connect(game.achievements.retry_sync)
	add_child(retry_button)
	game.achievements.changed.connect(refresh)
	refresh()


func refresh() -> void:
	var tracker: Node = game.achievements
	var earned: Array = tracker.data.get("unlocked", [])
	progress.text = "%d / %d unlocked" % [earned.size(), tracker.CATALOG.size()]
	for entry in tracker.CATALOG:
		var unlocked: bool = entry.id in earned
		rows[entry.id].text = "%s · %s\n%s" % ["Unlocked" if unlocked else "Locked", entry.name, entry.description]
		rows[entry.id].modulate = Color("#ffd17b") if unlocked else Color("#bfd0d8")
	status.text = tracker.status_text()
	if not game.leaderboard_eligible():
		status.text += "\nAssisted progress cannot earn new achievements."
	retry_button.disabled = tracker.sending or tracker.api_url.is_empty() or not tracker.readable or not tracker.data.get("started", false)
