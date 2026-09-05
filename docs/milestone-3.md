# Milestone 3: building turrets during a run

This is a historical lesson for **M3**, before the next milestone moves construction between runs. Its embedded code is a snapshot, not code you need to paste into a newer version of the game.

## Revisit this exact version

The Git tag **`milestone-3`** identifies the complete working project for this lesson, including scenes, scripts, settings, and tests. [Browse the M3 source on GitHub](https://github.com/pelletiermaxime/little-last-light/tree/milestone-3).

You do not lose old code when a file changes: Git stores each committed version. To inspect the controller without changing your current files, run:

```bash
git show milestone-3:build_controller.gd
```

To play M3 separately while keeping your current project intact, run this from the project folder:

```bash
git worktree add --detach ../little-last-light-m3 milestone-3
godot --editor --path ../little-last-light-m3
```

That creates a separate directory containing the old version. You can experiment there without changing the main project's checkout.

## What M3 does

You earn energy during combat. At **20 energy**, press **B** or click **Build turret**. Gameplay pauses, a ghost turret follows the mouse, and a circle previews its firing range. Green means a valid spot; red means a blocked spot. Left-click to buy and resume. Escape or Cancel resumes without spending.

Turret bodies cannot overlap, but their range circles can. Construction is blocked outside the arena and beneath the HUD. Purchases last for the current attempt only: death followed by restart reloads the starting scene and clears bought turrets and energy.

Try a second turret with overlapping coverage, then move the lantern so enemies approach through that shared area. High brightness funds purchases faster and spawns more enemies.

## The scene tree and ownership

```text
Main                            main.gd: spawning, defeat, restart
├── Lantern                     lantern.gd: movement, health, energy, HUD
├── Turret                      instance of turret.tscn; starts beside lantern
├── BuildController             build_controller.gd: purchases and preview
│   ├── Turret                  preview only; disabled and not in turrets group
│   └── CanvasLayer             purchase controls, above gameplay
└── Turret / further instances  bought turrets added directly to Main
```

The lower entries appear at runtime. A purchased turret is a sibling of the lantern, so moving the lantern does not move it. The preview belongs to the controller because its lifetime and visibility belong to the placement interaction.

## A reusable scene is a template

Previously, Main declared the starting turret's script directly. M3 extracts that definition into `turret.tscn`, which contains a Node2D, the existing turret script, and membership in the `turrets` group. Main instances this scene for the starting turret; purchases instance the same scene again.

`preload("res://turret.tscn")` loads the template as a `PackedScene`. `instantiate()` creates a fresh set of nodes from it. Each turret therefore has its own cooldown and target selection, even though they share the same script.

The group is a lookup label. `get_nodes_in_group("turrets")` finds real turrets for spacing checks without relying on their generated node names.

## Follow one purchase through the controller

### 1. Set up once: `_ready()`

`@onready` retrieves the sibling Lantern after the controller enters the scene tree. The controller sets its process mode to `ALWAYS`, creates the preview, then creates the bottom-left controls.

The preview is a real turret instance for drawing purposes, but its process mode is `DISABLED`: it cannot run its firing code. Removing it from the `turrets` group prevents it from blocking its own placement. It starts hidden.

Button signals connect to the same methods used by keyboard input. This keeps mouse and keyboard behavior consistent. The non-interactive containers and label ignore mouse input, so their empty space does not swallow placement clicks. Buttons themselves still consume clicks.

### 2. Enter placement: `begin_placement()`

This guard rejects invalid transitions:

```gdscript
if placing or get_tree().paused or lantern.health <= 0.0 or lantern.energy < TURRET_COST:
	return
```

That means: do not enter twice, do not build over the defeat menu, do not build while dead, and do not build without enough energy. A disabled button helps the player understand affordability, but the method checks it too because keyboard input also calls it.

Only after validation does it set `placing`, pause the scene tree, and show the preview and Cancel button. Entering placement spends nothing.

### 3. Update the preview: `_process()`

The controller keeps processing during pause. Every frame it updates the affordability message. During placement it reads the global mouse position, moves the preview there, asks `can_place_at()` whether the spot is valid, and changes its tint.

The rest of the game uses normal inherited processing. Pausing stops the lantern's movement, health-producing enemy updates, energy generation, spawning, and real turret firing. The defeat menu has its own always-processing layer from M2.

### 4. Convert the click: `_unhandled_input()`

B begins placement; Escape cancels. Key repeats are ignored. A left-click during placement calls:

```gdscript
try_place(get_canvas_transform().affine_inverse() * event.position)
```

The click arrives in viewport coordinates. The inverse canvas transform converts it into world coordinates for turret positioning. The preview also uses world coordinates. Using the position stored in the click event makes placement correspond to that particular click.

After handling an action, `set_input_as_handled()` prevents another handler from treating it as a second action.

### 5. Validate the position: `can_place_at()`

Three checks run before placement:

- A 20-pixel arena margin keeps the turret body inside the screen. The range circle may extend beyond it.
- Two reserved rectangles keep the top-left HUD and bottom-left controls clear.
- A minimum 36-pixel distance between turret centers keeps their bodies apart.

This is a placement-spacing rule, not enemy collision detection. Overlapping firing ranges are deliberately allowed.

### 6. Complete the purchase: `try_place()`

The method rechecks placement state, health, funds, and position before changing anything. If all checks pass, it creates a turret under Main, sets its world position, subtracts 20 energy, refreshes the lantern's HUD, and exits placement.

For example, 27.5 energy becomes 7.5 after buying one turret. Invalid clicks and cancelling leave it at 27.5. A second click after purchase does not buy another turret, because `placing` is already false.

### 7. Finish either way: `cancel_placement()`

The name describes the Cancel action, but successful purchases call this method too: both outcomes need to hide the preview and button, clear `placing`, and unpause. It does not deduct energy or delete a purchased turret.

## What stayed from earlier milestones

Energy still belongs to Lantern and grows with brightness. Main still places the first turret beside it at startup. Turrets still find the nearest enemy in range and instantly remove it when firing. Contact damage still uses the M2 distance tolerance; M3 does not convert enemies to Area2D.

Those supporting files are preserved at the tag: [lantern.gd](https://github.com/pelletiermaxime/little-last-light/blob/milestone-3/lantern.gd), [main.gd](https://github.com/pelletiermaxime/little-last-light/blob/milestone-3/main.gd), [turret.gd](https://github.com/pelletiermaxime/little-last-light/blob/milestone-3/turret.gd), and [enemy.gd](https://github.com/pelletiermaxime/little-last-light/blob/milestone-3/enemy.gd).

## How we checked it

From the project folder:

```bash
godot --headless --path . --script res://tests/check_build.gd
godot --headless --path . --script res://tests/check_health.gd
```

The build test loads the actual scene, injects B and Escape key events and a left-click, and checks affordability, paused energy/time, invalid positions, cancellation, cost, duplicate clicks, fixed positions, turret firing, defeat, and a clean restart. Some cases call purchase methods directly to isolate individual rules. The health test also runs to catch regressions in damage and restarting.

One useful test detail: `root.push_input(click, true)` says the test's click coordinates are already local to the viewport. Without that flag, Godot transforms them from window coordinates, which can differ in a headless run. The test point is based on `get_viewport_rect().size`, not the physical window size.

Godot imported the scenes, both checks passed, the graphical game launched, and the purchase HUD was checked in a screenshot. You also confirmed M3 works well during playtesting. Automated tests establish the checked rules, not whether the economy is fun at every price.

## Experiments to try in the M3 checkout

1. Change `TURRET_COST` from 20 to 10. The price label follows the constant. Observe how earlier purchases affect the risk of High brightness.
2. Change `TURRET_SPACING` from 36 to 80. Try the same layout and notice the placement restriction, while firing range stays unchanged.
3. Change `attack_range` in `turret.gd`. Both real turrets and the preview inherit the new default.

## Limits of this checkpoint and the next milestone

M3 has one turret type, a fixed price, no upgrades or relocation, and no persistence. Its HUD exclusion rectangles use fixed dimensions; a future responsive HUD would benefit from deriving them from actual controls. The controller directly accesses Lantern's energy and HUD refresh method, which is easy to trace here but will change when energy becomes persistent.

The next milestone will move purchases into a between-run preparation phase, retain earned energy and turret layouts, allow repositioning during preparation, add an explicit Start run action, and ramp up combat difficulty. Those changes belong after this checkpoint. This lesson and the `milestone-3` tag preserve the earlier during-run purchase design.

## Complete M3 code snapshots

The sections below embed the exact M3 controller, scene definitions, and build test. They remain readable even after those files evolve. The Git tag preserves the rest of the project as well.

<details>
<summary>build_controller.gd — complete M3 version</summary>

```gdscript
extends Node2D

const TURRET_SCENE: PackedScene = preload("res://turret.tscn")
const TURRET_COST: float = 20.0
const PLACEMENT_MARGIN: float = 20.0
const TURRET_SPACING: float = 36.0

@onready var lantern: Node2D = get_parent().get_node("Lantern")

var placing: bool = false
var preview: Node2D
var build_button: Button
var cancel_button: Button
var hint: Label


func _ready() -> void:
	# Placement UI and preview work while the rest of the run is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	preview = TURRET_SCENE.instantiate()
	preview.process_mode = Node.PROCESS_MODE_DISABLED
	preview.remove_from_group("turrets")
	add_child(preview)
	preview.hide()
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var bar := VBoxContainer.new()
	layer.add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	bar.offset_left = 24
	bar.offset_top = -120
	bar.offset_right = 540
	bar.offset_bottom = -20
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint = Label.new()
	hint.add_theme_font_size_override("font_size", 18)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(hint)
	var buttons := HBoxContainer.new()
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(buttons)
	build_button = Button.new()
	build_button.text = "Build turret — %d energy (B)" % int(TURRET_COST)
	build_button.custom_minimum_size = Vector2(300, 44)
	build_button.focus_mode = Control.FOCUS_NONE
	build_button.pressed.connect(begin_placement)
	buttons.add_child(build_button)
	cancel_button = Button.new()
	cancel_button.text = "Cancel (Esc)"
	cancel_button.custom_minimum_size = Vector2(150, 44)
	cancel_button.focus_mode = Control.FOCUS_NONE
	cancel_button.pressed.connect(cancel_placement)
	buttons.add_child(cancel_button)
	cancel_button.hide()
	_update_interface()


func _process(_delta: float) -> void:
	_update_interface()
	if placing:
		preview.global_position = get_global_mouse_position()
		var valid := can_place_at(preview.global_position)
		preview.modulate = Color(0.6, 1.0, 0.7, 0.65) if valid else Color(1.0, 0.3, 0.3, 0.65)


func _update_interface() -> void:
	build_button.disabled = placing or lantern.health <= 0.0 or lantern.energy < TURRET_COST
	if placing:
		hint.text = "Paused · Left-click to place · Esc to cancel"
	elif lantern.health <= 0.0:
		hint.text = ""
	elif lantern.energy < TURRET_COST:
		hint.text = "Need %d more energy to build" % int(ceil(TURRET_COST - lantern.energy))
	else:
		hint.text = "Ready to expand your defense"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_B:
			begin_placement()
			get_viewport().set_input_as_handled()
		elif placing and event.keycode == KEY_ESCAPE:
			cancel_placement()
			get_viewport().set_input_as_handled()
	elif placing and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		try_place(get_canvas_transform().affine_inverse() * event.position)
		get_viewport().set_input_as_handled()


func begin_placement() -> void:
	if placing or get_tree().paused or lantern.health <= 0.0 or lantern.energy < TURRET_COST:
		return
	placing = true
	get_tree().paused = true
	preview.global_position = get_global_mouse_position()
	preview.show()
	cancel_button.show()
	_update_interface()


func can_place_at(point: Vector2) -> bool:
	var screen_size := get_viewport_rect().size
	if not Rect2(Vector2.ONE * PLACEMENT_MARGIN, screen_size - Vector2.ONE * PLACEMENT_MARGIN * 2.0).has_point(point):
		return false
	# Keep the HUD and purchase controls clear.
	if Rect2(0, 0, 460, 210).has_point(point) or Rect2(0, screen_size.y - 140, 560, 140).has_point(point):
		return false
	for turret in get_tree().get_nodes_in_group("turrets"):
		if point.distance_to(turret.global_position) < TURRET_SPACING:
			return false
	return true


func try_place(point: Vector2) -> bool:
	# Validate everything before spending: invalid clicks never cost energy.
	if not placing or lantern.health <= 0.0 or lantern.energy < TURRET_COST or not can_place_at(point):
		return false
	var turret := TURRET_SCENE.instantiate() as Node2D
	get_parent().add_child(turret)
	turret.global_position = point
	lantern.energy -= TURRET_COST
	lantern._update_status()
	cancel_placement()
	return true


func cancel_placement() -> void:
	if not placing:
		return
	placing = false
	preview.hide()
	cancel_button.hide()
	get_tree().paused = false
	_update_interface()
```

</details>

<details>
<summary>turret.tscn — complete M3 version</summary>

```ini
[gd_scene format=3]

[ext_resource type="Script" path="res://turret.gd" id="1"]

[node name="Turret" type="Node2D" groups=["turrets"]]
script = ExtResource("1")
```

</details>

<details>
<summary>main.tscn — complete M3 version</summary>

```ini
[gd_scene format=3 uid="uid://cnjhfdvymo7wv"]

[ext_resource type="Script" uid="uid://cit3707eae47i" path="res://main.gd" id="1_h2yge"]
[ext_resource type="Script" uid="uid://b2bk4an1dwj4l" path="res://lantern.gd" id="1_ig7tw"]
[ext_resource type="PackedScene" path="res://turret.tscn" id="3_turret"]
[ext_resource type="Script" path="res://build_controller.gd" id="4_build"]

[node name="Main" type="Node2D" unique_id=49982640]
script = ExtResource("1_h2yge")

[node name="Lantern" type="Node2D" parent="." unique_id=118638199]
script = ExtResource("1_ig7tw")

[node name="Turret" parent="." instance=ExtResource("3_turret")]
position = Vector2(80, 0)

[node name="BuildController" type="Node2D" parent="."]
script = ExtResource("4_build")
```

</details>

<details>
<summary>tests/check_build.gd — complete M3 version</summary>

```gdscript
extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func press_key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	root.push_input(event)

func check() -> void:
	change_scene_to_file("res://main.tscn")
	await scene_changed
	var scene = current_scene
	var lantern = scene.lantern
	var build = scene.get_node("BuildController")
	assert(get_nodes_in_group("turrets").size() == 1, "Ghost is not a real turret")
	press_key(KEY_B)
	assert(not paused and not build.placing, "Cannot build without energy")
	lantern.energy = 40.0
	press_key(KEY_B)
	assert(paused and build.placing and build.preview.visible, "B enters placement")
	var elapsed: float = lantern.elapsed
	await process_frame
	await process_frame
	assert(lantern.energy == 40.0 and lantern.elapsed == elapsed, "Placement freezes economy and timer")
	assert(not build.try_place(Vector2(-10, 300)), "Outside arena rejected")
	assert(not build.try_place(scene.get_node("Turret").global_position), "Overlap rejected")
	assert(not build.try_place(Vector2(30, 30)), "HUD blocked")
	assert(lantern.energy == 40.0, "Invalid clicks do not spend")
	press_key(KEY_ESCAPE)
	assert(not paused and not build.placing and lantern.energy == 40.0, "Esc cancels without cost")
	press_key(KEY_B)
	var arena: Vector2 = scene.get_viewport_rect().size
	var point := Vector2(arena.x * 0.85, arena.y * 0.55)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = point
	root.push_input(click, true)
	assert(not paused and lantern.energy == 20.0, "Purchase costs exactly 20 and resumes")
	assert(get_nodes_in_group("turrets").size() == 2, "Exactly one real turret added")
	assert(not build.try_place(point + Vector2(50, 0)), "Second click cannot purchase again")
	var turret = get_nodes_in_group("turrets")[1]
	lantern.position += Vector2(10, 0)
	assert(turret.global_position == point, "Purchased turret stays fixed")
	scene._spawn_enemy()
	var enemy = get_nodes_in_group("enemies")[0]
	enemy.global_position = point + Vector2(50, 0)
	turret._process(0.1)
	assert(enemy.is_queued_for_deletion(), "Purchased turret shoots")
	lantern.take_damage(1000)
	press_key(KEY_B)
	assert(paused and not build.placing, "Cannot build during defeat")
	scene.restart_button.pressed.emit()
	await scene_changed
	assert(get_nodes_in_group("turrets").size() == 1, "Restart clears purchased turrets")
	assert(not current_scene.get_node("BuildController").placing, "Restart clears placement state")
	print("PASS: keyboard placement, pause, invalid positions, cancel, cost, double-click, fixed turret, shooting, defeat and restart")
	quit()
```

</details>
