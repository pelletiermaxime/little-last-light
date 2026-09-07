extends Node2D

enum Phase { PREPARATION, RUNNING, RESULTS }

const ENEMY_SCENE: PackedScene = preload("res://enemy.tscn")
const CHARGER_SCENE: PackedScene = preload("res://charger.tscn")
const BOSS_SCRIPT = preload("res://water_boss.gd")
const BOSS_TIME: float = 300.0
const BOSS_ENERGY_REWARD: float = 300.0
const FINAL_BOSS_SCRIPT = preload("res://snuffer.gd")
const FINAL_BOSS_TIME: float = 900.0
const RAINKEEPER_SCRIPT = preload("res://rainkeeper.gd")
const RAINKEEPER_TIME := 600.0
const ENCOUNTER_SCHEDULE = preload("res://encounter_schedule.gd")
const FIRST_CHARGER_TIME: float = 20.0
const CHARGER_INTERVAL: float = 4.0
const MIN_CHARGER_INTERVAL: float = 2.5
const CHARGER_RAMP_END: float = 120.0
const MAX_CHARGERS: int = 8
const TURRET_SCENE: PackedScene = preload("res://turret.tscn")
const PULSE_TURRET_SCENE: PackedScene = preload("res://pulse_turret.tscn")
const SNIPER_TURRET_SCENE: PackedScene = preload("res://sniper_turret.tscn")
const EMBER_TURRET_SCENE: PackedScene = preload("res://ember_turret.tscn")
const SPAWN_INTERVALS: Array[float] = [2.0, 1.2, 0.65]
const MIN_SPAWN_INTERVALS: Array[float] = [0.25, 0.15, 0.10]
const PRESSURE_RAMP_SECONDS: float = 20.0
const TOUGHNESS_STEP_SECONDS: float = 30.0
const BASE_ENEMY_SPEED: float = 85.0
const MAX_UPGRADE_LEVEL: int = 5
const UPGRADE_BASE_COSTS: Dictionary = {"damage": 120.0, "fire_rate": 100.0, "health": 80.0, "slow_rate": 120.0, "slow_strength": 160.0, "slow_duration": 100.0, "energy": 100.0, "proximity": 150.0}

# The future settings menu can assign fps_limit; 0 means unlimited.
@export_range(0, 360, 1, "or_greater") var fps_limit: int = 100:
	set(value):
		fps_limit = maxi(value, 0)
		Engine.max_fps = fps_limit

@export var save_path: String = "user://progress-v1.json"
@onready var lantern: Node2D = $Lantern

var phase: Phase = Phase.PREPARATION
var pickups: Node2D
var banked_energy: float = 0.0
var damage_level: int = 0
var fire_rate_level: int = 0
var health_level: int = 0
var energy_level: int = 0
var proximity_level: int = 0
var boss_reward_earned: bool = false
var boss_reward_amount: float = 0.0
var boss_reward_notice_until: float = 0.0
var slow_levels: Dictionary = {"slow_rate": 0, "slow_strength": 0, "slow_duration": 0}
var best_time: float = 0.0
var spawn_progress: float = 0.0
var boss_spawned: bool = false
var final_boss_spawned: bool = false
# Overridden only by the isolated interactive test launcher; normal runs use 15:00.
var final_boss_time: float = FINAL_BOSS_TIME
var rainkeeper_spawned := false
var version_clears: Dictionary = {}
var next_charger_time: float = FIRST_CHARGER_TIME
var autosave_elapsed: float = 0.0
var summary: String = "Arrange your defense, then start your first run."
var save_message: String = ""
var previous_viewport_size: Vector2
var save_is_readable: bool = true
var last_run: Dictionary = {}
var run_energy_invested: float = 0.0
# Editor runs share the dev leaderboard; exports use the stamped release.
var game_version: String = "dev" if OS.has_feature("editor") else str(ProjectSettings.get_setting("application/config/version", "0.0.1"))
var version_bests: Dictionary = {}
var legacy_best_time: float = 0.0
var leaderboard_profile: Dictionary = {"token": "", "username": "", "pending": {}}


func _ready() -> void:
	Engine.max_fps = fps_limit
	previous_viewport_size = get_arena_rect().size
	$Turret.position = lantern.position + Vector2(80.0, 0.0)
	lantern.died.connect(_on_lantern_died)
	pickups = preload("res://run_pickups.gd").new()
	add_child(pickups)
	load_progress()
	configure_lantern()
	for turret in get_tree().get_nodes_in_group("turrets"):
		configure_turret(turret)
	if leaderboard_profile.token.is_empty():
		leaderboard_profile.token = Crypto.new().generate_random_bytes(32).hex_encode()
	_set_turrets_active(false)
	lantern._update_status()
	get_viewport().size_changed.connect(_resize_layout)
	get_tree().auto_accept_quit = false


func turret_damage() -> float:
	return 1.0 + 1.5 * damage_level


func turret_shots_per_second() -> float:
	return (1.0 + 0.25 * fire_rate_level) / 1.5


func lantern_max_health() -> float:
	return 25.0 + 15.0 * health_level


func configure_lantern() -> void:
	# Only called in preparation, after loading or purchasing an upgrade.
	lantern.max_health = lantern_max_health()
	lantern.health = lantern.max_health


func configure_turret(turret: Node2D) -> void:
	if turret.turret_type == "ember":
		# Keep the selected prototype's tuning fixed during comparison with Watchlight.
		return
	if turret.turret_type == "pulse":
		turret.fire_interval = slow_interval()
		turret.slow_factor = 1.0 - slow_strength()
		turret.slow_duration = slow_duration()
		return
	turret.damage = turret_damage()
	turret.fire_interval = 1.0 / turret_shots_per_second()
	if turret.turret_type == "sniper":
		turret.damage *= turret.STAT_MULTIPLIER
		turret.fire_interval *= turret.STAT_MULTIPLIER


func turret_scene(kind: String) -> PackedScene:
	match kind:
		"pulse": return PULSE_TURRET_SCENE
		"sniper": return SNIPER_TURRET_SCENE
		"ember": return EMBER_TURRET_SCENE
		_: return TURRET_SCENE


func slow_interval() -> float:
	return 3.0 - 0.15 * slow_levels.slow_rate


func slow_strength() -> float:
	return 0.45 + 0.05 * slow_levels.slow_strength


func slow_duration() -> float:
	return 1.3 + 0.15 * slow_levels.slow_duration


func upgrade_levels() -> Dictionary:
	var levels := {"damage": damage_level, "fire_rate": fire_rate_level, "health": health_level, "energy": energy_level, "proximity": proximity_level}
	levels.merge(slow_levels)
	return levels


func energy_multiplier() -> float:
	return 1.0 + 0.25 * energy_level


func proximity_multiplier() -> float:
	return 1.5 + 0.1 * proximity_level


func upgrade_cost(kind: String) -> float:
	if not UPGRADE_BASE_COSTS.has(kind):
		return INF
	return UPGRADE_BASE_COSTS[kind] * pow(2.0, upgrade_levels()[kind])


func defense_investment() -> float:
	var invested: float = $BuildController.layout_refund()
	# Upgrade prices double; their cumulative cost is next price minus base price.
	for kind in UPGRADE_BASE_COSTS:
		invested += upgrade_cost(kind) - UPGRADE_BASE_COSTS[kind]
	return invested


func buy_upgrade(kind: String) -> bool:
	if phase != Phase.PREPARATION or $BuildController.placing:
		return false
	if not UPGRADE_BASE_COSTS.has(kind):
		return false
	var level: int = upgrade_levels()[kind]
	var cost := upgrade_cost(kind)
	if level >= MAX_UPGRADE_LEVEL or banked_energy < cost:
		return false
	banked_energy -= cost
	if kind == "damage":
		damage_level += 1
	elif kind == "fire_rate":
		fire_rate_level += 1
	elif kind == "health":
		health_level += 1
		configure_lantern()
	elif kind == "energy":
		energy_level += 1
	elif kind == "proximity":
		proximity_level += 1
	else:
		slow_levels[kind] += 1
	for turret in get_tree().get_nodes_in_group("turrets"):
		configure_turret(turret)
	save_progress()
	$BuildController._update_interface()
	lantern._update_status()
	get_node("/root/GameAudio").play(&"upgrade")
	return true


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()


func quit_game() -> void:
	# Share the normal window-close save behavior with the preparation button.
	get_node("/root/DisplaySettings").remember_window_size()
	if save_progress() or not save_is_readable:
		get_tree().quit()


func start_run() -> void:
	if phase != Phase.PREPARATION or $BuildController.placing:
		return
	get_node("/root/GameAudio").play(&"confirm")
	_clear_enemies()
	pickups.reset()
	# Snapshot the defense budget before the run. Unspent savings do not help survival.
	run_energy_invested = defense_investment()
	lantern.health = lantern.max_health
	lantern.energy = 0.0
	lantern.elapsed = 0.0
	lantern.brightness = 0
	lantern.hit_flash = 0.0
	lantern.projectile_grace_remaining = 0.0
	lantern._center_in_viewport()
	spawn_progress = 0.0
	boss_spawned = false
	boss_reward_earned = false
	boss_reward_amount = 0.0
	boss_reward_notice_until = 0.0
	final_boss_spawned = false
	rainkeeper_spawned = false
	next_charger_time = FIRST_CHARGER_TIME
	autosave_elapsed = 0.0
	phase = Phase.RUNNING
	lantern.running = true
	_set_turrets_active(true)
	lantern._update_status()


func _on_lantern_died() -> void:
	end_run()


func end_run(voluntary: bool = false, victory: bool = false) -> void:
	if phase != Phase.RUNNING:
		return
	phase = Phase.RESULTS
	get_tree().paused = false
	lantern.running = false
	pickups.reset()
	# Capture the result before banking clears this run's energy.
	var survival := minf(lantern.elapsed, final_boss_time)
	var previous_clear := float(version_clears.get(game_version, 0.0))
	var new_clear: bool = victory and (previous_clear == 0.0 or lantern.elapsed < previous_clear)
	last_run = {"duration": lantern.elapsed, "survival": survival, "victory": victory, "energy": lantern.energy, "new_best": new_clear if victory else survival > best_time, "voluntary": voluntary}
	last_run.boss_bonus = boss_reward_amount
	best_time = maxf(best_time, survival)
	if new_clear:
		version_clears[game_version] = lantern.elapsed
	version_bests[game_version] = best_time
	if new_clear or (last_run.new_best and previous_clear == 0.0):
		leaderboard_profile.pending = {
			"version": game_version,
			"durationMs": maxi(1, int(survival * 1000.0)),
			"energyEarned": lantern.energy,
			"energyInvested": run_energy_invested,
			"turretLayout": _run_turret_layout(),
		}
		if victory:
			leaderboard_profile.pending.clearTimeMs = int(lantern.elapsed * 1000.0)
	var result := "Run ended" if voluntary else "The light went out"
	summary = "%s · %ds survived · +%d energy\nImprove your layout and try again. Best: %ds" % [result, int(lantern.elapsed), int(lantern.energy), int(best_time)]
	if victory:
		summary = "Dawn has come · cleared in %ds · +%d energy" % [int(lantern.elapsed), int(lantern.energy)]
	banked_energy += lantern.energy
	lantern.energy = 0.0
	_clear_enemies()
	_set_turrets_active(false)
	lantern._update_status()
	save_progress()
	$ResultsScreen.show_results()


func continue_to_preparation() -> void:
	if phase != Phase.RESULTS:
		return
	get_node("/root/GameAudio").play(&"confirm")
	phase = Phase.PREPARATION
	$ResultsScreen.hide_results()
	$PreparationUI.open_view(0)
	$BuildController._update_interface()
	lantern._update_status()


func _run_turret_layout() -> Dictionary:
	var size := get_arena_rect().size
	var turrets: Array = []
	for turret in get_tree().get_nodes_in_group("turrets"):
		var point: Vector2 = turret.position / size
		turrets.append({"x": point.x, "y": point.y, "type": turret.turret_type})
	return {
		"width": size.x, "height": size.y, "turrets": turrets,
		"upgrades": {"damage": damage_level, "fireRate": fire_rate_level, "health": health_level},
	}


func _clear_enemies() -> void:
	for hazard in get_tree().get_nodes_in_group("hazards"):
		hazard.process_mode = Node.PROCESS_MODE_DISABLED
		hazard.remove_from_group("hazards")
		hazard.remove_from_group("enemy_projectiles")
		hazard.queue_free()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.remove_from_group("bosses")
		enemy.remove_from_group("final_bosses")
		enemy.remove_from_group("rainkeepers")
		enemy.remove_from_group("chargers")
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.remove_from_group("enemies")
		enemy.queue_free()


func _set_turrets_active(active: bool) -> void:
	for turret in get_tree().get_nodes_in_group("turrets"):
		turret.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
		turret.reset_attack()


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


func _process(delta: float) -> void:
	if phase != Phase.RUNNING:
		return
	autosave_elapsed += delta
	if autosave_elapsed >= 5.0:
		autosave_elapsed = 0.0
		save_progress()
	# M15 integration point: final arrival runs alongside ordinary spawn pressure.
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


func update_final_encounter() -> bool:
	if phase != Phase.RUNNING:
		return false
	if not final_boss_spawned and lantern.elapsed >= final_boss_time:
		final_boss_spawned = true
		# Final arrival adds pressure: existing enemies and water stay until defeated
		# or the run ends. Ordinary spawning continues throughout final combat.
		var boss := FINAL_BOSS_SCRIPT.new()
		boss.target = lantern
		var size := get_arena_rect().size
		boss.position = Vector2(48 if lantern.position.x > size.x / 2.0 else size.x - 48, 64 if lantern.position.y > size.y / 2.0 else size.y - 64)
		boss.defeated.connect(_on_final_boss_defeated)
		add_child(boss)
		$GameHUD.refresh()
	return final_boss_spawned


func update_rainkeeper_encounter() -> void:
	if phase != Phase.RUNNING or rainkeeper_spawned or final_boss_spawned or lantern.elapsed < RAINKEEPER_TIME:
		return
	rainkeeper_spawned = true
	var boss := RAINKEEPER_SCRIPT.new()
	boss.target = lantern
	var size := get_arena_rect().size
	boss.position = Vector2(48 if lantern.position.x > size.x / 2.0 else size.x - 48, 64 if lantern.position.y > size.y / 2.0 else size.y - 64)
	add_child(boss)
	$GameHUD.refresh()


func _on_final_boss_defeated() -> void:
	# First terminal event wins. A dead lantern can never claim a clear.
	if phase == Phase.RUNNING and lantern.health > 0.0 and final_boss_spawned:
		end_run(false, true)


func _spawn_boss() -> void:
	if phase != Phase.RUNNING or boss_spawned or final_boss_spawned:
		return
	boss_spawned = true
	var boss := BOSS_SCRIPT.new()
	boss.target = lantern
	boss.defeated.connect(_on_drencher_defeated)
	# Arrive at the farthest inset corner, giving space and a visible warning.
	var size := get_arena_rect().size
	var corners: Array[Vector2] = [Vector2(44, 44), Vector2(size.x - 44, 44), size - Vector2(44, 44), Vector2(44, size.y - 44)]
	boss.position = corners[0]
	for point in corners:
		if point.distance_squared_to(lantern.position) > boss.position.distance_squared_to(lantern.position):
			boss.position = point
	add_child(boss)
	$GameHUD.refresh()


func _on_drencher_defeated() -> void:
	if phase != Phase.RUNNING or lantern.health <= 0.0 or boss_reward_earned:
		return
	boss_reward_earned = true
	boss_reward_amount = BOSS_ENERGY_REWARD * energy_multiplier()
	boss_reward_notice_until = lantern.elapsed + 5.0
	lantern.energy += boss_reward_amount
	save_progress()
	$GameHUD.refresh()
	get_node("/root/GameAudio").play(&"upgrade")


func _spawn_enemy() -> void:
	if phase != Phase.RUNNING or not ENCOUNTER_SCHEDULE.ordinary_spawns_enabled(lantern.elapsed):
		return
	var enemy := ENEMY_SCENE.instantiate() as Node2D
	enemy.target = lantern
	enemy.max_health = current_enemy_health()
	enemy.speed = current_enemy_speed()
	add_child(enemy)
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
	if phase != Phase.RUNNING or not ENCOUNTER_SCHEDULE.ordinary_spawns_enabled(lantern.elapsed) or get_tree().get_nodes_in_group("chargers").size() >= MAX_CHARGERS:
		return
	var charger := CHARGER_SCENE.instantiate() as Node2D
	charger.target = lantern
	charger.max_health = maxf(3.0, current_enemy_health() + 1.0)
	add_child(charger)
	charger.global_position = _random_edge_position()


func get_arena_rect() -> Rect2:
	var size := get_viewport_rect().size
	return Rect2(Vector2.ZERO, size)


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
	var purchase_costs: Array = []
	var turret_types: Array = []
	var size := get_arena_rect().size
	for turret in get_tree().get_nodes_in_group("turrets"):
		var point: Vector2 = turret.position / size
		positions.append([point.x, point.y])
		purchase_costs.append(turret.purchase_cost)
		turret_types.append(turret.turret_type)
	# Include current earnings without banking them twice in the live game.
	var data := {"version": 1, "energy": banked_energy + lantern.energy, "best_time": best_time, "turrets": positions, "version_bests": version_bests, "legacy_best_time": legacy_best_time, "leaderboard": leaderboard_profile}
	data.turret_costs = purchase_costs
	data.version_clears = version_clears
	data.turret_types = turret_types
	data.upgrades = upgrade_levels()
	data.game_version = str(ProjectSettings.get_setting("application/config/version", "0.0.1"))
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


func reset_progress() -> bool:
	if phase != Phase.PREPARATION:
		return false
	# Replace the save atomically before changing live state. This explicit reset
	# also permits recovery from a previously unreadable save.
	var size := get_arena_rect().size
	var starter := (size * 0.5 + Vector2(80, 0)) / size
	var fresh := {"version": 1, "energy": 0, "best_time": 0, "turrets": [[starter.x, starter.y]]}
	var file := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(fresh))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(save_path + ".tmp", save_path) != OK:
		return false
	call_deferred("_restart_after_reset")
	return true


func _restart_after_reset() -> void:
	# Recreate all run state, including future milestone additions, while keeping
	# the selected save path and audio/display autoload preferences.
	var fresh := (load(scene_file_path) as PackedScene).instantiate()
	fresh.save_path = save_path
	var tree := get_tree()
	var parent := get_parent()
	parent.remove_child(self)
	parent.add_child(fresh)
	tree.current_scene = fresh
	queue_free()


func load_progress() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var contents := FileAccess.get_file_as_string(save_path)
	if contents.strip_edges().is_empty():
		# Same starting state as a missing save; the next save creates valid JSON.
		return
	var parser := JSON.new()
	var error := parser.parse(contents)
	# Progress is scoped to a build version during development. Unstamped saves
	# also start fresh; leaderboard version selection remains independent.
	if error == OK and parser.data is Dictionary and parser.data.get("game_version", "") != str(ProjectSettings.get_setting("application/config/version", "0.0.1")):
		return
	if error != OK or not _valid_save(parser.data):
		save_is_readable = false
		save_message = "Save could not be read; original file preserved. This session will not save."
		return
	var data: Dictionary = parser.data
	banked_energy = float(data.energy)
	var upgrades: Dictionary = data.get("upgrades", {})
	damage_level = int(upgrades.get("damage", 0))
	fire_rate_level = int(upgrades.get("fire_rate", 0))
	health_level = int(upgrades.get("health", 0))
	energy_level = int(upgrades.get("energy", 0))
	proximity_level = int(upgrades.get("proximity", 0))
	for kind in slow_levels:
		slow_levels[kind] = int(upgrades.get(kind, 0))
	# A legacy record's release cannot be inferred; preserve it separately.
	legacy_best_time = float(data.get("legacy_best_time", data.best_time if not data.has("version_bests") else 0.0))
	version_bests = data.get("version_bests", {})
	version_clears = data.get("version_clears", {})
	best_time = float(version_bests.get(game_version, 0.0))
	leaderboard_profile = data.get("leaderboard", {"token": "", "username": "", "pending": {}})
	for turret in get_tree().get_nodes_in_group("turrets"):
		turret.remove_from_group("turrets")
		turret.queue_free()
	for index in range(data.turrets.size()):
		var coordinates: Array = data.turrets[index]
		var kind: String = data.turret_types[index] if data.has("turret_types") else "damage"
		var turret := turret_scene(kind).instantiate() as Node2D
		# Before selling existed, saved order was starter, then purchases at 20, 30…
		var original_cost := 0.0 if index == 0 else 20.0 + 10.0 * (index - 1)
		turret.purchase_cost = float(data.turret_costs[index]) if data.has("turret_costs") else original_cost
		configure_turret(turret)
		add_child(turret)
		turret.position = Vector2(coordinates[0], coordinates[1]) * get_arena_rect().size
	summary = "Welcome back. Your energy and turret layout are ready.\nBest run: %ds" % int(best_time)


func _valid_save(data: Variant) -> bool:
	if not data is Dictionary or data.get("version") != 1:
		return false
	var upgrades = data.get("upgrades", {})
	if not upgrades is Dictionary:
		return false
	for kind in UPGRADE_BASE_COSTS:
		var level = upgrades.get(kind, 0)
		if not (level is int or level is float) or not is_finite(float(level)):
			return false
		if level < 0 or level > MAX_UPGRADE_LEVEL or level != floor(level):
			return false
	var records = data.get("version_bests", {})
	var clears = data.get("version_clears", {})
	if not clears is Dictionary:
		return false
	for clear_time in clears.values():
		if not (clear_time is float or clear_time is int) or not is_finite(float(clear_time)) or clear_time < final_boss_time:
			return false
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
		if pending.has("clearTimeMs"):
			var clear_time = pending.clearTimeMs
			if not (clear_time is int or clear_time is float) or not is_finite(float(clear_time)) or clear_time < final_boss_time * 1000 or clear_time != floor(clear_time) or duration != final_boss_time * 1000:
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
	if data.has("turret_types"):
		var types = data.turret_types
		if not types is Array or types.size() != positions.size() or types[0] != "damage":
			return false
		for kind in types:
			if kind not in ["damage", "pulse", "sniper", "ember"]:
				return false
	if data.has("turret_costs"):
		var costs = data.turret_costs
		if not costs is Array or costs.size() != positions.size():
			return false
		for index in range(costs.size()):
			var cost = costs[index]
			if not (cost is int or cost is float) or not is_finite(float(cost)):
				return false
			# Preserve historical paid prices as well as the new 25-energy ladder.
			if (index == 0 and cost != 0) or (index > 0 and (cost < 20 or cost != floorf(cost))):
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
	if layout.has("upgrades"):
		if not layout.upgrades is Dictionary:
			return false
		for key in ["damage", "fireRate", "health"]:
			var level = layout.upgrades.get(key)
			if not (level is int or level is float) or not is_finite(float(level)) or level < 0 or level != floor(level):
				return false
	for key in ["width", "height"]:
		var size = layout.get(key)
		if not (size is int or size is float) or not is_finite(float(size)) or size <= 0:
			return false
	for point in layout.turrets:
		if not point is Dictionary:
			return false
		if point.has("type") and point.type not in ["damage", "pulse", "sniper", "ember"]:
			return false
		for key in ["x", "y"]:
			var value = point.get(key)
			if not (value is int or value is float) or not is_finite(float(value)) or value < 0 or value > 1:
				return false
	return true
