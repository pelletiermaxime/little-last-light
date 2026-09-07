extends SceneTree


func _initialize() -> void:
	# Avoid display preference writes as well as game save writes in this visual study.
	root.get_node("DisplaySettings").settings_path = "/tmp/lll-sniper-display-%d.cfg" % OS.get_process_id()
	root.get_node("DisplaySettings").windowed_size = Vector2i(1152, 760)
	root.get_node("DisplaySettings").display_mode = "Windowed"
	root.get_node("DisplaySettings").windowed_maximized = false
	call_deferred("launch")


func launch() -> void:
	root.title = "Little Last Light — Sniper visual study"
	var scene := preload("res://previews/sniper_gallery.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
