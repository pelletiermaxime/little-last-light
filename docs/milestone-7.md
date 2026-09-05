# Milestone 7: a versioned online leaderboard

M7 incorporates the leaderboard merged in `5208d02` on top of M6. The `milestone-7` tag preserves the complete game, website, backend, tests, and release workflow. The charging enemy is planned for M8.

## What players get

After death or the pause screen's End Run button, a new personal survival record offers an optional publication with a public username. Nothing is submitted automatically. No thanks keeps the record local; a failed request keeps a retryable offer. The online website shows the top 100 for an exact game version and updates live when new scores arrive.

The game still works offline. Saved energy and turret placements carry between versions, but survival bests belong to the release that produced them. A username is a display name rather than an account; different saves can use the same name.

## Follow a record through the code

1. `Main.end_run(voluntary)` handles both death and End Run. Before resetting earnings, it compares elapsed time against this version's best, updates `version_bests`, and creates a `leaderboard_profile.pending` offer with the version and integer milliseconds. It then banks energy and saves.
2. `GameHUD` refreshes `LeaderboardPanel` in the preparation sidebar. Its username field validates 3–20 ASCII letters, digits, or underscores. BuildController ignores gameplay shortcuts while a LineEdit owns focus, so typing B or R does not buy or refund turrets.
3. Publish persists the profile before making an HTTP request. `sending` copies the exact offered record; the game can continue while the request is in flight. The random 32-byte token identifies this save without an account and must never be treated as a public username.
4. The Convex `/scores` HTTP action validates JSON, version, identity, name, and duration. It hashes the token with SHA-256 and calls an internal mutation. Public queries return only rank, username, duration, and achievement time.
5. The mutation keeps one best row per token hash and version. Repeating the same or a lower score succeeds without inserting duplicates. Improving writes have a five-second per-device cooldown. A failed request can safely be retried.
6. On success, the Godot client clears the pending offer only if it still equals `sending`. A response for an earlier record therefore cannot erase a better result earned meanwhile. Pending offers and the chosen username survive reopening.
7. The Nuxt website subscribes to available versions and the selected version's top scores through Convex. Changing the version changes the active subscription; it does not combine scores across releases.

## Save migration and precision

The outer save format remains version 1 with optional new fields: `version_bests`, `legacy_best_time`, and `leaderboard`. Existing saves remain readable. An old unversioned `best_time` is preserved as a legacy record rather than guessed into the current release. Energy and normalized turret coordinates retain their existing behavior.

Survival is submitted as integer milliseconds, while local elapsed time remains a float in seconds. The backend accepts 1 millisecond through 24 hours. A game's release version is separate from the save format version and from the human milestone tag. The publishing script stamps the actual release number into the exported game, so M7's records use that stamped version.

## Deployment and review fixes

The game demo remains on GitHub Pages. The separate Nuxt leaderboard is already hosted on Cloudflare Pages, with a production Convex backend; see [the deployment guide](../leaderboard/README.md) for the exact URLs and commands. Public GitHub Actions variables provide the game's API and website URLs. They are public addresses, not administrative credentials.

The M7 review found that release and Pages publication depended only on the game build, allowing publication even if the leaderboard job failed. Both now depend on **build and leaderboard**. The website/backend have their own deployment lifecycle; pushing the game does not automatically redeploy Convex or Cloudflare.

The review also added an integration regression covering End Run from a paused session: the game unpauses into preparation, offers the correct versioned record, banks energy once, and restores the record plus pending publication after reopening. All M6 gameplay controls remain covered by their existing tests.

## Verification

- Ten Godot headless check scripts, using isolated temporary saves.
- Seven Python release-version and leaderboard-URL configuration tests.
- Three Convex HTTP/database tests, Nuxt and backend type checking, and a production website build.
- Six Playwright desktop/mobile checks for live updates, version switching, empty releases, and recovery, using mocked WebSockets with the real application/client.
- Read-only checks of the live website, versions endpoint, and score endpoint; production results expose only the intended public fields. No synthetic records are submitted to production.

## Boundaries for future milestones

This is a community leaderboard with client-reported, unverified scores. Progression and turrets carry over between runs, so rankings are not equal-start challenges. Tokens are save-local identities, not accounts or anti-cheat; resetting a save creates a new identity. Stronger abuse prevention, account recovery, and verified competitive runs are future work. Version discovery currently walks distinct published versions; pagination should be considered if that history becomes large.

The single pending slot represents the latest new best offer and can be replaced by a newer personal best. These are intentional constraints of this first leaderboard milestone. The next gameplay milestone adds the charging enemy rather than expanding the leaderboard.

## Historical code snapshots

These snapshots preserve the key implementation for learning after later milestones change the files. For any other file, use `git show milestone-7:path/to/file`.

<details>
<summary>leaderboard_panel.gd — complete M7 snapshot</summary>

```gdscript
extends VBoxContainer

var main: Node2D
var prompt: Label
var username: LineEdit
var publish: Button
var skip: Button
var notice: Label
var request: HTTPRequest
var sending: Dictionary = {}
var api_url: String
var displayed_pending: Dictionary = {}


func _ready() -> void:
	api_url = str(ProjectSettings.get_setting("leaderboard/api_url", "")).trim_suffix("/")
	add_theme_constant_override("separation", 8)
	prompt = Label.new()
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(prompt)
	username = LineEdit.new()
	username.placeholder_text = "Username (3–20 letters, numbers, _)"
	username.max_length = 20
	username.accessibility_name = "Leaderboard username"
	add_child(username)
	publish = Button.new()
	publish.text = "Publish my record"
	publish.pressed.connect(_publish)
	add_child(publish)
	skip = Button.new()
	skip.text = "No thanks"
	skip.pressed.connect(_skip)
	add_child(skip)
	notice = Label.new()
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(notice)
	var site_url := str(ProjectSettings.get_setting("leaderboard/site_url", ""))
	if not site_url.is_empty():
		var view := LinkButton.new()
		view.text = "View online leaderboard ↗"
		view.pressed.connect(func(): OS.shell_open(site_url + "?version=" + main.game_version.uri_encode()))
		add_child(view)
	request = HTTPRequest.new()
	request.timeout = 15.0
	request.body_size_limit = 8192
	request.request_completed.connect(_completed)
	add_child(request)
	call_deferred("_restore_username")
	refresh()


func _restore_username() -> void:
	username.text = main.leaderboard_profile.username


func refresh() -> void:
	visible = main.phase == main.Phase.PREPARATION
	var pending: Dictionary = main.leaderboard_profile.pending
	if pending != displayed_pending:
		displayed_pending = pending.duplicate()
		if not pending.is_empty() and sending.is_empty():
			notice.text = ""
	var offered := not pending.is_empty()
	prompt.visible = offered
	username.visible = offered
	publish.visible = offered
	skip.visible = offered
	if offered:
		prompt.text = "New personal best · v%s\nPublish %.3f seconds with a public username?" % [pending.version, float(pending.durationMs) / 1000.0]
	publish.disabled = not sending.is_empty() or api_url.is_empty()
	skip.disabled = not sending.is_empty()
	username.editable = sending.is_empty()
	if api_url.is_empty() and offered:
		notice.text = "Online publishing is not configured in this build. Your record is saved locally."


func _skip() -> void:
	if not sending.is_empty():
		return
	main.leaderboard_profile.pending = {}
	main.save_progress()
	notice.text = "Record kept on this device."
	refresh()


func _publish() -> void:
	if not sending.is_empty() or api_url.is_empty() or main.leaderboard_profile.pending.is_empty():
		return
	var name_text := username.text.strip_edges()
	var pattern := RegEx.new()
	pattern.compile("^[A-Za-z0-9_]{3,20}$")
	if pattern.search(name_text) == null:
		notice.text = "Use 3–20 letters, numbers, or underscores."
		return
	main.leaderboard_profile.username = name_text
	# Persist the anonymous identity before sending so retries cannot create duplicates.
	if not main.save_progress():
		notice.text = "Save your progress successfully before publishing."
		return
	sending = main.leaderboard_profile.pending.duplicate()
	var payload := sending.duplicate()
	payload.username = name_text
	payload.token = main.leaderboard_profile.token
	notice.text = "Publishing…"
	var error := request.request(api_url + "/scores", ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(payload))
	if error != OK:
		sending = {}
		notice.text = "Could not connect. Your record is saved; try publishing again."
	refresh()


func _completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var parser := JSON.new()
	var response: Variant = null
	if not body.is_empty() and parser.parse(body.get_string_from_utf8()) == OK:
		response = parser.data
	if result == HTTPRequest.RESULT_SUCCESS and code == 200 and response is Dictionary and response.get("ok") == true:
		# A newer personal best may have been earned while this request was in flight.
		if main.leaderboard_profile.pending == sending:
			main.leaderboard_profile.pending = {}
		main.save_progress()
		notice.text = "Published! Your record is on the v%s leaderboard." % sending.version
	else:
		notice.text = "Publishing failed. Your record is saved; try again."
		if response is Dictionary and response.get("error") is String:
			notice.text = str(response.error).left(180) + " Your record is saved."
	sending = {}
	refresh()
```

</details>

<details>
<summary>main.gd — complete M7 snapshot</summary>

```gdscript
extends Node2D

enum Phase { PREPARATION, RUNNING }

const SIDEBAR_WIDTH: float = 320.0

const ENEMY_SCENE: PackedScene = preload("res://enemy.tscn")
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
var autosave_elapsed: float = 0.0
var summary: String = "Arrange your defense, then start your first run."
var save_message: String = ""
var previous_viewport_size: Vector2
var save_is_readable: bool = true
var last_run: Dictionary = {}
var game_version: String = str(ProjectSettings.get_setting("application/config/version", "0.0.1"))
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
	if last_run.new_best:
		leaderboard_profile.pending = {"version": game_version, "durationMs": maxi(1, int(lantern.elapsed * 1000.0))}
	var result := "Run ended" if voluntary else "The light went out"
	summary = "%s · %ds survived · +%d energy\nImprove your layout and try again. Best: %ds" % [result, int(lantern.elapsed), int(lantern.energy), int(best_time)]
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
	# Basic pursuers never gain speed with time. Open space is a reliable escape.
	return BASE_ENEMY_SPEED


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
<summary>leaderboard/convex/http.ts — complete M7 snapshot</summary>

```typescript
import { httpRouter } from 'convex/server'
import { httpAction } from './_generated/server'
import { api, internal } from './_generated/api'
import { validVersion, validateScore } from './validation'

const http = httpRouter()
const headers = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Content-Type': 'application/json',
}
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers })

http.route({ path: '/versions', method: 'GET', handler: httpAction(async ctx => {
  return json(await ctx.runQuery(api.scores.versions, {}))
}) })
http.route({ path: '/scores', method: 'GET', handler: httpAction(async (ctx, request) => {
  const version = new URL(request.url).searchParams.get('version') ?? ''
  if (!validVersion(version)) return json({ error: 'Invalid game version.' }, 400)
  return json(await ctx.runQuery(api.scores.list, { version }))
}) })
http.route({ path: '/scores', method: 'OPTIONS', handler: httpAction(async () => new Response(null, { status: 204, headers })) })
http.route({ path: '/scores', method: 'POST', handler: httpAction(async (ctx, request) => {
  if (!request.headers.get('content-type')?.startsWith('application/json')) return json({ error: 'Expected JSON.' }, 415)
  const body = await request.text()
  if (body.length > 2048) return json({ error: 'Request is too large.' }, 413)
  let score: ReturnType<typeof validateScore>
  try { score = validateScore(JSON.parse(body)) }
  catch (error) { return json({ error: error instanceof Error ? error.message : 'Invalid score.' }, 400) }
  const { token, ...publicScore } = score
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(token))
  const playerHash = Array.from(new Uint8Array(digest), b => b.toString(16).padStart(2, '0')).join('')
  const result = await ctx.runMutation(internal.scores.submit, { ...publicScore, playerHash })
  return json(result, result.ok ? 200 : 409)
}) })
export default http
```

</details>

<details>
<summary>leaderboard/convex/scores.ts — complete M7 snapshot</summary>

```typescript
import { v } from 'convex/values'
import { internalMutation, query } from './_generated/server'
import { validVersion } from './validation'

export const versions = query({
  args: {},
  handler: async ctx => {
    const versions: string[] = []
    let after = ''
    // Jump past each version's scores rather than scanning every player's row.
    while (true) {
      const row = await ctx.db.query('scores').withIndex('by_version_score', q => q.gt('version', after)).first()
      if (!row) break
      versions.push(row.version)
      after = row.version
    }
    return versions.sort((a, b) => b.localeCompare(a, undefined, { numeric: true }))
  },
})

export const list = query({
  args: { version: v.string() },
  handler: async (ctx, { version }) => {
    if (!validVersion(version)) throw new Error('Invalid game version.')
    const rows = await ctx.db.query('scores').withIndex('by_version_score', q => q.eq('version', version)).order('desc').take(100)
    return rows.map((row, index) => ({ rank: index + 1, username: row.username, durationMs: row.durationMs, achievedAt: row.achievedAt }))
  },
})

export const submit = internalMutation({
  args: { version: v.string(), playerHash: v.string(), username: v.string(), durationMs: v.number() },
  handler: async (ctx, args) => {
    const previous = await ctx.db.query('scores').withIndex('by_player_version', q => q.eq('playerHash', args.playerHash).eq('version', args.version)).unique()
    if (previous && previous.durationMs >= args.durationMs) return { ok: true }
    const latest = await ctx.db.query('scores').withIndex('by_player_time', q => q.eq('playerHash', args.playerHash)).order('desc').first()
    if (latest && Date.now() - latest.achievedAt < 5000) return { ok: false, error: 'Please wait a few seconds before publishing again.' }
    const score = { ...args, achievedAt: Date.now() }
    if (previous) await ctx.db.patch(previous._id, score)
    else await ctx.db.insert('scores', score)
    return { ok: true }
  },
})
```

</details>

<details>
<summary>tests/check_leaderboard.gd — complete M7 snapshot</summary>

```gdscript
extends SceneTree

var failures := 0
var path := "/tmp/little-last-light-leaderboard-%d.json" % OS.get_process_id()


func _initialize() -> void:
	call_deferred("check")


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func game(version: String) -> Node2D:
	var scene = load("res://main.tscn").instantiate()
	scene.save_path = path
	scene.game_version = version
	root.add_child(scene)
	# Keep offline-state assertions independent of this worktree's configured API.
	scene.get_node("GameHUD").leaderboard.api_url = ""
	scene.get_node("GameHUD").leaderboard.refresh()
	scene.set_process(false)
	scene.lantern.set_process(false)
	scene.lantern.set_physics_process(false)
	return scene


func finish(scene: Node2D, seconds: float) -> void:
	scene.start_run()
	scene.lantern.elapsed = seconds
	scene.lantern.take_damage(1000)
	scene.get_node("GameHUD").refresh()


func check() -> void:
	var scene := game("0.1.0")
	var panel = scene.get_node("GameHUD").leaderboard
	expect(scene.leaderboard_profile.token.length() == 64, "Creates anonymous identity")
	expect(not panel.publish.visible, "No publish offer before completed personal best")
	finish(scene, 65.125)
	expect(panel.publish.visible and scene.leaderboard_profile.pending.durationMs == 65125, "New best offers precise score")
	expect(panel.publish.disabled, "Unconfigured build stays local")
	var token: String = scene.leaderboard_profile.token
	scene.leaderboard_profile.username = "Keeper"
	scene.save_progress()
	scene.free()
	await process_frame
	scene = game("0.1.0")
	await process_frame
	panel = scene.get_node("GameHUD").leaderboard
	expect(scene.best_time == 65.125 and scene.leaderboard_profile.token == token, "Best and identity survive restart")
	expect(panel.username.text == "Keeper" and panel.publish.visible, "Name and pending offer survive restart")
	panel.username.grab_focus()
	var event := InputEventKey.new()
	event.keycode = KEY_B
	event.physical_keycode = KEY_B
	event.pressed = true
	scene.banked_energy = 100
	scene.get_node("BuildController")._unhandled_input(event)
	expect(not scene.get_node("BuildController").placing, "Username typing cannot buy a turret")
	panel.username.release_focus()
	panel._skip()
	finish(scene, 65.125)
	expect(not panel.publish.visible, "Tied record does not prompt")
	finish(scene, 10)
	expect(not panel.publish.visible, "Lower record does not prompt")
	finish(scene, 70)
	panel.api_url = "https://example.convex.site"
	panel.sending = scene.leaderboard_profile.pending.duplicate()
	panel._completed(HTTPRequest.RESULT_CANT_CONNECT, 0, [], PackedByteArray())
	expect(not scene.leaderboard_profile.pending.is_empty() and panel.notice.text.contains("failed"), "Network failure retains pending record")
	panel.sending = scene.leaderboard_profile.pending.duplicate()
	finish(scene, 80)
	panel._completed(HTTPRequest.RESULT_SUCCESS, 200, [], '{"ok":true}'.to_utf8_buffer())
	expect(scene.leaderboard_profile.pending.durationMs == 80000, "Older response cannot clear newer record")
	panel.sending = scene.leaderboard_profile.pending.duplicate()
	panel._completed(HTTPRequest.RESULT_SUCCESS, 200, [], '{"ok":true}'.to_utf8_buffer())
	expect(scene.leaderboard_profile.pending.is_empty(), "Successful publish clears matching pending score")
	scene.free()
	await process_frame
	scene = game("0.2.0")
	expect(scene.best_time == 0 and scene.banked_energy == 100, "New version resets best but keeps economy")
	finish(scene, 5)
	expect(scene.last_run.new_best and scene.version_bests["0.1.0"] == 80, "New release record keeps older version history")
	# M6's voluntary End Run must use the same record and saving path as death.
	scene.start_run()
	scene.lantern.elapsed = 12.345
	scene.lantern.energy = 7.0
	var pause_screen = scene.get_node("PauseScreen")
	pause_screen.pause()
	pause_screen.end_run_button.pressed.emit()
	expect(not paused and scene.phase == scene.Phase.PREPARATION, "Ending a paused run returns to interactive preparation")
	expect(scene.last_run.voluntary and scene.best_time == 12.345, "End Run records the voluntary personal best")
	expect(scene.leaderboard_profile.pending == {"version": "0.2.0", "durationMs": 12345}, "End Run offers its record for the correct version")
	expect(scene.get_node("GameHUD").leaderboard.publish.visible, "End Run immediately displays the opt-in offer")
	expect(scene.banked_energy == 107.0, "End Run banks energy alongside the leaderboard record")
	scene.free()
	await process_frame
	scene = game("0.2.0")
	expect(scene.best_time == 12.345 and scene.leaderboard_profile.pending.durationMs == 12345, "Voluntary record and pending publication survive reopening")
	expect(scene.banked_energy == 107.0, "Leaderboard persistence preserves End Run earnings")
	scene.free()
	await process_frame
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string('{"version":1,"energy":42,"best_time":99,"turrets":[[0.5,0.5]]}')
	file.close()
	scene = game("0.3.0")
	expect(scene.best_time == 0 and scene.legacy_best_time == 99 and scene.banked_energy == 42, "Legacy save migrates without attributing unknown version")
	scene.save_progress()
	scene.free()
	await process_frame
	scene = game("0.3.0")
	expect(scene.legacy_best_time == 99, "Legacy record preserved after migration")
	scene.free()
	DirAccess.remove_absolute(path)
	if failures == 0:
		print("PASS: version isolation, save migration, opt-in, identity, input focus, retries, stale response protection, paused End Run and reopening")
	quit(1 if failures else 0)
```

</details>
