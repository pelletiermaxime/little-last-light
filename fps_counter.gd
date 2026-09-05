extends Label

# Keep diagnostics independent of the run: visible in preparation and combat.
var refresh_elapsed: float = 0.0


func _process(delta: float) -> void:
	refresh_elapsed += delta
	if refresh_elapsed < 1.0:
		return
	refresh_elapsed = 0.0
	# Refresh once per second so the counter stays readable and inexpensive.
	text = "FPS: %d" % Engine.get_frames_per_second()
