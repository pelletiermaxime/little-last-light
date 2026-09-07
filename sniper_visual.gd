extends Node2D
## Presentation only: a future sniper can drive these values from its combat state.

enum Design { LENSKEEPER, NEEDLE_OF_DAWN, WATCHLIGHT }

@export var design: Design = Design.LENSKEEPER
var charge: float = 1.0
var flash: float = 0.0
var aim_angle: float = -0.25
var shot_endpoint := Vector2(110, -28)
var show_shot: bool = true

const HOUSING := Color("#36566f")
const EDGE := Color("#7c9daa")
const LIGHT := Color("#fff0cc")


func _draw() -> void:
	var light := Color("#65717b").lerp(LIGHT, charge)
	draw_circle(Vector2.ZERO, 21.0, Color(1.0, 0.85, 0.55, 0.025 + charge * 0.055))
	match design:
		Design.LENSKEEPER:
			draw_set_transform(Vector2.ZERO, aim_angle)
			draw_circle(Vector2.ZERO, 11.0, Color("#203543"))
			draw_arc(Vector2.ZERO, 13.0, 0.45, PI - 0.45, 20, HOUSING, 4.0, true)
			draw_arc(Vector2.ZERO, 13.0, PI + 0.45, TAU - 0.45, 20, HOUSING, 4.0, true)
			draw_arc(Vector2.ZERO, 11.0, 0.6, PI - 0.6, 20, EDGE, 1.0, true)
			draw_arc(Vector2.ZERO, 11.0, PI + 0.6, TAU - 0.6, 20, EDGE, 1.0, true)
			draw_circle(Vector2.ZERO, 5.0, light)
			draw_line(Vector2(5, 0), Vector2(15, 0), light, 2.0, true)
			draw_line(Vector2(12, -3), Vector2(12, 3), EDGE, 1.5, true)
		Design.NEEDLE_OF_DAWN:
			draw_circle(Vector2(0, 7), 10.0, Color("#203543"))
			draw_arc(Vector2(0, 7), 10.0, 0.0, PI, 20, EDGE, 2.0, true)
			draw_colored_polygon(PackedVector2Array([Vector2(0, -18), Vector2(8, 0), Vector2(0, 11), Vector2(-8, 0)]), HOUSING)
			draw_colored_polygon(PackedVector2Array([Vector2(0, -15), Vector2(5, 0), Vector2(0, 8)]), light)
			draw_line(Vector2(0, 8), Vector2(0, lerpf(5.0, -15.0, charge)), LIGHT, 1.0, true)
			draw_circle(Vector2(0, -15), 1.0 + 1.5 * charge, light)
		Design.WATCHLIGHT:
			draw_set_transform(Vector2.ZERO, aim_angle)
			draw_colored_polygon(PackedVector2Array([Vector2(-12, -8), Vector2(5, -12), Vector2(13, -6), Vector2(13, 6), Vector2(5, 12), Vector2(-12, 8)]), HOUSING)
			draw_line(Vector2(-10, -7), Vector2(5, -10), EDGE, 1.0, true)
			draw_rect(Rect2(-5, -6, 12, 12), Color("#17232d"))
			var opening := lerpf(0.75, 4.0, charge)
			draw_rect(Rect2(-4, -opening, 13, opening * 2.0), light)
			draw_line(Vector2(-6, -opening - 1), Vector2(10, -opening - 1), EDGE, 2.0, true)
			draw_line(Vector2(-6, opening + 1), Vector2(10, opening + 1), EDGE, 2.0, true)
			draw_line(Vector2(14, -4), Vector2(14, 4), light, 2.0, true)
	draw_set_transform(Vector2.ZERO)
	if flash > 0.0:
		draw_circle(Vector2.ZERO, 7.0, Color(1.0, 0.94, 0.8, flash))
		if show_shot:
			# Every design uses exactly the same instantaneous single-target flash.
			draw_line(Vector2.ZERO, shot_endpoint, Color(1.0, 0.94, 0.8, flash), 2.0, true)
			draw_circle(shot_endpoint, 4.0, Color(1.0, 0.94, 0.8, flash))
			for index in range(4):
				var direction := Vector2.from_angle(index * PI / 2.0 + 0.4)
				draw_line(shot_endpoint + direction * 6.0, shot_endpoint + direction * 10.0, Color(1.0, 0.85, 0.65, flash), 1.0, true)
