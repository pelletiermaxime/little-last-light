extends Node2D

enum Phase { PREPARATION, RUNNING }

const SIDEBAR_WIDTH: float = 320.0

const ENEMY_SCENE: PackedScene = preload("res://enemy.tscn")
const CHARGER_SCENE: PackedScene = preload("res://charger.tscn")
const FIRST_CHARGER_TIME: float = 20.0
const CHARGER_INTERVAL: float = 8.0
const MIN_CHARGER_INTERVAL: float = 5.0
const CHARGER_RAMP_END: float = 120.0
const MAX_CHARGERS: int = 4
const TURRET_SCENE: PackedScene = preload("res://turret.tscn")
const SPAWN_INTERVALS: Array[float] = [2.0, 1.2, 0.65]
const PRESSURE_RAMP_SECONDS: float = 20.0
const TOUGHNESS_STEP_SECONDS: float = 30.0
const BASE_ENEMY_SPEED: float = 85.0

@export var save_path: String = "user://progress-v1.json"
@onready var lantern: Node2D = $Lantern

var phase: Phase = Phase.PREPARATION
var banked_energy: float = 0.0
var best_time: float = 0.0
var spawn_progress: float = 0.0
var next_charger_time: float = FIRST_CHARGER_TIME
var autosave_elapsed: float = 0.0
var summary: String = "Arrange your defense, then start your first run."
var save_message: String = ""
var previous_viewport_size: Vector2
var save_is_readable: bool = true
var last_run: Dictionary = {}
var run_energy_invested: float = 0.0
# Running from the editor uses local records; export templates use the stamped release.
var game_version: String = "dev" if OS.has_feature("editor") else str(ProjectSettings.get_setting("application/config/version", "0.0.1"))
var version_bests: Dictionary = {}
var legacy_best_time: float = 0.0
var leaderboard_profile: Dictionary = {"token": "", "username": "", "pending": {}}


func _ready() -> void:
	previous_viewport_size = get_arena_rect().size
	$Turret.position = lantern.position + Vector2(80.0, 0.0)
	lantern.died.connect(_on_lantern_died)
	load_progress()
	if leaderboard_profile.token.is_empty():
		leaderboard_profile.token = Crypto.new().generate_random_bytes(32).hex_encode()
	_set_turrets_active(false)
	lantern._update_status()
	get_viewport().size_changed.connect(_resize_layout)
	get_tree().auto_accept_quit = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()


func quit_game() -> void:
	# Share the normal window-close save behavior with the preparation button.
	if save_progress() or not save_is_readable:
		get_tree().quit()


func start_run() -> void:
	if phase != Phase.PREPARATION or $BuildController.placing:
		return
	_clear_enemies()
	# Snapshot the defense budget before the run. Unspent savings do not help survival.
	run_energy_invested = $BuildController.layout_refund()
	lantern.health = lantern.max_health
	lantern.energy = 0.0
	lantern.elapsed = 0.0
	lantern.brightness = 0
	lantern.hit_flash = 0.0
	lantern._center_in_viewport()
	spawn_progress = 0.0
	next_charger_time = FIRST_CHARGER_TIME
	autosave_elapsed = 0.0
	phase = Phase.RUNNING
	lantern.running = true
	_set_turrets_active(true)
	lantern._update_status()


func _on_lantern_died() -> void:
	end_run()


func end_run(voluntary: bool = false) -> void:
	if phase != Phase.RUNNING:
		return
	phase = Phase.PREPARATION
	lantern.running = false
	# Capture the result before banking clears this run's energy.
	last_run = {"duration": lantern.elapsed, "energy": lantern.energy, "new_best": lantern.elapsed > best_time, "voluntary": voluntary}
	best_time = maxf(best_time, lantern.elapsed)
	version_bests[game_version] = best_time
	if last_run.new_best and game_version != "dev":
		leaderboard_profile.pending = {
			"version": game_version,
			"durationMs": maxi(1, int(lantern.elapsed * 1000.0)),
			"energyEarned": lantern.energy,
			"energyInvested": run_energy_invested,
			"turretLayout": _run_turret_layout(),
		}
	var result := "Run ended" if voluntary else "The light went out"
	summary = "%s · %ds survived · +%d energy\nImprove your layout and try again. Best: %ds" % [result, int(lantern.elapsed), int(lantern.energy), int(best_time)]
	banked_energy += lantern.energy
	lantern.energy = 0.0
	_clear_enemies()
	_set_turrets_active(false)
	lantern._update_status()
	save_progress()


func _run_turret_layout() -> Dictionary:
	var size := get_arena_rect().size
	var turrets: Array = []
	for turret in get_tree().get_nodes_in_group("turrets"):
		var point: Vector2 = turret.position / size
		turrets.append({"x": point.x, "y": point.y})
	return {"width": size.x, "height": size.y, "turrets": turrets}


func _clear_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.remove_from_group("chargers")
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
	# Basic pursuers never gain speed with time. Open space is a reliable escape.
	return BASE_ENEMY_SPEED


func _process(delta: float) -> void:
	if phase != Phase.RUNNING:
		return
	spawn_progress += delta / current_spawn_interval()
	if spawn_progress >= 1.0:
		spawn_progress -= 1.0
		_spawn_enemy()
	if lantern.elapsed >= next_charger_time:
		# Brightness changes basic spawn pressure, not the charger's warning cadence.
		next_charger_time = lantern.elapsed + current_charger_interval()
		_spawn_charger()
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


func current_charger_interval() -> float:
	var progress := clampf((lantern.elapsed - FIRST_CHARGER_TIME) / (CHARGER_RAMP_END - FIRST_CHARGER_TIME), 0.0, 1.0)
	return lerpf(CHARGER_INTERVAL, MIN_CHARGER_INTERVAL, progress)


func _spawn_charger() -> void:
	if phase != Phase.RUNNING or get_tree().get_nodes_in_group("chargers").size() >= MAX_CHARGERS:
		return
	var charger := CHARGER_SCENE.instantiate() as Node2D
	charger.target = lantern
	charger.max_health = maxf(3.0, current_enemy_health() + 1.0)
	add_child(charger)
	charger.global_position = _random_edge_position()


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
	var data := {"version": 1, "energy": banked_energy + lantern.energy, "best_time": best_time, "turrets": positions, "version_bests": version_bests, "legacy_best_time": legacy_best_time, "leaderboard": leaderboard_profile}
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
	# A legacy record's release cannot be inferred; preserve it separately.
	legacy_best_time = float(data.get("legacy_best_time", data.best_time if not data.has("version_bests") else 0.0))
	version_bests = data.get("version_bests", {})
	best_time = float(version_bests.get(game_version, 0.0))
	leaderboard_profile = data.get("leaderboard", {"token": "", "username": "", "pending": {}})
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
	var records = data.get("version_bests", {})
	if not records is Dictionary:
		return false
	for record in records.values():
		if not (record is float or record is int) or not is_finite(float(record)) or record < 0:
			return false
	var legacy = data.get("legacy_best_time", 0.0)
	if not (legacy is float or legacy is int) or not is_finite(float(legacy)) or legacy < 0:
		return false
	var profile = data.get("leaderboard", {"token": "", "username": "", "pending": {}})
	if not profile is Dictionary or not profile.get("token") is String or not profile.get("username") is String or not profile.get("pending") is Dictionary:
		return false
	if not profile.token.is_empty():
		var token_pattern := RegEx.new()
		token_pattern.compile("^[a-f0-9]{64}$")
		if token_pattern.search(profile.token) == null:
			return false
	var pending: Dictionary = profile.pending
	if not pending.is_empty():
		var duration = pending.get("durationMs")
		if not pending.get("version") is String or not (duration is int or duration is float):
			return false
		if not is_finite(float(duration)) or duration < 1 or duration != floor(duration):
			return false
		for key in ["energyEarned", "energyInvested", "totalEnergy"]:
			if pending.has(key):
				var value = pending[key]
				if not (value is int or value is float) or not is_finite(float(value)) or value < 0:
					return false
		if pending.has("turretLayout") and not _valid_run_layout(pending.turretLayout):
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


func _valid_run_layout(layout: Variant) -> bool:
	if not layout is Dictionary or not layout.get("turrets") is Array:
		return false
	for key in ["width", "height"]:
		var size = layout.get(key)
		if not (size is int or size is float) or not is_finite(float(size)) or size <= 0:
			return false
	for point in layout.turrets:
		if not point is Dictionary:
			return false
		for key in ["x", "y"]:
			var value = point.get(key)
			if not (value is int or value is float) or not is_finite(float(value)) or value < 0 or value > 1:
				return false
	return true
