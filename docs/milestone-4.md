# Milestone 4: survive, prepare, improve, repeat

This lesson records the first version of our **run-based progression loop**. It includes complete code snapshots below so later changes will not erase the explanation. M3 remains available under the Git tag `milestone-3`; The Git tag `milestone-4` preserves this approved checkpoint. [Browse the exact M4 source](https://github.com/pelletiermaxime/little-last-light/tree/milestone-4).

## Try the new loop

Open `project.godot` and press **F5**. You begin in **Preparation** with your existing layout and saved energy.

1. Click **Start run** or press **Enter**. The lantern returns to the center with full health, Low brightness, and a fresh timer.
2. Use **WASD/arrows** to move and **Space** to change brightness. You earn energy, but cannot build or reposition during combat.
3. When health reaches zero, enemies disappear and your earnings become available to spend. Turrets stay where you placed them.
4. Press **B** to buy a turret. The first extra turret costs **20 energy**, then each additional turret costs 10 more: 30, 40, 50, and so on. Click a valid position to confirm, or **Esc** to cancel.
5. Click an existing turret to move it for free. Its original spot is preserved until you confirm the new one. Esc restores it.
6. Start the next run when the layout is ready. All unspent energy carries forward.

The first attempt needs no purchases: start with the free turret, earn energy, then use it after defeat. Nothing generates energy during preparation.

## What changed from M3

| M3 | M4 |
|---|---|
| Build by pausing an active run | Build only in preparation |
| Death reloads the whole scene | Death switches phase and clears enemies |
| Purchases disappear on restart | Purchases and positions survive |
| Energy belongs to the current attempt | Current earnings join a persistent balance |
| Fixed spawn interval per brightness | Spawn interval shrinks as the run progresses |
| No saved progression | Energy, layout, and best completed time saved locally |

This version keeps distance-based contact detection, with additional corrections for contact rounding and arrival during a frame. It does not switch to Area2D, add turret upgrades, or add a stationary armor bonus yet.

## The central idea: two phases

In `main.gd`:

```gdscript
enum Phase { PREPARATION, RUNNING }
var phase: Phase = Phase.PREPARATION
```

An enum gives names to the states of the game. Instead of many unrelated decisions about whether to pause, each operation checks which phase allows it.

```text
PREPARATION ── Start run ──► RUNNING
     ▲                          │
     └──── lantern dies ────────┘
```

The scene tree stays alive and unpaused in both phases. Main stops spawning outside RUNNING. Lantern's `running` flag prevents movement, income, brightness changes, damage, and timer advancement during preparation. Real turrets use disabled processing while preparing, but remain visible. The build controller keeps processing so mouse previews and buttons work.

This makes preparation an actual game phase with its own actions, rather than a frozen combat scene with a purchase menu on top.

## Who owns what?

| File | Responsibility in M4 |
|---|---|
| `main.gd` | Phase transitions, persistent balance, enemies, spawn pressure, saves |
| `lantern.gd` | Movement, health, brightness, time and energy earned in the current run |
| `build_controller.gd` | Preparation UI, purchase preview, free relocation, position validation |
| `turret.gd` / `turret.tscn` | The existing automatic turret behavior and reusable scene |
| `enemy.gd` | Chase, health, and frame-accurate contact damage |

The lantern and real turrets are still siblings under Main. Moving one never carries the others along.

## Starting a run: `start_run()`

Main only starts from PREPARATION and rejects Start while a placement is unfinished. This avoids starting combat with a hidden turret being moved.

It clears any remaining enemies, restores health, sets run energy and elapsed time to zero, resets brightness to Low, centers the lantern, and resets spawn progress. Then it switches to RUNNING and enables the lantern and turrets. Each turret's cooldown and lingering beam flash are reset.

It deliberately retains `banked_energy` and the existing turret nodes. We no longer reload the whole scene to start another attempt.

## Ending a run: `_on_lantern_died()`

The lantern still announces defeat through its `died` signal. Main handles that announcement only while RUNNING, then:

1. Switches to PREPARATION and stops the lantern's run logic.
2. Updates the best completed survival time and the result summary.
3. Adds current earnings to `banked_energy` and resets current earnings to zero.
4. Disables and removes enemies, stops turret processing, refreshes the HUD, and saves.

The phase guard prevents a repeated death notification from banking earnings twice. Enemies are disabled immediately before `queue_free()` because queued deletion happens at the end of the frame; they must not deal another hit while awaiting deletion.

## Follow the energy through two attempts

`lantern.energy` means **earned in this run**. `main.banked_energy` means **available between runs**.

For example:

```text
Begin with 10 banked energy.
Earn 35 in the run: bank = 10, current earnings = 35.
Die: bank becomes 45, current earnings become 0.
Buy one turret: bank becomes 25.
Start again: bank stays 25, current earnings start at 0.
```

Brightness still controls income at 1, 3, or 6 energy per second. It also changes enemy pressure. The bank cannot be spent during combat even if it already contains enough for a purchase.

## How free repositioning works

`begin_move(turret)` remembers the selected real turret in `selected_turret`, hides it, and shows the ghost preview. The real turret retains its original position and stays in the real-turret group.

`can_place_at()` ignores that selected turret when checking spacing, so it cannot block itself. Other real turrets still block overlapping bodies. Preparation controls and the combat HUD now live in a dedicated 320-pixel sidebar outside the arena. There is no UI-overlap placement rule. Only arena boundaries and spacing from other turrets limit placement. The preview explains an arena-edge or turret-spacing issue; pointing into the sidebar says to place inside the arena.

When `try_place()` succeeds:

- If a turret is selected, update that existing node's position. No currency is spent and no extra node is created.
- Otherwise, check banked funds, create a new turret with processing disabled, and subtract the current turret price.

Both routes end placement and save the layout. Cancelling shows the original turret again; because its real position never changed, there is nothing to undo. Saving while a move is unfinished records the original position.

## Difficulty after the first playtest

The first M4 playtest exposed two weaknesses: extra turrets were cheap enough to buy five at once, and all enemies died in one hit. The spawn ramp alone did not challenge a larger stationary defense enough.

The revised spawn interval is:

```gdscript
maxf(0.12, SPAWN_INTERVALS[lantern.brightness] / (1.0 + lantern.elapsed / PRESSURE_RAMP_SECONDS))
```

The starting intervals remain **2.0, 1.2, and 0.65 seconds** for Low, Medium, and High. `PRESSURE_RAMP_SECONDS` is now **20**, so spawn frequency doubles after 20 seconds. The 0.12-second floor bounds spawning.

A second rule keeps pressure growing even after that floor is reached:

```gdscript
func current_enemy_health() -> float:
	return 1.0 + floorf(lantern.elapsed / TOUGHNESS_STEP_SECONDS)
```

`TOUGHNESS_STEP_SECONDS` is **30**. New enemies have 1 health before 30 seconds, 2 before 60 seconds, 3 before 90 seconds, and so on. Existing enemies retain the health they spawned with. Main assigns `max_health` before adding an enemy to the scene tree, so its `_ready()` initializes the correct health.

Turrets now call `enemy.take_damage(damage)` instead of deleting their target immediately. Each turret deals 1 damage per shot. Enemies subtract damage and delete themselves at zero health. Tougher enemies draw a small health bar, and the combat HUD shows the hits required by newly spawning enemies.

These rules reset with every run and depend on elapsed time, not your turret count. Purchases therefore still make you stronger; enemies do not automatically scale to cancel each purchase.

A diagnostic simulated a stationary lantern, turrets arranged in an 80-pixel-radius ring, and three fixed random seeds per setup:

| Turrets | Low brightness survival | High brightness survival |
|---|---|---|
| 1 | 35.7–38.7 seconds | 20.1–20.7 seconds |
| 3 | 55.6–58.0 seconds | 34.2–36.1 seconds |
| 6 | 81.1–81.9 seconds | 48.9–49.6 seconds |
| 12 | 112.1–114.0 seconds | 65.0–67.7 seconds |

These are controlled samples, not guaranteed lifetimes. Dodging, other layouts, and viewport size affect survival. High brightness can still be profitable on shorter runs, so economy tuning remains open to playtesting.

## Faster pursuers and contact while moving

A later playtest lasted almost three minutes on the first attempt. The stationary samples above did not represent active dodging well: the lantern moves at 220 pixels/second, while enemies previously stayed at 45.

New enemies now spawn with:

```gdscript
minf(MAX_ENEMY_SPEED, BASE_ENEMY_SPEED + lantern.elapsed * ENEMY_SPEED_GAIN_PER_SECOND)
```

The base is **100 pixels/second**, the gain is **3 per elapsed second**, and the cap is **320**. New arrivals match the lantern's 220 speed at 40 seconds and exceed it afterward. Existing enemies retain their spawn speed. The next run resets the speed curve. Brightness continues to change spawn frequency and energy income; it does not directly change enemy speed.

The tests also uncovered an important contact-timing bug. Checking damage only before enemy movement meant a pursuer could reach the lantern each frame but fail to damage it because the lantern moved away before the next check.

The corrected enemy code computes:

```gdscript
var time_to_contact: float = (distance - CONTACT_DISTANCE) / speed
var contact_time: float = maxf(0.0, delta - time_to_contact)
```

After moving, it applies damage for that remaining contact time. For example, an enemy 10 pixels outside contact moving at 100 pixels/second takes 0.1 seconds to arrive. In a 0.2-second update, only the remaining 0.1 seconds deals damage. Enemies already touching at the beginning of a frame apply the full frame's contact damage.

A new regression check moves the lantern away every frame while a faster enemy pursues. It verifies health decreases, rather than only testing a stationary target. Another check verifies the exact arrival-time damage calculation.

With this corrected contact handling and the same circular movement route, Low brightness, and three fixed random seeds:

| Defense | Constant 45-speed enemies | New speed curve |
|---|---|---|
| Starting turret | 108.3–125.6 seconds | 54.4–55.3 seconds |
| Six turrets in a central ring | 114.4–130.1 seconds | 56.2–58.0 seconds |

This circular route is a repeatable diagnostic, not an intelligent player. It spends time away from central turret coverage, which limits the advantage of additional turrets. Your positioning and dodging can produce different survival times. The older stationary balance samples in this lesson are historical results, not predictions for this revision.

## Progressive turret prices

`turret_cost()` computes the next price as:

```gdscript
BASE_TURRET_COST + purchased * EXTRA_TURRET_COST
```

The base is 20, the increment is 10, and `purchased` is the number of real turrets minus the free starting turret. The preview is excluded from that group. Buying a turret increases the next price, while moving one does not. The button, affordability check, and final deduction all use the same calculation.

For example, 120 banked energy buys three extra turrets at 20 + 30 + 40 = 90, leaving 30 toward the next price of 50. Existing saved turrets and energy are preserved; the new price is derived from the layout you already own.

## A separate arena and sidebar

`main.get_arena_rect()` is now the shared source of gameplay bounds. It reserves the rightmost 320 pixels for the sidebar. Placement, lantern centering and movement, enemy spawn edges, and normalized saving all use that same arena rectangle.

The sidebar exists in both phases, so hiding preparation buttons during combat does not expand the arena or move turrets. The HUD stays in the sidebar during combat. The old top-left and bottom build exclusions inside the arena have been removed entirely. A visible divider marks where the arena ends.

The arena is narrower than the earlier full-window version. Saved turret coordinates are proportional, so existing layouts map into that smaller arena. Their proportions are retained, while ranges remain measured in game pixels. Balance samples above were collected before this sidebar layout change and should be treated as historical tuning evidence rather than predictions for the new geometry.

## Saving and reopening

The exported `save_path` defaults to **`user://progress-v1.json`**. `user://` is Godot's local application-data folder, separate from the source repository. In the editor, use **Project → Open User Data Folder** to find it. On your Linux machine, I verified the file at `/home/maximep/.local/share/godot/app_userdata/Little Last Light/progress-v1.json`.

The save contains a version number, available energy, best completed survival time, and normalized turret coordinates. A turret at half the arena width is stored with an x coordinate of 0.5. Loading scales those coordinates to the current arena; live resizing also scales turret positions. Existing normalized saves map into the new arena without losing energy or turrets.

Saving happens after a purchase, after a confirmed move, after defeat, every five seconds during combat, and on a normal desktop window close. It writes a temporary file first and then replaces the previous save, reducing the chance of leaving a partial JSON file.

During combat the saved balance is `banked_energy + lantern.energy`. This writes all earnings without changing either live variable. On reopening, that total is restored as banked energy and the game opens in preparation. It does **not** resume enemies or the exact interrupted run. Abruptly killing the process or stopping it from the editor can lose the few seconds since the last autosave.

An empty or whitespace-only file is treated like a missing save: a new profile starts and saving stays enabled. If you clear a previously unreadable file while the session is still open, the next save can recover too. Malformed nonempty or incompatible data produces a visible message and is preserved instead of overwritten. A write failure displays a message; a failed save on a normal close leaves the window open so the player can retry. Progress saves are local to the installation; browser exports would have their own browser-local storage, not automatic cross-device syncing.

## Tests and what they establish

Run these from the project folder:

```bash
godot --headless --path . --script res://tests/check_runs.gd
godot --headless --path . --script res://tests/check_build.gd
godot --headless --path . --script res://tests/check_health.gd
godot --headless --path . --script res://tests/check_difficulty.gd
```

The difficulty test checks progressive prices, arena/sidebar separation, the former HUD areas being buildable, identical arena bounds across phases, spawn and movement bounds, multi-hit enemies, continued toughness scaling, and a fresh run's toughness.

Save tests now include zero-byte and whitespace-only files, earning energy from that fresh state, reopening to recover it, and recovering an open session after its bad file is cleared. The difficulty test also checks spawn speed, its cap and reset, and damage from a faster pursuer while the lantern moves.

Each test uses its own temporary save path, so it does not modify your real progression.

- **Run test:** preparation does not produce income/time/damage/enemies; combat locks building; difficulty grows; defeat banks once; purchases and free moves persist; a new attempt resets health and difficulty; save/reopen retains earnings and positions; malformed saves are preserved.
- **Build test:** real B/Escape and mouse events, valid and invalid purchases, exact cost, duplicate clicks, fixed turrets, shooting, and purchased turrets surviving into the next attempt.
- **Health test:** all 72 approach directions still cause damage, death triggers once, preparation freezes run progression, and Start restores health.

The game was also rendered to inspect preparation, the post-run results, and relocation controls. Both automated rule checks and your own playtesting remain useful: tests cannot decide whether progression feels rewarding.

## Experiments for learning

1. Change `PRESSURE_RAMP_SECONDS` from 20 to 40. Pressure now doubles later. Compare a first run without buying anything.
2. Change `BASE_TURRET_COST` or `EXTRA_TURRET_COST` in `build_controller.gd`. Notice that it changes how many failed attempts you need for another turret without changing combat itself.
3. Watch `banked_energy` and `lantern.energy` in the Remote inspector across a death. One grows as the other returns to zero.

This is a prototype economy. Turret upgrades, more enemy roles, and stronger stationary builds remain future work. There is no reset-progress button yet; to make a clean test profile, use a different `save_path` rather than deleting your progress accidentally.

## Complete code snapshots

Updated M4 snapshots including empty-save recovery, faster arrivals, and corrected moving-contact damage. The Git tag `milestone-4` preserves this playable checkpoint; UI polish and further balance tuning follow in later changes.

<details>
<summary>main.gd — M4 snapshot</summary>

```gdscript
extends Node2D

enum Phase { PREPARATION, RUNNING }

const SIDEBAR_WIDTH: float = 320.0

const ENEMY_SCENE: PackedScene = preload("res://enemy.tscn")
const TURRET_SCENE: PackedScene = preload("res://turret.tscn")
const SPAWN_INTERVALS: Array[float] = [2.0, 1.2, 0.65]
const PRESSURE_RAMP_SECONDS: float = 20.0
const TOUGHNESS_STEP_SECONDS: float = 30.0
const BASE_ENEMY_SPEED: float = 100.0
const ENEMY_SPEED_GAIN_PER_SECOND: float = 3.0
const MAX_ENEMY_SPEED: float = 320.0

@export var save_path: String = "user://progress-v1.json"
@onready var lantern: Node2D = $Lantern

var phase: Phase = Phase.PREPARATION
var banked_energy: float = 0.0
var best_time: float = 0.0
var spawn_progress: float = 0.0
var autosave_elapsed: float = 0.0
var summary: String = "Arrange your defense, then start your first run."
var save_message: String = ""
var previous_viewport_size: Vector2
var save_is_readable: bool = true


func _ready() -> void:
	previous_viewport_size = get_arena_rect().size
	$Turret.position = lantern.position + Vector2(80.0, 0.0)
	lantern.died.connect(_on_lantern_died)
	load_progress()
	_set_turrets_active(false)
	lantern._update_status()
	get_viewport().size_changed.connect(_resize_layout)
	get_tree().auto_accept_quit = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if save_progress() or not save_is_readable:
			get_tree().quit()


func start_run() -> void:
	if phase != Phase.PREPARATION or $BuildController.placing:
		return
	_clear_enemies()
	lantern.health = lantern.max_health
	lantern.energy = 0.0
	lantern.elapsed = 0.0
	lantern.brightness = 0
	lantern.hit_flash = 0.0
	lantern._center_in_viewport()
	spawn_progress = 0.0
	autosave_elapsed = 0.0
	phase = Phase.RUNNING
	lantern.running = true
	_set_turrets_active(true)
	lantern._update_status()


func _on_lantern_died() -> void:
	if phase != Phase.RUNNING:
		return
	phase = Phase.PREPARATION
	lantern.running = false
	best_time = maxf(best_time, lantern.elapsed)
	summary = "The light went out · %ds survived · +%d energy\nImprove your layout and try again. Best: %ds" % [int(lantern.elapsed), int(lantern.energy), int(best_time)]
	banked_energy += lantern.energy
	lantern.energy = 0.0
	_clear_enemies()
	_set_turrets_active(false)
	lantern._update_status()
	save_progress()


func _clear_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.remove_from_group("enemies")
		enemy.queue_free()


func _set_turrets_active(active: bool) -> void:
	for turret in get_tree().get_nodes_in_group("turrets"):
		turret.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
		turret.cooldown = 0.0
		turret.shot_time = 0.0
		turret.queue_redraw()


func current_spawn_interval() -> float:
	return maxf(0.12, SPAWN_INTERVALS[lantern.brightness] / (1.0 + lantern.elapsed / PRESSURE_RAMP_SECONDS))


func current_enemy_health() -> float:
	# New enemies need another hit every 30 seconds, even after spawn rate caps.
	return 1.0 + floorf(lantern.elapsed / TOUGHNESS_STEP_SECONDS)


func current_enemy_speed() -> float:
	# Faster arrivals eventually catch a lantern that only runs away.
	return minf(MAX_ENEMY_SPEED, BASE_ENEMY_SPEED + lantern.elapsed * ENEMY_SPEED_GAIN_PER_SECOND)


func _process(delta: float) -> void:
	if phase != Phase.RUNNING:
		return
	spawn_progress += delta / current_spawn_interval()
	if spawn_progress >= 1.0:
		spawn_progress -= 1.0
		_spawn_enemy()
	autosave_elapsed += delta
	if autosave_elapsed >= 5.0:
		autosave_elapsed = 0.0
		save_progress()


func _spawn_enemy() -> void:
	if phase != Phase.RUNNING:
		return
	var enemy := ENEMY_SCENE.instantiate() as Node2D
	enemy.target = lantern
	enemy.max_health = current_enemy_health()
	enemy.speed = current_enemy_speed()
	add_child(enemy)
	enemy.global_position = _random_edge_position()


func get_arena_rect() -> Rect2:
	var size := get_viewport_rect().size
	return Rect2(Vector2.ZERO, Vector2(maxf(100.0, size.x - SIDEBAR_WIDTH), size.y))


func _draw() -> void:
	var arena := get_arena_rect()
	draw_line(Vector2(arena.end.x, 0), arena.end, Color("#53697e"), 2.0)


func _random_edge_position() -> Vector2:
	var size := get_arena_rect().size
	match randi_range(0, 3):
		0: return Vector2(16, randf_range(16, size.y - 16))
		1: return Vector2(size.x - 16, randf_range(16, size.y - 16))
		2: return Vector2(randf_range(16, size.x - 16), 16)
		_: return Vector2(randf_range(16, size.x - 16), size.y - 16)


func _resize_layout() -> void:
	var size := get_arena_rect().size
	if previous_viewport_size.x > 0.0 and previous_viewport_size.y > 0.0:
		for turret in get_tree().get_nodes_in_group("turrets"):
			turret.position = (turret.position / previous_viewport_size * size).clamp(Vector2(20, 20), (size - Vector2(20, 20)).max(Vector2(20, 20)))
	previous_viewport_size = size
	queue_redraw()


func save_progress() -> bool:
	if not save_is_readable:
		# An intentionally emptied file is a fresh profile, not corrupt data to protect.
		if not FileAccess.file_exists(save_path) or FileAccess.get_file_as_string(save_path).strip_edges().is_empty():
			save_is_readable = true
		else:
			return false
	var positions: Array = []
	var size := get_arena_rect().size
	for turret in get_tree().get_nodes_in_group("turrets"):
		var point: Vector2 = turret.position / size
		positions.append([point.x, point.y])
	# Include current earnings without banking them twice in the live game.
	var data := {"version": 1, "energy": banked_energy + lantern.energy, "best_time": best_time, "turrets": positions}
	var file := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null:
		save_message = "Could not save progress. Keep this window open and retry."
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or DirAccess.rename_absolute(save_path + ".tmp", save_path) != OK:
		save_message = "Could not save progress. Keep this window open and retry."
		return false
	save_message = ""
	return true


func load_progress() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var contents := FileAccess.get_file_as_string(save_path)
	if contents.strip_edges().is_empty():
		# Same starting state as a missing save; the next save creates valid JSON.
		return
	var parser := JSON.new()
	var error := parser.parse(contents)
	if error != OK or not _valid_save(parser.data):
		save_is_readable = false
		save_message = "Save could not be read; original file preserved. This session will not save."
		return
	var data: Dictionary = parser.data
	banked_energy = float(data.energy)
	best_time = float(data.best_time)
	for turret in get_tree().get_nodes_in_group("turrets"):
		turret.remove_from_group("turrets")
		turret.queue_free()
	for coordinates in data.turrets:
		var turret := TURRET_SCENE.instantiate() as Node2D
		add_child(turret)
		turret.position = Vector2(coordinates[0], coordinates[1]) * get_arena_rect().size
	summary = "Welcome back. Your energy and turret layout are ready.\nBest run: %ds" % int(best_time)


func _valid_save(data: Variant) -> bool:
	if not data is Dictionary or data.get("version") != 1:
		return false
	for key in ["energy", "best_time"]:
		var value = data.get(key)
		if not (value is float or value is int):
			return false
		if not is_finite(float(value)) or value < 0:
			return false
	var positions = data.get("turrets")
	if not positions is Array or positions.is_empty():
		return false
	for point in positions:
		if not point is Array or point.size() != 2:
			return false
		for value in point:
			if not (value is float or value is int):
				return false
			if not is_finite(float(value)) or value < 0.0 or value > 1.0:
				return false
	return true
```

</details>

<details>
<summary>lantern.gd — M4 snapshot</summary>

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

var status_label: Label


func _ready() -> void:
	health = max_health
	get_viewport().size_changed.connect(_keep_inside_viewport)
	_center_in_viewport()

	# A CanvasLayer keeps the interface separate from world positioning.
	var hud := CanvasLayer.new()
	hud.layer = 3
	add_child(hud)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(status_label)
	_layout_status()
	get_viewport().size_changed.connect(_layout_status)

	_update_status()


func _process(delta: float) -> void:
	if not running:
		return
	hit_flash = maxf(0.0, hit_flash - delta)
	elapsed += delta
	energy += ENERGY_RATES[brightness] * delta

	_update_status()
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


func _unhandled_key_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_SPACE:
			brightness = (brightness + 1) % BRIGHTNESS_NAMES.size()
			_update_status()
			get_viewport().set_input_as_handled()


func _center_in_viewport() -> void:
	position = get_parent().get_arena_rect().get_center()


func _layout_status() -> void:
	status_label.position = Vector2(get_parent().get_arena_rect().end.x + 20.0, 24.0)
	status_label.size = Vector2(280, 220)


func _update_status() -> void:
	if not running:
		status_label.text = "PREPARATION\nHealth restored on Start run"
		return
	status_label.text = (
		"Health: %d / %d\nTime: %ds · Brightness: %s\nThis run: %d energy\n(+%.0f / second)\n\nWASD / Arrows: move\nSpace: brightness"
		% [
			int(ceil(health)),
			int(max_health),
			int(elapsed),
			BRIGHTNESS_NAMES[brightness],
			int(energy),
			ENERGY_RATES[brightness],
		]
	)


func _draw() -> void:
	var pulse: float = 1.0 + sin(elapsed * 2.0) * 0.08
	var glow_size: float = pulse * LIGHT_SCALES[brightness]

	draw_circle(Vector2.ZERO, 70.0 * glow_size, Color(1.0, 0.65, 0.2, 0.04))
	draw_circle(Vector2.ZERO, 48.0 * glow_size, Color(1.0, 0.65, 0.2, 0.08))
	draw_circle(Vector2.ZERO, 30.0 * glow_size, Color(1.0, 0.65, 0.2, 0.16))

	draw_circle(Vector2.ZERO, 12.0 * pulse, Color("#ffbd59"))
	draw_circle(Vector2.ZERO, 6.0 * pulse, Color("#fff2cf"))
	if hit_flash > 0.0:
		draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 32, Color("#ff6b6b"), 3.0, true)
```

</details>

<details>
<summary>build_controller.gd — M4 snapshot</summary>

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
	sidebar.color = Color("#1b2533")
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
	hint = Label.new()
	hint.add_theme_font_size_override("font_size", 18)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bar.add_child(hint)
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
	cancel_button.hide()
	_layout_sidebar()
	get_viewport().size_changed.connect(_layout_sidebar)
	_update_interface()


func _layout_sidebar() -> void:
	var arena: Rect2 = main.get_arena_rect()
	sidebar.position = Vector2(arena.end.x, 0)
	sidebar.size = Vector2(main.SIDEBAR_WIDTH, arena.size.y)
	bar.position = Vector2(arena.end.x + 20, 260)
	bar.size = Vector2(280, 0)


func _process(_delta: float) -> void:
	_update_interface()
	if placing:
		preview.global_position = get_global_mouse_position()
		var reason := placement_error(preview.global_position)
		var valid := reason.is_empty()
		preview.modulate = Color(0.6, 1.0, 0.7, 0.65) if valid else Color(1.0, 0.3, 0.3, 0.65)
		placement_hint.text = ("Click to move here · Free" if is_instance_valid(selected_turret) else "Click to build · %d energy" % int(turret_cost())) if valid else reason
		placement_hint.modulate = Color("#a5edb7") if valid else Color("#ffb4a8")
		placement_hint.reset_size()
		var mouse := get_viewport().get_mouse_position()
		var limit := (get_viewport_rect().size - placement_hint.size - Vector2(8, 8)).max(Vector2(8, 8))
		placement_hint.position = (mouse + Vector2(20, 24)).clamp(Vector2(8, 8), limit)


func turret_cost() -> float:
	var purchased := maxi(0, get_tree().get_nodes_in_group("turrets").size() - 1)
	return BASE_TURRET_COST + purchased * EXTRA_TURRET_COST


func _update_interface() -> void:
	# Parent _ready() has not run during this child's _ready(), so keep reads simple.
	var preparing: bool = main.phase == main.Phase.PREPARATION
	build_button.visible = preparing
	start_button.visible = preparing
	start_button.disabled = placing
	build_button.text = "Build turret — %d energy (B)" % int(turret_cost())
	build_button.disabled = placing or main.banked_energy < turret_cost()
	overview.text = ("Energy available: %d\n%s" % [int(main.banked_energy), main.summary]) if preparing else ("Saved energy: %d · Building unlocks after this run" % int(main.banked_energy))
	if not main.save_message.is_empty():
		overview.text += "\n" + main.save_message
	if placing:
		hint.text = "Move turret for free · Click to confirm · Esc to cancel" if is_instance_valid(selected_turret) else "Place new turret · Click to buy · Esc to cancel"
	elif not preparing:
		hint.text = "New enemies: %d hits · Tougher every 30s · Brightness attracts more" % int(main.current_enemy_health())
	elif main.banked_energy < turret_cost():
		hint.text = "Click a turret to move it · Need %d more energy to buy" % int(ceil(turret_cost() - main.banked_energy))
	else:
		hint.text = "Click a turret to move it, or buy another with B"


func _unhandled_input(event: InputEvent) -> void:
	if main.phase != main.Phase.PREPARATION:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_B:
			begin_placement()
			get_viewport().set_input_as_handled()
		elif placing and event.keycode == KEY_ESCAPE:
			cancel_placement()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ENTER:
			main.start_run()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = get_canvas_transform().affine_inverse() * event.position
		if placing:
			try_place(point)
		else:
			for turret in get_tree().get_nodes_in_group("turrets"):
				if point.distance_to(turret.global_position) <= 20.0:
					begin_move(turret)
					break
		get_viewport().set_input_as_handled()


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
	preview.global_position = get_global_mouse_position()
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
<summary>enemy.gd — M4 snapshot</summary>

```gdscript
extends Node2D

const CONTACT_DISTANCE: float = 20.0
const CONTACT_TOLERANCE: float = 0.1

@export var speed: float = 45.0
@export var contact_damage_per_second: float = 15.0
@export var max_health: float = 1.0

var health: float

var target: Node2D


func _ready() -> void:
	health = max_health
	add_to_group("enemies")
	queue_redraw()
	

func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return

	var distance: float = global_position.distance_to(target.global_position)

	# Contact damage scales with time, so frame rate does not change its strength.
	# Movement can stop a fraction of a pixel outside the intended distance.
	if distance <= CONTACT_DISTANCE + CONTACT_TOLERANCE:
		target.take_damage(contact_damage_per_second * delta)
		return
	if speed <= 0.0:
		return

	var step: float = minf(speed * delta, distance - CONTACT_DISTANCE)
	var time_to_contact: float = (distance - CONTACT_DISTANCE) / speed
	global_position = global_position.move_toward(
		target.global_position,
		step
	)
	# Count time after arriving this frame, not just contact at its beginning.
	# Otherwise a moving lantern can escape every pre-movement damage check.
	var contact_time: float = maxf(0.0, delta - time_to_contact)
	if contact_time > 0.0:
		target.take_damage(contact_damage_per_second * contact_time)


func take_damage(amount: float) -> void:
	if health <= 0.0 or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	if health <= 0.0:
		queue_free()
	queue_redraw()


func _draw() -> void:
	# A little purple creature with two bright eyes.
	draw_circle(Vector2.ZERO, 10.0, Color("#826caa"))
	draw_circle(Vector2(-3.0, -2.0), 2.0, Color("#ffe0a3"))
	draw_circle(Vector2(3.0, -2.0), 2.0, Color("#ffe0a3"))
	if max_health > 1.0:
		draw_rect(Rect2(-12, -18, 24, 3), Color("#35414e"))
		draw_rect(Rect2(-12, -18, 24 * health / max_health, 3), Color("#efb17b"))
```

</details>

<details>
<summary>turret.gd — M4 snapshot</summary>

```gdscript
extends Node2D

@export var attack_range: float = 220.0
@export var fire_interval: float = 1.5
@export var damage: float = 1.0

var cooldown: float = 0.0
var shot_time: float = 0.0
var shot_endpoint: Vector2 = Vector2.ZERO


func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	shot_time = maxf(0.0, shot_time - delta)

	if cooldown <= 0.0:
		var enemy: Node2D = _find_nearest_enemy()

		if enemy != null:
			shot_endpoint = enemy.global_position
			shot_time = 0.12
			cooldown = fire_interval
			enemy.take_damage(damage)

	queue_redraw()


func _find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var nearest_distance: float = attack_range

	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D

		if enemy == null or enemy.is_queued_for_deletion():
			continue

		var distance: float = global_position.distance_to(
			enemy.global_position
		)

		if distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance

	return nearest


func _draw() -> void:
	# A faint circle shows how far the turret can shoot.
	draw_arc(
		Vector2.ZERO,
		attack_range,
		0.0,
		TAU,
		64,
		Color(0.4, 0.8, 1.0, 0.15),
		1.0,
		true
	)

	# Turret body.
	draw_circle(Vector2.ZERO, 13.0, Color("#36566f"))
	draw_circle(Vector2.ZERO, 7.0, Color("#9bddff"))

	# A short flash connects the turret to its last target.
	if shot_time > 0.0:
		draw_line(
			Vector2.ZERO,
			to_local(shot_endpoint),
			Color("#bcecff"),
			2.0,
			true
		)
```

</details>

<details>
<summary>tests/check_runs.gd — M4 snapshot</summary>

```gdscript
extends SceneTree

var failures: int = 0
var path: String

func _initialize() -> void:
	path = "/tmp/little-last-light-m4-%d.json" % OS.get_process_id()
	call_deferred("check")

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func new_game() -> Node2D:
	var scene = load("res://main.tscn").instantiate()
	scene.save_path = path
	root.add_child(scene)
	current_scene = scene
	scene.set_process(false)
	scene.lantern.set_process(false)
	scene.lantern.set_physics_process(false)
	return scene

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	root.push_input(event)

func check() -> void:
	var game = new_game()
	var lantern = game.lantern
	var build = game.get_node("BuildController")
	await process_frame
	expect(game.phase == game.Phase.PREPARATION, "Starts in preparation")
	lantern._process(10)
	game._process(10)
	lantern.take_damage(10)
	expect(lantern.energy == 0 and lantern.elapsed == 0 and lantern.health == 100, "Preparation has no income, time, or damage")
	expect(get_nodes_in_group("enemies").is_empty(), "Preparation does not spawn enemies")
	key(KEY_B)
	expect(not build.placing, "Cannot buy without banked energy")
	var turret = get_nodes_in_group("turrets")[0]
	var original: Vector2 = turret.position
	build.begin_move(turret)
	key(KEY_ENTER)
	expect(game.phase == game.Phase.PREPARATION, "Cannot start mid-placement")
	key(KEY_ESCAPE)
	expect(turret.visible and turret.position == original and not build.placing, "Cancelled move restores original")
	key(KEY_ENTER)
	expect(game.phase == game.Phase.RUNNING and lantern.running, "Enter starts combat")
	game.banked_energy = 30.0
	key(KEY_B)
	build.begin_move(turret)
	expect(not build.placing, "Build and move locked during combat")
	var initial: float = game.current_spawn_interval()
	lantern._process(20)
	expect(is_equal_approx(game.current_spawn_interval(), initial / 2), "Pressure doubles at 20 seconds")
	lantern._process(5)
	lantern.brightness = 2
	expect(game.current_spawn_interval() < initial / 2, "Brightness adds pressure")
	lantern._process(1)
	expect(lantern.energy == 31.0, "Only this-run earnings belong to lantern")
	expect(game.save_progress(), "Mid-run save succeeds")
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	expect(data.energy == 61.0 and game.banked_energy == 30.0, "Autosave includes earnings without double banking")
	game._spawn_enemy()
	lantern.take_damage(1000)
	expect(game.phase == game.Phase.PREPARATION and game.banked_energy == 61.0 and lantern.energy == 0, "Death banks once")
	game._on_lantern_died()
	expect(game.banked_energy == 61.0, "Repeated death cannot duplicate currency")
	expect(get_nodes_in_group("enemies").is_empty() and not turret.can_process(), "Death clears enemies and stops turrets")
	key(KEY_B)
	expect(build.placing, "Can buy after death despite zero health")
	expect(not build.try_place(original) and not build.try_place(Vector2(-10, 0)), "Invalid placement rejected")
	var arena: Vector2 = game.get_arena_rect().size
	var spot := Vector2(arena.x * 0.85, arena.y * 0.35)
	expect(build.try_place(spot), "Preparation purchase succeeds")
	expect(game.banked_energy == 41.0 and get_nodes_in_group("turrets").size() == 2, "Purchase deducts 20 once")
	expect(not build.try_place(spot + Vector2(40, 0)), "Duplicate click cannot buy again")
	build.begin_move(turret)
	var moved := original + Vector2(0, -65)
	expect(build.try_place(moved), "Can reposition freely")
	expect(game.banked_energy == 41.0 and turret.position == moved, "Move costs no energy")
	game.start_run()
	expect(lantern.health == 100 and lantern.energy == 0 and lantern.elapsed == 0 and lantern.brightness == 0, "New run resets health, earnings, timer and brightness")
	expect(game.banked_energy == 41.0 and get_nodes_in_group("turrets").size() == 2 and turret.position == moved, "New run retains purchases and layout")
	lantern._process(3)
	game.save_progress()
	game.free()
	await process_frame
	game = new_game()
	expect(game.phase == game.Phase.PREPARATION and game.banked_energy == 44.0, "Reopening banks saved active-run earnings")
	expect(get_nodes_in_group("turrets").size() == 2, "Reopening restores all turrets")
	expect(get_nodes_in_group("turrets")[0].position.distance_to(moved) < 0.01, "Reopening restores positions")
	expect(game.best_time == 26.0, "Best completed run persists")
	game.free()
	await process_frame
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("broken save")
	file.close()
	game = new_game()
	expect(not game.save_is_readable and not game.save_progress(), "Corrupt save is not overwritten")
	expect(FileAccess.get_file_as_string(path) == "broken save", "Original corrupt file is preserved")
	game.free()
	await process_frame
	for empty_contents in ["", " \n\t "]:
		file = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(empty_contents)
		file.close()
		game = new_game()
		expect(game.save_is_readable and game.banked_energy == 0, "Empty save starts a fresh profile")
		game.start_run()
		game.lantern._process(7)
		game.lantern.take_damage(1000)
		expect(game.banked_energy == 7 and game.save_progress(), "Fresh profile saves earned energy")
		game.free()
		await process_frame
		game = new_game()
		expect(game.banked_energy == 7, "Energy from formerly empty save survives reopening")
		game.free()
		await process_frame
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("invalid")
	file.close()
	game = new_game()
	file = FileAccess.open(path, FileAccess.WRITE)
	file.close()
	expect(game.save_progress() and game.save_is_readable, "Clearing a bad file allows an open session to save again")
	game.free()
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".tmp")
	if failures == 0:
		print("PASS: phases, income, pressure, death banking, purchases, repositioning, fresh runs, save/reopen, corrupt save")
	quit(0 if failures == 0 else 1)
```

</details>

<details>
<summary>tests/check_difficulty.gd — M4 snapshot</summary>

```gdscript
extends SceneTree

var failures: int = 0

func _initialize() -> void:
	call_deferred("check")

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func check() -> void:
	var scene = load("res://main.tscn").instantiate()
	var path := "/tmp/little-last-light-difficulty-%d.json" % OS.get_process_id()
	scene.save_path = path
	root.add_child(scene)
	scene.set_process(false)
	scene.lantern.set_process(false)
	var build = scene.get_node("BuildController")
	await process_frame
	expect(build.turret_cost() == 20.0, "First extra turret costs 20")
	var another = load("res://turret.tscn").instantiate()
	scene.add_child(another)
	another.position = Vector2(scene.get_arena_rect().size.x * 0.85, 250)
	expect(build.turret_cost() == 30.0, "Second extra turret costs 30")
	expect(build.placement_error(Vector2(3, 300)) == "Too close to the arena edge", "Edge rejection explained")
	expect(build.placement_error(another.position) == "Too close to another turret", "Spacing rejection explained")
	expect(build.placement_error(scene.lantern.status_label.position + Vector2(10, 10)) == "Place inside the arena", "Sidebar is outside arena")
	expect(build.can_place_at(Vector2(30, 30)), "Former top-left HUD location is buildable")
	var arena: Rect2 = scene.get_arena_rect()
	var empty_bottom := Vector2(arena.size.x * 0.5, arena.size.y - 36)
	expect(build.can_place_at(empty_bottom), "Empty bottom area is no longer blocked by the container")
	build.begin_move(another)
	expect(build.turret_cost() == 30.0, "Preview and moving a turret do not change price")
	expect(build.try_place(empty_bottom), "Free relocation can use empty bottom area")
	expect(scene.banked_energy == 0.0, "Relocation still free")
	scene.start_run()
	expect(scene.get_arena_rect() == arena, "Arena dimensions do not change on Start")
	expect(scene.lantern.position == arena.get_center(), "Lantern starts at arena center")
	scene.lantern.position = Vector2(10000, 10000)
	scene.lantern._keep_inside_viewport()
	expect(arena.has_point(scene.lantern.position), "Lantern cannot enter sidebar")
	scene.lantern._center_in_viewport()
	for index in range(100):
		expect(arena.has_point(scene._random_edge_position()), "Spawns stay inside arena")
	scene._set_turrets_active(false)
	expect(scene.current_enemy_health() == 1.0, "Initial enemies take one hit")
	expect(scene.current_enemy_speed() == 100.0, "Initial enemies are faster than M3")
	scene.lantern.elapsed = 29.9
	expect(scene.current_enemy_health() == 1.0, "No toughness increase before threshold")
	scene.lantern.elapsed = 30.0
	expect(scene.current_enemy_health() == 2.0, "New enemies take two hits at 30 seconds")
	scene._spawn_enemy()
	var enemy = get_nodes_in_group("enemies")[0]
	expect(enemy.speed == 190.0, "Enemy speed scales with spawn time")
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	expect(enemy.health == 2.0 and enemy.max_health == 2.0, "Spawn applies toughness before ready")
	scene.lantern.health = 100.0
	enemy.speed = 320.0
	enemy.global_position = scene.lantern.global_position + Vector2(20.0, 0)
	for frame in range(60):
		scene.lantern.position.x -= scene.lantern.move_speed / 60.0
		enemy._process(1.0 / 60.0)
	expect(scene.lantern.health < 96.0, "Faster pursuer damages a lantern moving away every frame")
	scene.lantern._center_in_viewport()
	scene.lantern.health = 100.0
	enemy.speed = 100.0
	enemy.global_position = scene.lantern.global_position + Vector2(30.0, 0)
	enemy._process(0.2)
	expect(is_equal_approx(scene.lantern.health, 98.5), "Only the remaining 0.1 seconds after arrival causes damage")
	enemy.take_damage(1.0)
	expect(enemy.health == 1.0 and not enemy.is_queued_for_deletion(), "Tough enemy survives first hit")
	enemy.take_damage(1.0)
	expect(enemy.is_queued_for_deletion(), "Tough enemy dies on second hit")
	scene.lantern.elapsed = 1000.0
	expect(scene.current_enemy_speed() > scene.lantern.move_speed and scene.current_enemy_speed() == 320.0, "Late arrivals can catch the lantern and speed is capped")
	var previous: float = scene.current_enemy_health()
	scene.lantern.elapsed += 30.0
	expect(scene.current_enemy_health() > previous, "Toughness continues after spawn interval reaches its floor")
	scene.lantern.take_damage(1000)
	scene.start_run()
	expect(scene.current_enemy_health() == 1.0, "Next run resets toughness")
	expect(scene.current_enemy_speed() == 100.0, "Next run resets enemy speed")
	scene.free()
	DirAccess.remove_absolute(path)
	if failures == 0:
		print("PASS: prices, arena/sidebar separation, buildable former HUD areas, consistent phases, spawn/movement bounds, multi-hit enemies, continuing pressure")
	quit(0 if failures == 0 else 1)
```

</details>

<details>
<summary>tests/check_health.gd — M4 snapshot</summary>

```gdscript
extends SceneTree

var deaths: int = 0

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var scene = load("res://main.tscn").instantiate()
	var test_path := "/tmp/little-last-light-health-%d.json" % OS.get_process_id()
	scene.save_path = test_path
	root.add_child(scene)
	current_scene = scene
	scene.start_run()
	var lantern = scene.get_node("Lantern")
	scene.set_process(false)
	lantern.set_process(false)
	scene.get_node("Turret").set_process(false)
	lantern.died.connect(func(): deaths += 1)
	scene._spawn_enemy()
	var enemy = get_nodes_in_group("enemies")[0]
	enemy.set_process(false)
	# Approach naturally from many angles; teleporting into contact misses rounding bugs.
	var missed_contacts := 0
	for angle in range(0, 360, 5):
		lantern.health = 100.0
		enemy.global_position = lantern.global_position + Vector2.from_angle(deg_to_rad(angle)) * 100.0
		for frame in range(180):
			enemy._process(1.0 / 60.0)
		if lantern.health >= 99.0:
			missed_contacts += 1
	if missed_contacts > 0:
		printerr("FAIL: enemies reached the edge but did not damage the lantern from %d / 72 angles" % missed_contacts)
		quit(1)
		return
	lantern.health = 100.0
	enemy.global_position = lantern.global_position + Vector2(100, 0)
	enemy._process(0.5)
	assert(lantern.health == 100.0, "No damage outside contact range")
	enemy.global_position = lantern.global_position
	enemy._process(0.5)
	assert(lantern.health == 92.5, "Contact damage uses elapsed time")
	lantern.take_damage(-10)
	assert(lantern.health == 92.5, "Negative damage ignored")
	lantern.set_process(true)
	scene.set_process(true)
	lantern.take_damage(1000)
	lantern.take_damage(1000)
	assert(lantern.health == 0 and deaths == 1, "Death emits once and health clamps")
	assert(scene.phase == scene.Phase.PREPARATION and not lantern.running, "Death returns to preparation")
	var energy: float = lantern.energy
	var progress: float = scene.spawn_progress
	await process_frame
	await process_frame
	assert(lantern.energy == energy and scene.spawn_progress == progress, "Run freezes")
	scene.get_node("BuildController").start_button.pressed.emit()
	assert(not paused and scene.phase == scene.Phase.RUNNING, "Start begins a fresh run")
	assert(current_scene.lantern.health == 100.0, "Restart restores health")
	assert(current_scene.lantern.energy < 1.0 and get_nodes_in_group("enemies").is_empty(), "Fresh run state")
	print("PASS: 72 contact approaches, damage, death, preparation freeze, fresh run")
	scene.free()
	DirAccess.remove_absolute(test_path)
	quit()
```

</details>
