extends Node

const ENEMY_SCENE: PackedScene = preload("res://enemies/enemy.tscn")
const CHARGER_SCENE: PackedScene = preload("res://enemies/charger.tscn")
const BOSS_SCRIPT = preload("res://bosses/water_boss.gd")
const BOSS_TIME: float = 300.0
const FINAL_BOSS_SCRIPT = preload("res://bosses/snuffer.gd")
const FINAL_BOSS_TIME: float = 900.0
const RAINKEEPER_SCRIPT = preload("res://bosses/rainkeeper.gd")
const RAINKEEPER_TIME := 600.0
const ENCOUNTER_SCHEDULE = preload("res://game/encounter_schedule.gd")
const FIRST_CHARGER_TIME: float = 20.0
const CHARGER_INTERVAL: float = 4.0
const MIN_CHARGER_INTERVAL: float = 2.5
const CHARGER_RAMP_END: float = 120.0
const MAX_CHARGERS: int = 8
const SPAWN_INTERVALS: Array[float] = [2.0, 1.2, 0.65]
const MIN_SPAWN_INTERVALS: Array[float] = [0.25, 0.15, 0.10]
const PRESSURE_RAMP_SECONDS: float = 20.0
const TOUGHNESS_STEP_SECONDS: float = 30.0
const BASE_ENEMY_SPEED: float = 85.0

var game: Node2D
@onready var lantern: Node2D = game.get_node("Lantern")

var spawn_progress: float = 0.0
var boss_spawned: bool = false
var final_boss_spawned: bool = false
# Overridden only by isolated encounter launchers; normal runs use 15:00.
var final_boss_time: float = FINAL_BOSS_TIME
var rainkeeper_spawned := false
var next_charger_time: float = FIRST_CHARGER_TIME


func reset() -> void:
	spawn_progress = 0.0
	boss_spawned = false
	final_boss_spawned = false
	rainkeeper_spawned = false
	next_charger_time = FIRST_CHARGER_TIME


func update(delta: float) -> void:
	if game.phase != game.Phase.RUNNING:
		return
	update_final_encounter()
	update_rainkeeper_encounter()
	if not boss_spawned and lantern.elapsed >= BOSS_TIME:
		_spawn_boss()
	spawn_progress += delta / current_spawn_interval()
	if spawn_progress >= 1.0:
		spawn_progress -= 1.0
		_spawn_enemy()
	if not ENCOUNTER_SCHEDULE.chargers_enabled(lantern.elapsed):
		# No accumulated charger debt or burst when a recovery ends.
		next_charger_time = lantern.elapsed
	elif lantern.elapsed >= next_charger_time:
		# Brightness changes basic spawn pressure, not the charger's warning cadence.
		next_charger_time = lantern.elapsed + current_charger_interval()
		_spawn_charger()


func current_spawn_interval() -> float:
	var rate := ENCOUNTER_SCHEDULE.pursuer_rate_multiplier(lantern.elapsed)
	if rate <= 0.0:
		return INF
	# Continue slower growth after the opening, with distinct brightness caps.
	var ramp := 1.0 + minf(lantern.elapsed, 100.0) / PRESSURE_RAMP_SECONDS
	ramp += clampf((lantern.elapsed - 100.0) / 100.0, 0.0, 4.0)
	return maxf(MIN_SPAWN_INTERVALS[lantern.brightness], SPAWN_INTERVALS[lantern.brightness] / ramp) / rate


func current_enemy_health() -> float:
	# Toughness keeps growing after the performance-safe spawn caps.
	return 1.0 + floorf(lantern.elapsed / TOUGHNESS_STEP_SECONDS) + floorf(maxf(0.0, lantern.elapsed - 300.0) / 45.0)


func current_enemy_speed() -> float:
	# Basic pursuers never gain speed with time. Open space is a reliable escape.
	return BASE_ENEMY_SPEED


func update_final_encounter() -> bool:
	if game.phase != game.Phase.RUNNING:
		return false
	if not final_boss_spawned and lantern.elapsed >= final_boss_time:
		final_boss_spawned = true
		# Final arrival adds pressure: existing enemies and water stay until defeated
		# or the run ends. Ordinary spawning continues throughout final combat.
		var boss := FINAL_BOSS_SCRIPT.new()
		boss.target = lantern
		boss.position = _opposite_corner()
		boss.defeated.connect(game._on_final_boss_defeated)
		game.add_child(boss)
		game.get_node("GameHUD").refresh()
	return final_boss_spawned


func update_rainkeeper_encounter() -> void:
	if game.phase != game.Phase.RUNNING or rainkeeper_spawned or final_boss_spawned or lantern.elapsed < RAINKEEPER_TIME:
		return
	rainkeeper_spawned = true
	var boss := RAINKEEPER_SCRIPT.new()
	boss.target = lantern
	boss.position = _opposite_corner()
	game.add_child(boss)
	game.get_node("GameHUD").refresh()


func _spawn_boss() -> void:
	if game.phase != game.Phase.RUNNING or boss_spawned or final_boss_spawned:
		return
	boss_spawned = true
	var boss := BOSS_SCRIPT.new()
	boss.target = lantern
	boss.defeated.connect(game._on_drencher_defeated)
	# Arrive at the farthest inset corner, giving space and a visible warning.
	var size: Vector2 = game.get_arena_rect().size
	var corners: Array[Vector2] = [Vector2(44, 44), Vector2(size.x - 44, 44), size - Vector2(44, 44), Vector2(44, size.y - 44)]
	boss.position = corners[0]
	for point in corners:
		if point.distance_squared_to(lantern.position) > boss.position.distance_squared_to(lantern.position):
			boss.position = point
	game.add_child(boss)
	game.get_node("GameHUD").refresh()


func _spawn_enemy() -> void:
	if game.phase != game.Phase.RUNNING or not ENCOUNTER_SCHEDULE.ordinary_spawns_enabled(lantern.elapsed):
		return
	var enemy := ENEMY_SCENE.instantiate() as Node2D
	enemy.target = lantern
	enemy.max_health = current_enemy_health()
	enemy.speed = current_enemy_speed()
	game.add_child(enemy)
	enemy.global_position = _random_edge_position()


func current_charger_interval() -> float:
	var progress := clampf((lantern.elapsed - FIRST_CHARGER_TIME) / (CHARGER_RAMP_END - FIRST_CHARGER_TIME), 0.0, 1.0)
	var interval := lerpf(CHARGER_INTERVAL, MIN_CHARGER_INTERVAL, progress)
	interval -= 0.5 * clampf((lantern.elapsed - 120.0) / 480.0, 0.0, 1.0)
	if ENCOUNTER_SCHEDULE.period(lantern.elapsed) == "Gathering":
		return interval * 2.0
	# Recovery retains breathing room even after chargers join it at five minutes.
	return maxf(12.0, interval * 3.0) if ENCOUNTER_SCHEDULE.period(lantern.elapsed) == "Recovery" else interval


func _spawn_charger() -> void:
	if game.phase != game.Phase.RUNNING or not ENCOUNTER_SCHEDULE.ordinary_spawns_enabled(lantern.elapsed) or get_tree().get_nodes_in_group("chargers").size() >= MAX_CHARGERS:
		return
	var charger := CHARGER_SCENE.instantiate() as Node2D
	charger.target = lantern
	charger.max_health = maxf(3.0, current_enemy_health() + 1.0)
	game.add_child(charger)
	charger.global_position = _random_edge_position()


func _random_edge_position() -> Vector2:
	var size: Vector2 = game.get_arena_rect().size
	match randi_range(0, 3):
		0: return Vector2(16, randf_range(16, size.y - 16))
		1: return Vector2(size.x - 16, randf_range(16, size.y - 16))
		2: return Vector2(randf_range(16, size.x - 16), 16)
		_: return Vector2(randf_range(16, size.x - 16), size.y - 16)


func _opposite_corner() -> Vector2:
	var size: Vector2 = game.get_arena_rect().size
	return Vector2(48 if lantern.position.x > size.x / 2.0 else size.x - 48, 64 if lantern.position.y > size.y / 2.0 else size.y - 64)
