extends CanvasLayer

# Presentation reads game state; it never owns health, currency, or saves.
const INK := Color("#eff3f0")
const MUTED := Color("#9aaebc")
const GOLD := Color("#ffcf7a")
const LIGHT_COLORS: Array[Color] = [Color("#9ddacb"), Color("#ffcf7a"), Color("#ff997d")]

var main: Node2D
var lantern: Node2D
var panel: VBoxContainer
var scroll: ScrollContainer
var heading: Label
var subheading: Label
var health_text: Label
var health_bar: ProgressBar
var earnings: Label
var detail: Label
var brightness_box: VBoxContainer
var light_buttons: Array[Button] = []
var threat: Label
var controls: Label
var save_notice: Label
var refresh_elapsed: float = 0.0
var displayed_brightness: int = -1
var leaderboard: VBoxContainer


func _ready() -> void:
	layer = 4
	main = get_parent()
	lantern = main.get_node("Lantern")
	# One scrollable column keeps long recaps and save warnings from overlapping
	# placement controls on shorter windows.
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	panel = VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 12)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(panel)
	heading = _label(panel, 13, GOLD)
	subheading = _label(panel, 28, INK)
	health_text = _label(panel, 15, MUTED)
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size.y = 8
	health_bar.show_percentage = false
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_bar.add_theme_stylebox_override("background", _style(Color("#283744")))
	health_bar.add_theme_stylebox_override("fill", _style(GOLD))
	panel.add_child(health_bar)
	earnings = _label(panel, 30, GOLD)
	detail = _label(panel, 16, MUTED)
	brightness_box = VBoxContainer.new()
	brightness_box.add_theme_constant_override("separation", 8)
	panel.add_child(brightness_box)
	_label(brightness_box, 13, MUTED).text = "BRIGHTNESS / ENERGY PER SECOND"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	brightness_box.add_child(row)
	for index in range(3):
		var button := Button.new()
		button.text = "%s\n+%d /s" % [lantern.BRIGHTNESS_NAMES[index], int(lantern.ENERGY_RATES[index])]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 64
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 15)
		button.pressed.connect(lantern.set_brightness.bind(index))
		row.add_child(button)
		light_buttons.append(button)
	threat = _label(brightness_box, 16, INK)
	controls = _label(panel, 14, MUTED)
	save_notice = _label(panel, 14, Color("#ff997d"))
	leaderboard = preload("res://leaderboard_panel.gd").new()
	leaderboard.main = main
	panel.add_child(leaderboard)
	main.get_node("BuildController").bar.reparent(panel)
	get_viewport().size_changed.connect(_layout)
	_layout()
	refresh()


func _label(parent: Node, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	return style


func _layout() -> void:
	scroll.position = Vector2(main.get_arena_rect().end.x + 20.0, 24.0)
	scroll.size = Vector2(280, main.get_arena_rect().size.y - 48.0)


func _process(delta: float) -> void:
	# Ten UI updates per second are enough for numbers; world motion stays smooth.
	refresh_elapsed += delta
	if refresh_elapsed >= 0.1:
		refresh_elapsed = 0.0
		refresh()


func format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%02d:%02d" % [total / 60, total % 60]


func refresh() -> void:
	if is_instance_valid(leaderboard):
		leaderboard.refresh()
	var running: bool = lantern.running
	earnings.visible = running or not main.last_run.is_empty()
	health_bar.visible = running
	brightness_box.visible = running
	controls.visible = running
	save_notice.text = main.save_message
	save_notice.visible = not main.save_message.is_empty()
	if running:
		heading.text = "KEEP THE LIGHT ALIVE"
		subheading.text = format_time(lantern.elapsed)
		health_text.text = "HEALTH  %d / %d%s" % [int(ceil(lantern.health)), int(lantern.max_health), "  ·  DANGER" if lantern.health <= 25 else ""]
		health_bar.max_value = lantern.max_health
		health_bar.value = lantern.health
		health_bar.modulate = Color("#ff806e") if lantern.health <= 25 else Color.WHITE
		earnings.text = "+%d energy" % int(lantern.energy)
		detail.text = "Earned this run · banked when it ends\nIn reserve: %d energy" % int(main.banked_energy)
		var risk: Array[String] = ["LOW attraction", "MEDIUM attraction", "HIGH attraction"]
		threat.text = "%s\nNew enemies: %d hit%s to defeat" % [risk[lantern.brightness], int(main.current_enemy_health()), "" if main.current_enemy_health() == 1 else "s"]
		controls.text = "Move inside your turrets' reach.\n%s" % ("Left stick: move · Cross: brightness" if main.get_node("BuildController").using_controller else "WASD / arrows: move\nSpace: cycle brightness · or click above")
		if displayed_brightness != lantern.brightness:
			displayed_brightness = lantern.brightness
			for index in range(3):
				var selected := index == displayed_brightness
				var color := LIGHT_COLORS[index]
				light_buttons[index].add_theme_stylebox_override("normal", _style(color if selected else Color("#283744")))
				light_buttons[index].add_theme_stylebox_override("hover", _style(color.lightened(0.1)))
				light_buttons[index].add_theme_stylebox_override("pressed", _style(color.darkened(0.1)))
				light_buttons[index].add_theme_color_override("font_color", Color("#111b23") if selected else INK)
				light_buttons[index].add_theme_color_override("font_hover_color", Color("#111b23"))
				light_buttons[index].add_theme_color_override("font_pressed_color", Color("#111b23"))
	else:
		heading.text = ("THE LIGHT WENT OUT" if not main.last_run.is_empty() else "LITTLE LAST LIGHT") + " · v" + main.game_version
		subheading.text = "Prepare your next run" if not main.last_run.is_empty() else "Build your refuge"
		health_text.text = "Full health on every start"
		if not main.last_run.is_empty():
			earnings.text = "+%d energy earned" % int(main.last_run.energy)
			detail.text = "Survived %s  ·  Best %s%s" % [format_time(main.last_run.duration), format_time(main.best_time), "\nNew personal best" if main.last_run.new_best else ""]
		else:
			earnings.text = "%d energy" % int(main.banked_energy)
			detail.text = "Place your defense, then dodge within its reach.\nBest survival: %s" % format_time(main.best_time)
