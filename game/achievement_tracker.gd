extends Node

signal unlocked(id: String)
signal changed

const CATALOG := [
	{"id": "first_tower", "name": "Growing the Light", "description": "Buy your first tower."},
	{"id": "defeat_drencher", "name": "Out of the Water", "description": "Defeat the Drencher."},
	{"id": "defeat_rainkeeper", "name": "After the Rain", "description": "Defeat the Rainkeeper."},
	{"id": "defeat_snuffer", "name": "Last Light Standing", "description": "Defeat the Snuffer."},
]

const IDS := ["first_tower", "defeat_drencher", "defeat_rainkeeper", "defeat_snuffer"]
const STORE = preload("res://game/progress_store.gd")
var game: Node2D
var path: String
var data: Dictionary = {}
var readable := true
var api_url := ""
var request: HTTPRequest
var sending := false
var synced := false
var sent: Array = []
var retry_in := 0.0
var sync_message := "Saved on this device."


func setup(owner_game: Node2D, editor_build: bool = OS.has_feature("editor")) -> void:
	game = owner_game
	path = game.save_path + (".achievements-editor.json" if editor_build else ".achievements-export.json")
	data = {"token": game.leaderboard_profile.token, "unlocked": [], "started": false}
	var read_path := path
	# The unqualified file was used only during pre-release editor testing.
	# Adopt it for editor play, never as production achievement history.
	var legacy_path: String = game.save_path + ".achievements.json"
	if editor_build and not FileAccess.file_exists(path) and FileAccess.file_exists(legacy_path):
		read_path = legacy_path
	if FileAccess.file_exists(read_path):
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(read_path))
		if not _valid(saved):
			readable = false
			return # Preserve an unreadable identity instead of registering a new player.
		data = saved
	elif FileAccess.file_exists(game.save_path):
		# Adopt the score identity even when this release resets gameplay progress.
		var old: Variant = JSON.parse_string(FileAccess.get_file_as_string(game.save_path))
		if old is Dictionary and old.get("leaderboard") is Dictionary:
			var token: Variant = old.leaderboard.get("token")
			if _valid_token(token):
				data.token = token
	game.leaderboard_profile.token = data.token
	# Automated headless checks remain offline; editor play uses the dev deployment.
	if DisplayServer.get_name() != "headless":
		api_url = preload("res://game/online_config.gd").api_url()
	request = HTTPRequest.new()
	request.timeout = 10.0
	add_child(request)
	request.request_completed.connect(_completed)
	_persist()


func _valid_token(value: Variant) -> bool:
	if not value is String:
		return false
	var pattern := RegEx.new()
	pattern.compile("^[a-f0-9]{64}$")
	return pattern.search(value) != null


func _valid(value: Variant) -> bool:
	if not value is Dictionary or not _valid_token(value.get("token")):
		return false
	if not value.get("unlocked") is Array or not value.get("started") is bool:
		return false
	for id in value.unlocked:
		if id not in IDS:
			return false
	return true


func _persist() -> bool:
	return readable and STORE.write_atomic(path, data)


func enroll() -> void:
	if not readable or not game.leaderboard_eligible():
		return
	data.started = true
	_persist()
	flush()


func unlock(id: String) -> void:
	if not readable or id not in IDS or not game.leaderboard_eligible() or id in data.unlocked:
		return
	data.unlocked.append(id)
	data.started = true
	synced = false
	_persist()
	unlocked.emit(id)
	changed.emit()
	flush()


func _process(delta: float) -> void:
	retry_in = maxf(0.0, retry_in - delta)
	flush()


func flush() -> void:
	if not readable or synced or sending or retry_in > 0.0 or api_url.is_empty() or not data.started:
		return
	retry_in = 30.0
	# The token and complete unlock set must survive a crash before reporting.
	if not _persist():
		sync_message = "Could not save achievements. Sync will retry."
		changed.emit()
		return
	sent = data.unlocked.duplicate()
	var payload := {"token": data.token, "unlocked": sent}
	sending = true
	sync_message = "Syncing achievements…"
	changed.emit()
	if request.request(api_url + "/achievements", ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(payload)) != OK:
		sending = false
		sync_message = "Saved locally. Connection failed; retrying shortly."
		changed.emit()


func _completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	sending = false
	sync_message = "Saved locally. Sync failed; retrying shortly."
	changed.emit()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var parser := JSON.new()
	if parser.parse(body.get_string_from_utf8()) != OK:
		return
	var response: Variant = parser.data
	if response is Dictionary and response.get("ok") == true:
		synced = sent == data.unlocked
		retry_in = 0.0
		sync_message = "Achievements synced." if synced else "New achievements waiting to sync."
		changed.emit()


func status_text() -> String:
	if not readable:
		return "Achievement save could not be read; original file preserved."
	if api_url.is_empty():
		return "Saved on this device. Online achievements are not configured."
	if not data.started:
		return "Start an unassisted run to join community achievement tracking."
	return sync_message


func retry_sync() -> void:
	synced = false
	retry_in = 0.0
	flush()
