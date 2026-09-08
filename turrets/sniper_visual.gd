extends Node2D
## Watchlight presentation, driven by its combat state.
var charge: float = 1.0
var flash: float = 0.0
var aim_angle: float = -0.25
var shot_endpoint := Vector2(110, -28)

const HOUSING := Color("#36566f")
const EDGE := Color("#7c9daa")
const LIGHT := Color("#fff0cc")


func _draw() -> void:
	var light := Color("#65717b").lerp(LIGHT, charge)
	draw_circle(Vector2.ZERO, 21.0, Color(1.0, 0.85, 0.55, 0.025 + charge * 0.055))
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
		draw_line(Vector2.ZERO, shot_endpoint, Color(1.0, 0.94, 0.8, flash), 2.0, true)
		draw_circle(shot_endpoint, 4.0, Color(1.0, 0.94, 0.8, flash))
		for index in range(4):
			var direction := Vector2.from_angle(index * PI / 2.0 + 0.4)
			draw_line(shot_endpoint + direction * 6.0, shot_endpoint + direction * 10.0, Color(1.0, 0.85, 0.65, flash), 1.0, true)
