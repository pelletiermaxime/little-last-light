extends "res://turrets/turret.gd"

const DURATION := 12.0
var remaining := DURATION

func _init() -> void:
	# Intentionally outside the permanent turrets group: no saving, refunds,
	# layout budget, upgrades or proximity bonus for this temporary helper.
	turret_type = "sentinel"
	attack_range = 260.0
	fire_interval = 0.35

func _process(delta: float) -> void:
	remaining = maxf(0.0, remaining - delta)
	if remaining <= 0.0:
		process_mode = Node.PROCESS_MODE_DISABLED
		queue_free()
		return
	super._process(delta)
	queue_redraw()

func _draw() -> void:
	super._draw()
	draw_rect(Rect2(-10, -10, 20, 20), Color("#ffe0a0"), false, 2)
	draw_arc(Vector2.ZERO, 20, -PI / 2, -PI / 2 + TAU * remaining / DURATION, 40, Color("#ffe0a0"), 2, true)
	var caption := "Sentinel · %ds" % ceili(remaining)
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(font, Vector2(-width / 2, 38), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#ffe0a0"))
