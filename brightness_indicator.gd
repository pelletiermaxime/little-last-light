extends Button

var prompt_icon: Texture2D

var level: int = 0:
	set(value):
		level = value
		queue_redraw()


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_theme_font_size_override("font_size", 14)
	add_theme_color_override("font_color", Color("#d5d9cc"))
	add_theme_color_override("font_hover_color", Color("#ffcf7a"))
	add_theme_color_override("font_pressed_color", Color("#ffcf7a"))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	tooltip_text = "Brightness · Click / Space to cycle"


func _draw() -> void:
	if prompt_icon != null:
		draw_texture_rect(prompt_icon, Rect2(-28, 3, 24, 24), false)
	# One, two, or three lit segments remain readable without relying on color.
	for index in range(3):
		var height := 5.0 + index * 4.0
		draw_rect(Rect2(4 + index * 17, 23 - height, 12, height), Color("#ffcf7a") if index <= level else Color("#52606b"))
