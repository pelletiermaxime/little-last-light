extends RefCounted


static func save_progress(game: Node2D) -> bool:
	if not game.save_is_readable:
		# An intentionally emptied file is a fresh profile, not corrupt data to protect.
		if not FileAccess.file_exists(game.save_path) or FileAccess.get_file_as_string(game.save_path).strip_edges().is_empty():
			game.save_is_readable = true
		else:
			return false
	var positions: Array = []
	var purchase_costs: Array = []
	var turret_types: Array = []
	var size: Vector2 = game.get_arena_rect().size
	for turret in game.get_tree().get_nodes_in_group("turrets"):
		var point: Vector2 = turret.position / size
		positions.append([point.x, point.y])
		purchase_costs.append(turret.purchase_cost)
		turret_types.append(turret.turret_type)
	# Include current earnings without banking them twice in the live game.
	var data := {"version": 1, "energy": game.banked_energy + game.lantern.energy, "best_time": game.best_time, "turrets": positions, "version_bests": game.version_bests, "legacy_best_time": game.legacy_best_time, "leaderboard": game.leaderboard_profile}
	data.turret_costs = purchase_costs
	data.version_clears = game.version_clears
	data.turret_types = turret_types
	data.upgrades = game.upgrade_levels()
	data.game_version = str(ProjectSettings.get_setting("application/config/version", "0.0.1"))
	if not write_atomic(game.save_path, data):
		game.save_message = "Could not save progress. Keep this window open and retry."
		return false
	game.save_message = ""
	return true


static func reset_progress(game: Node2D) -> bool:
	if game.phase != game.Phase.PREPARATION:
		return false
	# Replace the save atomically before changing live state. This explicit reset
	# also permits recovery from a previously unreadable save.
	var size: Vector2 = game.get_arena_rect().size
	var starter := (size * 0.5 + Vector2(80, 0)) / size
	var fresh := {"version": 1, "energy": 0, "best_time": 0, "turrets": [[starter.x, starter.y]]}
	if not write_atomic(game.save_path, fresh):
		return false
	game.call_deferred("_restart_after_reset")
	return true


static func load_progress(game: Node2D) -> void:
	if not FileAccess.file_exists(game.save_path):
		return
	var contents := FileAccess.get_file_as_string(game.save_path)
	if contents.strip_edges().is_empty():
		# Same starting state as a missing save; the next save creates valid JSON.
		return
	var parser := JSON.new()
	var error := parser.parse(contents)
	# Progress is scoped to a build version during development. Unstamped saves
	# also start fresh; leaderboard version selection remains independent.
	if error == OK and parser.data is Dictionary and parser.data.get("game_version", "") != str(ProjectSettings.get_setting("application/config/version", "0.0.1")):
		return
	if error != OK or not is_valid(parser.data, game):
		game.save_is_readable = false
		game.save_message = "Save could not be read; original file preserved. This session will not save."
		return
	var data: Dictionary = parser.data
	game.banked_energy = float(data.energy)
	var upgrades: Dictionary = data.get("upgrades", {})
	game.damage_level = int(upgrades.get("damage", 0))
	game.fire_rate_level = int(upgrades.get("fire_rate", 0))
	game.health_level = int(upgrades.get("health", 0))
	game.energy_level = int(upgrades.get("energy", 0))
	game.proximity_level = int(upgrades.get("proximity", 0))
	for kind in game.slow_levels:
		game.slow_levels[kind] = int(upgrades.get(kind, 0))
	# A legacy record's release cannot be inferred; preserve it separately.
	game.legacy_best_time = float(data.get("legacy_best_time", data.best_time if not data.has("version_bests") else 0.0))
	game.version_bests = data.get("version_bests", {})
	game.version_clears = data.get("version_clears", {})
	game.best_time = float(game.version_bests.get(game.game_version, 0.0))
	game.leaderboard_profile = data.get("leaderboard", {"token": "", "username": "", "pending": {}})
	for turret in game.get_tree().get_nodes_in_group("turrets"):
		turret.remove_from_group("turrets")
		turret.queue_free()
	for index in range(data.turrets.size()):
		var coordinates: Array = data.turrets[index]
		var kind: String = data.turret_types[index] if data.has("turret_types") else "damage"
		var turret := game.turret_scene(kind).instantiate() as Node2D
		# Before selling existed, saved order was starter, then purchases at 20, 30…
		var original_cost := 0.0 if index == 0 else 20.0 + 10.0 * (index - 1)
		turret.purchase_cost = float(data.turret_costs[index]) if data.has("turret_costs") else original_cost
		game.configure_turret(turret)
		game.add_child(turret)
		turret.position = Vector2(coordinates[0], coordinates[1]) * game.get_arena_rect().size
	game.summary = "Welcome back. Your energy and turret layout are ready.\nBest run: %ds" % int(game.best_time)


static func is_valid(data: Variant, game: Node2D) -> bool:
	if not data is Dictionary or data.get("version") != 1:
		return false
	var upgrades = data.get("upgrades", {})
	if not upgrades is Dictionary:
		return false
	for kind in game.UPGRADE_BASE_COSTS:
		var level = upgrades.get(kind, 0)
		if not _is_finite_number(level):
			return false
		if level < 0 or level > game.MAX_UPGRADE_LEVEL or level != floor(level):
			return false
	var records = data.get("version_bests", {})
	var clears = data.get("version_clears", {})
	if not clears is Dictionary:
		return false
	for clear_time in clears.values():
		if not _is_finite_number(clear_time) or clear_time < game.encounters.final_boss_time:
			return false
	if not records is Dictionary:
		return false
	for record in records.values():
		if not _is_finite_number(record) or record < 0:
			return false
	var legacy = data.get("legacy_best_time", 0.0)
	if not _is_finite_number(legacy) or legacy < 0:
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
			if not _is_finite_number(clear_time) or clear_time < game.encounters.final_boss_time * 1000 or clear_time != floor(clear_time) or duration != game.encounters.final_boss_time * 1000:
				return false
		for key in ["energyEarned", "energyInvested", "totalEnergy"]:
			if pending.has(key):
				var value = pending[key]
				if not _is_finite_number(value) or value < 0:
					return false
		if pending.has("turretLayout") and not valid_run_layout(pending.turretLayout):
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
			if not _is_finite_number(cost):
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


static func valid_run_layout(layout: Variant) -> bool:
	if not layout is Dictionary or not layout.get("turrets") is Array:
		return false
	if layout.has("upgrades"):
		if not layout.upgrades is Dictionary:
			return false
		for key in ["damage", "fireRate", "health"]:
			var level = layout.upgrades.get(key)
			if not _is_finite_number(level) or level < 0 or level != floor(level):
				return false
	for key in ["width", "height"]:
		var size = layout.get(key)
		if not _is_finite_number(size) or size <= 0:
			return false
	for point in layout.turrets:
		if not point is Dictionary:
			return false
		if point.has("type") and point.type not in ["damage", "pulse", "sniper", "ember"]:
			return false
		for key in ["x", "y"]:
			var value = point.get(key)
			if not _is_finite_number(value) or value < 0 or value > 1:
				return false
	return true


static func write_atomic(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var error := file.get_error()
	file.close()
	return error == OK and DirAccess.rename_absolute(path + ".tmp", path) == OK


static func _is_finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
