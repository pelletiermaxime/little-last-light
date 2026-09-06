extends RefCounted

static func panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#17232def")
	style.border_color = Color("#3b5260")
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(20)
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 12
	return style


static func button(button: Button, primary: bool = false) -> void:
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size.y = 44
	button.add_theme_font_size_override("font_size", 16)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(8)
		style.set_content_margin_all(10)
		style.bg_color = Color("#ffcf7a") if primary else Color("#2a3e4b")
		if state == "hover":
			style.bg_color = style.bg_color.lightened(0.12)
		elif state == "pressed":
			style.bg_color = style.bg_color.darkened(0.12)
		elif state == "disabled":
			style.bg_color = Color("#23313a")
		elif state == "focus":
			style.bg_color = Color.TRANSPARENT
			style.set_border_width_all(3 if primary else 2)
			style.border_color = Color("#17212b") if primary else Color("#c4eeef")
			if primary:
				style.set_expand_margin_all(-4)
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color("#17212b") if primary else Color("#e8f1f1"))
	button.add_theme_color_override("font_focus_color", Color("#17212b") if primary else Color("#e8f1f1"))
	button.add_theme_color_override("font_hover_color", Color("#17212b") if primary else Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color("#17212b") if primary else Color.WHITE)


static func label(text: String, size: int, color: Color = Color("#e8f1f1")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


static func fit_card(card: Control, viewport_size: Vector2, left_aligned: bool = false) -> void:
	# Menus have finite pages. Scale only if a short/narrow window needs it.
	var available := (viewport_size - Vector2(32, 32)).max(Vector2.ONE)
	var factor := minf(1.0, minf(available.x / maxf(card.size.x, 1.0), available.y / maxf(card.size.y, 1.0)))
	card.scale = Vector2.ONE * factor
	card.position = (viewport_size - card.size * factor) / 2.0
	if left_aligned:
		card.position.x = 16
