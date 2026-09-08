extends Node2D

enum Phase { PREPARATION, RUNNING, RESULTS }

const PROGRESS_STORE = preload("res://game/progress_store.gd")
const ENCOUNTER_DIRECTOR = preload("res://game/encounter_director.gd")

const BOSS_ENERGY_REWARD: float = 300.0
const TURRET_SCENE: PackedScene = preload("res://turrets/turret.tscn")
const PULSE_TURRET_SCENE: PackedScene = preload("res://turrets/pulse_turret.tscn")
const SNIPER_TURRET_SCENE: PackedScene = preload("res://turrets/sniper_turret.tscn")
const EMBER_TURRET_SCENE: PackedScene = preload("res://turrets/ember_turret.tscn")
const MAX_UPGRADE_LEVEL: int = 5
const UPGRADE_BASE_COSTS: Dictionary = {"damage": 120.0, "fire_rate": 100.0, "health": 80.0, "slow_rate": 120.0, "slow_strength": 160.0, "slow_duration": 100.0, "energy": 100.0, "proximity": 150.0}

# A zero FPS limit means unlimited.
@export_range(0, 360, 1, "or_greater") var fps_limit: int = 100:
	set(value):
		fps_limit = maxi(value, 0)
		Engine.max_fps = fps_limit

@export var save_path: String = "user://progress-v1.json"
@onready var lantern: Node2D = $Lantern

var encounters := ENCOUNTER_DIRECTOR.new()
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
var version_clears: Dictionary = {}
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
var assists: Dictionary = {"cheap_upgrades": false, "short_night": false, "slow_enemies": false, "reduced_damage": false}
const DAMAGE_FACTORS := [1.0, 0.75, 0.5, 0.0]
var damage_taken_factor := 1.0
# Energy and upgrades carry between runs, so eligibility belongs to the save.
var assisted_progress := false
var run_assisted := false


func set_assist(kind: String, enabled: bool) -> bool:
	if phase != Phase.PREPARATION or not assists.has(kind):
		return false
	assists[kind] = enabled
	if enabled:
		assisted_progress = true
		leaderboard_profile.pending = {}
	save_progress()
	$BuildController._update_interface()
	return true


func night_scale() -> float:
	return 0.5 if assists.short_night else 1.0


func set_damage_taken(value: float) -> bool:
	if phase != Phase.PREPARATION or value not in DAMAGE_FACTORS:
		return false
	damage_taken_factor = value
	return set_assist("reduced_damage", value != 1.0)


func encounter_time() -> float:
	# Child HUD readiness precedes Main's @onready bindings.
	return $Lantern.elapsed / night_scale()


func night_duration() -> float:
	return encounters.final_boss_time * night_scale()


func enemy_movement_multiplier() -> float:
	return 0.5 if assists.slow_enemies else 1.0


func leaderboard_eligible() -> bool:
	return not assisted_progress and not assists.values().has(true)


func _ready() -> void:
	encounters.game = self
	add_child(encounters)
	Engine.max_fps = fps_limit
	previous_viewport_size = get_arena_rect().size
	$Turret.position = lantern.position + Vector2(80.0, 0.0)
	lantern.died.connect(_on_lantern_died)
	pickups = preload("res://game/run_pickups.gd").new()
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
	elif turret.turret_type == "ember":
		turret.fire_interval *= 2.0


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
	return UPGRADE_BASE_COSTS[kind] * pow(2.0, upgrade_levels()[kind]) * (0.5 if assists.cheap_upgrades else 1.0)


func defense_investment() -> float:
	var invested: float = $BuildController.layout_refund()
	# Upgrade prices double; their cumulative cost is next price minus base price.
	for kind in UPGRADE_BASE_COSTS:
		invested += UPGRADE_BASE_COSTS[kind] * (pow(2.0, upgrade_levels()[kind]) - 1.0)
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
	run_assisted = not leaderboard_eligible()
	assisted_progress = assisted_progress or run_assisted
	lantern.health = lantern.max_health
	lantern.energy = 0.0
	lantern.elapsed = 0.0
	lantern.brightness = 0
	lantern.hit_flash = 0.0
	lantern.projectile_grace_remaining = 0.0
	lantern._center_in_viewport()
	encounters.reset()
	boss_reward_earned = false
	boss_reward_amount = 0.0
	boss_reward_notice_until = 0.0
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
	var survival := minf(lantern.elapsed, night_duration())
	var previous_clear := float(version_clears.get(game_version, 0.0))
	var eligible := leaderboard_eligible() and not run_assisted
	var new_clear: bool = eligible and victory and (previous_clear == 0.0 or lantern.elapsed < previous_clear)
	last_run = {"duration": lantern.elapsed, "survival": survival, "victory": victory, "energy": lantern.energy, "new_best": new_clear if victory else survival > best_time, "voluntary": voluntary}
	last_run.boss_bonus = boss_reward_amount
	last_run.assisted = not eligible
	last_run.new_best = eligible and last_run.new_best
	if eligible:
		best_time = maxf(best_time, survival)
	if new_clear:
		version_clears[game_version] = lantern.elapsed
	version_bests[game_version] = best_time
	if eligible and (new_clear or (last_run.new_best and previous_clear == 0.0)):
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


func _process(delta: float) -> void:
	if phase != Phase.RUNNING:
		return
	autosave_elapsed += delta
	if autosave_elapsed >= 5.0:
		autosave_elapsed = 0.0
		save_progress()
	encounters.update(delta)


func _on_final_boss_defeated() -> void:
	# First terminal event wins. A dead lantern can never claim a clear.
	if phase == Phase.RUNNING and lantern.health > 0.0 and encounters.final_boss_spawned:
		end_run(false, true)


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


func get_arena_rect() -> Rect2:
	var size := get_viewport_rect().size
	return Rect2(Vector2.ZERO, size)


func _resize_layout() -> void:
	var size := get_arena_rect().size
	if previous_viewport_size.x > 0.0 and previous_viewport_size.y > 0.0:
		for turret in get_tree().get_nodes_in_group("turrets"):
			turret.position = (turret.position / previous_viewport_size * size).clamp(Vector2(20, 20), (size - Vector2(20, 20)).max(Vector2(20, 20)))
	previous_viewport_size = size
	queue_redraw()


func save_progress() -> bool:
	return PROGRESS_STORE.save_progress(self)


func reset_progress() -> bool:
	return PROGRESS_STORE.reset_progress(self)


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
	PROGRESS_STORE.load_progress(self)


func _valid_save(data: Variant) -> bool:
	return PROGRESS_STORE.is_valid(data, self)
