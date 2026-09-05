# Milestone 5: clarity and feel

This milestone makes the existing survival loop easier to read. It introduces no new turret types, economy changes, enemy tuning, FPS limits, or save format changes. The starting point is source commit `8e88823`; the approved M5 checkpoint is preserved by the `milestone-5` Git tag.

## What to try

Start a run and watch the health bar, timer, and large energy total. Click Low, Medium, or High to choose brightness directly; Space or the gamepad's Cross button still cycles it. Compare the selected button, income label, attraction label, glow size, and the one/two/three rays on the lantern. Take a hit and look for the red body flash and contact ring. Below 25 health, the HUD includes an explicit DANGER warning.

After death, the recap shows how long you survived, how much that attempt earned, your best time, and whether this was a new personal best. The preparation controls show your available balance and whether you can afford the next turret. Buy one and watch the remaining amount update using the next, more expensive price. Start again to return to the live HUD.

The sidebar keeps the same 320-pixel width as M4, so saved layouts, turret coverage, movement bounds, and enemy spawn edges behave as before. Long content can scroll vertically inside the sidebar. This matters when a save warning or controller instructions take more space: they must not overlap the buttons or disappear below the window.

## One owner for the interface

Previously, `Lantern` created a status Label and `BuildController` created another overview below it at a fixed vertical position. Both assembled paragraphs of text. This made the hierarchy weak and allowed long text to collide with controls.

The new `GameHUD` CanvasLayer owns the presentation. Its scroll container holds one VBoxContainer, which stacks labels, the health bar, the three brightness buttons, and the existing preparation controls. `BuildController` still creates those controls and handles their actions, but GameHUD reparents its `bar` into the shared column. Reparenting changes where a node lives and is drawn; its connected button signals continue to call the same controller methods.

The layer order is background (2), HUD (4), placement tooltip (5), and FPS counter (10). Decorative labels ignore mouse input. Brightness buttons consume clicks in the sidebar; the arena remains the placement surface. The HUD's scroll container determines its position from `get_arena_rect().end.x`, keeping one definition of the arena boundary.

`GameHUD` is a view of the game, not a second game state. It reads health and earnings from Lantern, banked energy and results from Main, and input-device mode and turret cost from BuildController. It does not spend money or write saves.

## Updating the HUD without doing unnecessary work

The HUD accumulates `delta` and refreshes ordinary text ten times per second. That is frequent enough for readable numbers without rebuilding text every rendered frame. Movement and combat still run at their existing update rates. Discrete events such as taking damage, selecting brightness, starting, and dying call Lantern's `_update_status()` to refresh immediately.

`_update_status()` is now a small bridge to `GameHUD.refresh()`. It checks that the HUD exists and is ready because Godot runs child `_ready()` methods before the parent's. GameHUD obtains Lantern with `get_node()` rather than relying on Main's `@onready` variable during its own startup.

Brightness button styles update only when the selected index changes. The FPS counter remains its own once-per-second overlay. These changes reduce repeated presentation work; they are not a measured CPU/GPU optimization or a frame-rate cap.

## Brightness has one entry point

`Lantern.set_brightness(level)` checks that a run is active and the index is valid. It then assigns the level, refreshes the HUD, and requests a redraw. Both keyboard/controller cycling and the three sidebar buttons call this method, preventing their behavior from drifting apart.

The income labels read the existing `ENERGY_RATES` array: 1, 3, and 6 energy per second. Attraction labels describe the relative effect of the chosen brightness. Enemy pressure still increases with elapsed time even on Low; Low is not a safe idle mode. The selected button uses a filled background, while the lantern's glow and ray count give an additional visible cue in the arena.

The health bar uses the actual current and maximum health values. The number is rounded upward exactly as before, so a tiny positive amount does not display as zero. A red body flash reinforces damage. That flash now decays even during preparation; it previously stayed red after a fatal hit because Lantern stopped processing feedback when the run ended. The timer and earnings still stop during preparation.

## Capture the result before clearing earnings

On death, Main already banked `lantern.energy` and then set it to zero. A recap that simply read that field afterward would report zero earned.

M5 captures an in-memory `last_run` Dictionary first:

```gdscript
last_run = {
    "duration": lantern.elapsed,
    "energy": lantern.energy,
    "new_best": lantern.elapsed > best_time,
}
```

The existing best-time update and banking happen afterward. For example, 5 energy in reserve plus 28.4 earned produces 33.4 available, while the recap displays 28 earned. Buying a 20-energy turret leaves 13.4; the next turret costs 30, so the interface says 17 more are needed. Rounding up the shortage avoids promising a purchase that the player cannot yet afford.

`last_run` is session-only. The persistent version-1 JSON still contains banked/current saved energy, best time, and normalized turret positions. Reopening shows preparation and the saved best, without inventing a recap for a run whose full result was not stored. An equal survival time does not count as a new record. Starting again switches to live values; a later death replaces the last result.

## Verification and limits

`tests/check_hud.gd` checks brightness selection and preparation lockout, income labels, time formatting, low-health feedback, banking/recap ordering, personal bests, affordability after a purchase, save warning visibility, hit-flash decay, the shared scroll column, and fresh values after restart. It uses a disposable `/tmp` save and removes it afterward.

The existing health, construction, run/save, difficulty, and controller regression tests remain relevant. The difficulty test now locates the new HUD scroll container when checking that sidebar coordinates are outside the arena; gameplay assertions are unchanged.

Visual checks cover preparation, a run at High brightness and low health, a result with a personal best, and turret placement at 1152 × 648. All six test suites passed, and the web export was checked in a browser. Automated scenarios establish behavior; the approved playtest establishes this milestone's checkpoint. The browser demo is published separately from source.

## Code snapshots

The snapshots below preserve the M5 implementation for learning even after later milestones change these files. Main's other methods and the save schema remain as documented in M4; its new `last_run` field and death capture are explained above.


<details>
<summary>game_hud.gd — complete M5 snapshot</summary>

```gdscript
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
		heading.text = "THE LIGHT WENT OUT" if not main.last_run.is_empty() else "LITTLE LAST LIGHT"
		subheading.text = "Prepare your next run" if not main.last_run.is_empty() else "Build your refuge"
		health_text.text = "Full health on every start"
		if not main.last_run.is_empty():
			earnings.text = "+%d energy earned" % int(main.last_run.energy)
			detail.text = "Survived %s  ·  Best %s%s" % [format_time(main.last_run.duration), format_time(main.best_time), "\nNew personal best" if main.last_run.new_best else ""]
		else:
			earnings.text = "%d energy" % int(main.banked_energy)
			detail.text = "Place your defense, then dodge within its reach.\nBest survival: %s" % format_time(main.best_time)
```

</details>

<details>
<summary>lantern.gd — complete M5 snapshot</summary>

```gdscript
extends Node2D

signal died

const BRIGHTNESS_NAMES: Array[String] = ["Low", "Medium", "High"]
const ENERGY_RATES: Array[float] = [1.0, 3.0, 6.0]
const LIGHT_SCALES: Array[float] = [1.0, 1.4, 1.9]

@export var move_speed: float = 220.0
@export var max_health: float = 100.0

var health: float
var running: bool = false
var hit_flash: float = 0.0

var elapsed: float = 0.0
var brightness: int = 0
var energy: float = 0.0



func _ready() -> void:
	health = max_health
	get_viewport().size_changed.connect(_keep_inside_viewport)
	_center_in_viewport()



func _process(delta: float) -> void:
	# Let the last hit fade after death instead of freezing a red flash in prep.
	if hit_flash > 0.0:
		hit_flash = maxf(0.0, hit_flash - delta)
		queue_redraw()
	if not running:
		return
	elapsed += delta
	energy += ENERGY_RATES[brightness] * delta

	queue_redraw()


func take_damage(amount: float) -> void:
	if not running or health <= 0.0 or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	hit_flash = 0.15
	_update_status()
	queue_redraw()
	if health <= 0.0:
		died.emit()


func _physics_process(delta: float) -> void:
	if not running:
		return
	# get_vector keeps diagonal movement the same speed as straight movement.
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	position += direction * move_speed * delta
	_keep_inside_viewport()


func _keep_inside_viewport() -> void:
	var screen_size: Vector2 = get_parent().get_arena_rect().size
	var margin := Vector2.ONE * 16.0
	position = position.clamp(margin, (screen_size - margin).max(margin))


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event.is_action_pressed("cycle_brightness"):
		set_brightness((brightness + 1) % BRIGHTNESS_NAMES.size())
		get_viewport().set_input_as_handled()


func _center_in_viewport() -> void:
	position = get_parent().get_arena_rect().get_center()


func set_brightness(level: int) -> void:
	if not running or level < 0 or level >= BRIGHTNESS_NAMES.size():
		return
	brightness = level
	_update_status()
	queue_redraw()


func _update_status() -> void:
	var hud := get_parent().get_node_or_null("GameHUD")
	if hud != null and hud.is_node_ready():
		hud.refresh()


func _draw() -> void:
	var pulse: float = 1.0 + sin(elapsed * 2.0) * 0.08
	var glow_size: float = pulse * LIGHT_SCALES[brightness]

	draw_circle(Vector2.ZERO, 70.0 * glow_size, Color(1.0, 0.65, 0.2, 0.04))
	draw_circle(Vector2.ZERO, 48.0 * glow_size, Color(1.0, 0.65, 0.2, 0.08))
	draw_circle(Vector2.ZERO, 30.0 * glow_size, Color(1.0, 0.65, 0.2, 0.16))

	draw_circle(Vector2.ZERO, 12.0 * pulse, Color("#ffbd59"))
	draw_circle(Vector2.ZERO, 6.0 * pulse, Color("#fff2cf"))
	# One, two, or three rays make brightness readable without relying on color.
	for index in range(brightness + 1):
		var angle := -PI / 2.0 + (index - brightness / 2.0) * 0.45
		draw_line(Vector2.from_angle(angle) * 19.0, Vector2.from_angle(angle) * 25.0, Color("#ffe0a0"), 2.0, true)
	if hit_flash > 0.0:
		draw_circle(Vector2.ZERO, 14.0, Color(1.0, 0.35, 0.3, 0.65))
		draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 32, Color("#ff6b6b"), 3.0, true)
```

</details>

<details>
<summary>build_controller.gd — complete M5 snapshot</summary>

```gdscript
extends Node2D

const TURRET_SCENE: PackedScene = preload("res://turret.tscn")
const BASE_TURRET_COST: float = 20.0
const EXTRA_TURRET_COST: float = 10.0
const PLACEMENT_MARGIN: float = 20.0
const TURRET_SPACING: float = 36.0

@onready var lantern: Node2D = get_parent().get_node("Lantern")
@onready var main: Node2D = get_parent()

var placing: bool = false
var preview: Node2D
var build_button: Button
var cancel_button: Button
var hint: Label
var overview: Label
var start_button: Button
var bar: VBoxContainer
var selected_turret: Node2D
var placement_hint: Label
var sidebar: ColorRect
var controller_cursor: Vector2
var using_controller: bool = false
const CURSOR_SPEED: float = 360.0


func _ready() -> void:
	# Preparation uses an explicit phase; it does not pause the scene tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	preview = TURRET_SCENE.instantiate()
	preview.process_mode = Node.PROCESS_MODE_DISABLED
	preview.remove_from_group("turrets")
	add_child(preview)
	preview.hide()
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	# Background sits below the lantern HUD; controls stay above it.
	var background_layer := CanvasLayer.new()
	background_layer.layer = 2
	add_child(background_layer)
	sidebar = ColorRect.new()
	sidebar.color = Color("#18242e")
	background_layer.add_child(sidebar)
	sidebar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	placement_hint = Label.new()
	var tooltip_style := StyleBoxFlat.new()
	tooltip_style.bg_color = Color(0.025, 0.035, 0.05, 0.97)
	tooltip_style.content_margin_left = 8
	tooltip_style.content_margin_right = 8
	tooltip_style.content_margin_top = 5
	tooltip_style.content_margin_bottom = 5
	placement_hint.add_theme_stylebox_override("normal", tooltip_style)
	placement_hint.add_theme_font_size_override("font_size", 17)
	placement_hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	placement_hint.add_theme_constant_override("shadow_offset_x", 2)
	placement_hint.add_theme_constant_override("shadow_offset_y", 2)
	placement_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(placement_hint)
	placement_hint.hide()
	bar = VBoxContainer.new()
	layer.add_child(bar)
	bar.add_theme_constant_override("separation", 14)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overview = Label.new()
	overview.add_theme_font_size_override("font_size", 18)
	overview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bar.add_child(overview)
	overview.add_theme_color_override("font_color", Color("#ffcf7a"))
	hint = Label.new()
	hint.add_theme_font_size_override("font_size", 18)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bar.add_child(hint)
	hint.add_theme_color_override("font_color", Color("#a8bbc8"))
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(buttons)
	build_button = Button.new()
	build_button.text = "Build turret (B)"
	build_button.custom_minimum_size = Vector2(280, 44)
	build_button.focus_mode = Control.FOCUS_NONE
	build_button.pressed.connect(begin_placement)
	buttons.add_child(build_button)
	cancel_button = Button.new()
	cancel_button.text = "Cancel (Esc)"
	cancel_button.custom_minimum_size = Vector2(150, 44)
	cancel_button.focus_mode = Control.FOCUS_NONE
	cancel_button.pressed.connect(cancel_placement)
	buttons.add_child(cancel_button)
	start_button = Button.new()
	start_button.text = "Start run (Enter)"
	start_button.custom_minimum_size = Vector2(210, 44)
	start_button.focus_mode = Control.FOCUS_NONE
	start_button.pressed.connect(main.start_run)
	buttons.add_child(start_button)
	# The filled gold action makes the next run the clearest way forward.
	var primary := StyleBoxFlat.new()
	primary.bg_color = Color("#ffcf7a")
	primary.set_corner_radius_all(5)
	start_button.add_theme_stylebox_override("normal", primary)
	start_button.add_theme_color_override("font_color", Color("#17212b"))
	cancel_button.hide()
	_layout_sidebar()
	controller_cursor = main.get_arena_rect().get_center()
	get_viewport().size_changed.connect(_layout_sidebar)
	_update_interface()


func _layout_sidebar() -> void:
	var arena: Rect2 = main.get_arena_rect()
	sidebar.position = Vector2(arena.end.x, 0)
	sidebar.size = Vector2(main.SIDEBAR_WIDTH, arena.size.y)
	# GameHUD places the preparation controls in its shared scrollable column.


func _process(delta: float) -> void:
	if using_controller and main.phase == main.Phase.PREPARATION:
		var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var arena: Rect2 = main.get_arena_rect()
		controller_cursor = (controller_cursor + direction * CURSOR_SPEED * delta).clamp(arena.position, arena.end - Vector2.ONE)
	queue_redraw()
	_update_interface()
	if placing:
		preview.global_position = _cursor_position()
		var reason := placement_error(preview.global_position)
		var valid := reason.is_empty()
		preview.modulate = Color(0.6, 1.0, 0.7, 0.65) if valid else Color(1.0, 0.3, 0.3, 0.65)
		var confirm := "Cross" if using_controller else "Click"
		placement_hint.text = ((confirm + " to move here · Free") if is_instance_valid(selected_turret) else (confirm + " to build · %d energy" % int(turret_cost()))) if valid else reason
		placement_hint.modulate = Color("#a5edb7") if valid else Color("#ffb4a8")
		placement_hint.reset_size()
		var mouse := get_canvas_transform() * _cursor_position()
		var limit := (get_viewport_rect().size - placement_hint.size - Vector2(8, 8)).max(Vector2(8, 8))
		placement_hint.position = (mouse + Vector2(20, 24)).clamp(Vector2(8, 8), limit)


func turret_cost() -> float:
	var purchased := maxi(0, get_tree().get_nodes_in_group("turrets").size() - 1)
	return BASE_TURRET_COST + purchased * EXTRA_TURRET_COST


func _update_interface() -> void:
	# Parent _ready() has not run during this child's _ready(), so keep reads simple.
	var preparing: bool = main.phase == main.Phase.PREPARATION
	bar.visible = preparing
	build_button.visible = preparing
	start_button.visible = preparing
	start_button.disabled = placing
	build_button.text = "Build turret — %d energy (%s)" % [int(turret_cost()), "Square" if using_controller else "B"]
	cancel_button.text = "Cancel (%s)" % ("Circle" if using_controller else "Esc")
	start_button.text = "Start run (%s)" % ("Options" if using_controller else "Enter")
	build_button.disabled = placing or main.banked_energy < turret_cost()
	var remaining := maxi(0, int(ceil(turret_cost() - main.banked_energy)))
	overview.text = "AVAILABLE  %d energy\n%s" % [int(main.banked_energy), "Next turret affordable" if remaining == 0 else "%d more for next turret" % remaining]
	if placing:
		hint.text = "Move turret for free · Click to confirm · Esc to cancel" if is_instance_valid(selected_turret) else "Place new turret · Click to buy · Esc to cancel"
	elif not preparing:
		hint.text = "New enemies: %d hits · Tougher every 30s · Brightness attracts more" % int(main.current_enemy_health())
	elif main.banked_energy < turret_cost():
		hint.text = "Reposition turrets for free.\nClick one to move it."
	else:
		hint.text = "Add a turret, or click one to move it for free."
	if preparing and using_controller:
		hint.text = "Left stick / D-pad: cursor\nCross: select / place\nSquare: buy · Circle: cancel"


func _cursor_position() -> Vector2:
	return controller_cursor if using_controller else get_global_mouse_position()


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed or event is InputEventJoypadMotion and absf(event.axis_value) > 0.2:
		using_controller = true
	elif event is InputEventMouseMotion or event is InputEventMouseButton or event is InputEventKey:
		using_controller = false


func _draw() -> void:
	if not using_controller or main.phase != main.Phase.PREPARATION:
		return
	var point := to_local(controller_cursor)
	draw_arc(point, 10.0, 0.0, TAU, 32, Color.WHITE, 2.0)
	draw_line(point - Vector2(15, 0), point + Vector2(15, 0), Color.WHITE)
	draw_line(point - Vector2(0, 15), point + Vector2(0, 15), Color.WHITE)


func _unhandled_input(event: InputEvent) -> void:
	if main.phase != main.Phase.PREPARATION:
		return
	if event.is_action_pressed("build_turret"):
		begin_placement()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cancel_placement"):
		cancel_placement()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("start_run"):
		main.start_run()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("confirm_placement"):
		_select_or_place(controller_cursor)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = get_canvas_transform().affine_inverse() * event.position
		_select_or_place(point)
		get_viewport().set_input_as_handled()


func _select_or_place(point: Vector2) -> void:
	if placing:
		try_place(point)
	else:
		for turret in get_tree().get_nodes_in_group("turrets"):
			if point.distance_to(turret.global_position) <= 20.0:
				begin_move(turret)
				break


func begin_placement() -> void:
	if placing or main.phase != main.Phase.PREPARATION or main.banked_energy < turret_cost():
		return
	selected_turret = null
	_show_preview()


func begin_move(turret: Node2D) -> void:
	if placing or main.phase != main.Phase.PREPARATION or not is_instance_valid(turret) or not turret.is_in_group("turrets"):
		return
	selected_turret = turret
	selected_turret.hide()
	_show_preview()


func _show_preview() -> void:
	placing = true
	preview.global_position = _cursor_position()
	preview.show()
	placement_hint.show()
	cancel_button.show()
	_update_interface()


func can_place_at(point: Vector2) -> bool:
	return placement_error(point).is_empty()


func placement_error(point: Vector2) -> String:
	var arena: Rect2 = main.get_arena_rect()
	if not arena.has_point(point):
		return "Place inside the arena"
	if not arena.grow(-PLACEMENT_MARGIN).has_point(point):
		return "Too close to the arena edge"
	for turret in get_tree().get_nodes_in_group("turrets"):
		if turret == selected_turret:
			continue
		if point.distance_to(turret.global_position) < TURRET_SPACING:
			return "Too close to another turret"
	return ""


func try_place(point: Vector2) -> bool:
	# Validate everything before spending: invalid clicks never cost energy.
	if not placing or main.phase != main.Phase.PREPARATION or not can_place_at(point):
		return false
	if is_instance_valid(selected_turret):
		selected_turret.global_position = point
	else:
		var cost := turret_cost()
		if main.banked_energy < cost:
			return false
		var turret := TURRET_SCENE.instantiate() as Node2D
		turret.process_mode = Node.PROCESS_MODE_DISABLED
		get_parent().add_child(turret)
		turret.global_position = point
		main.banked_energy -= cost
	cancel_placement()
	main.save_progress()
	return true


func cancel_placement() -> void:
	if not placing:
		return
	placing = false
	if is_instance_valid(selected_turret):
		selected_turret.show()
	selected_turret = null
	preview.hide()
	placement_hint.hide()
	cancel_button.hide()
	_update_interface()
```

</details>

<details>
<summary>main.tscn — complete M5 snapshot</summary>

```ini
[gd_scene format=3 uid="uid://cnjhfdvymo7wv"]

[ext_resource type="Script" uid="uid://cit3707eae47i" path="res://main.gd" id="1_h2yge"]
[ext_resource type="Script" uid="uid://b2bk4an1dwj4l" path="res://lantern.gd" id="1_ig7tw"]
[ext_resource type="PackedScene" path="res://turret.tscn" id="3_turret"]
[ext_resource type="Script" path="res://build_controller.gd" id="4_build"]
[ext_resource type="Script" path="res://fps_counter.gd" id="5_fps"]
[ext_resource type="Script" path="res://game_hud.gd" id="6_hud"]

[node name="Main" type="Node2D" unique_id=49982640]
script = ExtResource("1_h2yge")

[node name="Lantern" type="Node2D" parent="." unique_id=118638199]
script = ExtResource("1_ig7tw")

[node name="Turret" parent="." instance=ExtResource("3_turret")]
position = Vector2(80, 0)

[node name="BuildController" type="Node2D" parent="."]
script = ExtResource("4_build")

[node name="GameHUD" type="CanvasLayer" parent="."]
script = ExtResource("6_hud")

[node name="Diagnostics" type="CanvasLayer" parent="."]
layer = 10

[node name="FPS" type="Label" parent="Diagnostics"]
offset_left = 12.0
offset_top = 10.0
mouse_filter = 2
theme_override_colors/font_color = Color(1, 1, 1, 1)
theme_override_colors/font_shadow_color = Color(0, 0, 0, 1)
theme_override_constants/shadow_offset_x = 1
theme_override_constants/shadow_offset_y = 1
theme_override_font_sizes/font_size = 16
text = "FPS: …"
script = ExtResource("5_fps")
```

</details>

<details>
<summary>tests/check_hud.gd — complete M5 snapshot</summary>

```gdscript
extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("check")


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func check() -> void:
	var scene = load("res://main.tscn").instantiate()
	var test_path := "/tmp/little-last-light-hud-%d.json" % OS.get_process_id()
	scene.save_path = test_path
	root.add_child(scene)
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	var hud = scene.get_node("GameHUD")
	var build = scene.get_node("BuildController")
	var lantern = scene.lantern
	expect(not hud.brightness_box.visible, "Preparation hides combat brightness controls")
	hud.light_buttons[2].pressed.emit()
	expect(lantern.brightness == 0, "Hidden brightness actions cannot change preparation state")
	expect(hud.format_time(125.9) == "02:05", "Survival time uses whole minutes and seconds")
	scene.start_run()
	for level in range(3):
		hud.light_buttons[level].pressed.emit()
		expect(lantern.brightness == level, "Brightness buttons select their own level")
		expect(hud.displayed_brightness == level, "Selected brightness is immediately shown")
		expect(hud.light_buttons[level].text.contains("+%d /s" % int(lantern.ENERGY_RATES[level])), "Income labels match gameplay rates")
	lantern.elapsed = 65.0
	lantern.energy = 28.4
	lantern.health = 24.0
	hud.refresh()
	expect(hud.health_bar.value == 24.0 and hud.health_text.text.contains("DANGER"), "Low health has a number, bar, and warning")
	expect(hud.subheading.text == "01:05", "Run timer displays actual elapsed time")
	scene.banked_energy = 5.0
	lantern.take_damage(100.0)
	hud.refresh()
	build._update_interface()
	expect(is_equal_approx(scene.last_run.energy, 28.4), "Recap captures earnings before banking clears them")
	expect(is_equal_approx(scene.banked_energy, 33.4), "HUD does not change banking arithmetic")
	expect(scene.last_run.new_best and scene.last_run.duration == 65.0, "Recap records survival and personal best")
	expect(hud.earnings.text == "+28 energy earned", "Recap retains earned amount after death")
	lantern._process(0.2)
	expect(lantern.hit_flash == 0.0 and lantern.energy == 0.0, "Hit feedback fades after death without producing preparation income")
	expect(build.bar.get_parent() == hud.panel and hud.panel.get_parent() == hud.scroll, "Recap and actions share a scrollable column instead of overlapping")
	expect(build.overview.text.contains("affordable"), "Recap identifies affordable next purchase")
	build.begin_placement()
	expect(build.try_place(Vector2(100, 100)), "Purchase after recap succeeds")
	build._update_interface()
	expect(build.overview.text.contains("17 more"), "Purchase refreshes progress toward escalating next price")
	scene.save_message = "Save test warning"
	hud.refresh()
	expect(hud.save_notice.visible and hud.save_notice.text == scene.save_message, "Save failures remain visible")
	scene.save_message = ""
	scene.start_run()
	hud.refresh()
	expect(hud.health_bar.value == 100.0 and hud.earnings.text == "+0 energy", "New run replaces recap with fresh live values")
	lantern.elapsed = 10.0
	lantern.take_damage(100.0)
	expect(not scene.last_run.new_best and scene.best_time == 65.0, "Shorter run does not claim a personal best")
	scene.free()
	DirAccess.remove_absolute(test_path)
	if failures == 0:
		print("PASS: brightness selection, health HUD, recap, affordability, save warning, restart")
	quit(1 if failures else 0)
```

</details>
