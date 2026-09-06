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
		view.text = "View online leaderboard"
		view.pressed.connect(func(): OS.shell_open(site_url if main.game_version == "dev" else site_url + "?version=" + main.game_version.uri_encode()))
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
	var development: bool = main.game_version == "dev"
	var offered := not pending.is_empty() and not development
	prompt.visible = offered
	username.visible = offered
	publish.visible = offered
	skip.visible = offered
	if offered:
		prompt.text = "New personal best · v%s\nPublish %.3f seconds with a public username?" % [pending.version, float(pending.durationMs) / 1000.0]
		if pending.has("energyInvested"):
			prompt.text += "\nDefense investment: %d energy." % int(pending.energyInvested)
		if pending.has("energyEarned"):
			prompt.text += "\nEnergy earned this run: %d." % int(pending.energyEarned)
		if pending.has("turretLayout"):
			prompt.text += "\nYour %d-turret layout will be public." % pending.turretLayout.turrets.size()
	publish.disabled = not sending.is_empty() or api_url.is_empty()
	skip.disabled = not sending.is_empty()
	username.editable = sending.is_empty()
	if api_url.is_empty() and offered:
		notice.text = "Online publishing is not configured in this build. Your record is saved locally."
	if development:
		notice.text = "Development build · records stay local."


func _skip() -> void:
	if not sending.is_empty():
		return
	main.leaderboard_profile.pending = {}
	main.save_progress()
	notice.text = "Record kept on this device."
	refresh()


func _publish() -> void:
	if main.game_version == "dev" or not sending.is_empty() or api_url.is_empty() or main.leaderboard_profile.pending.is_empty():
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
	sending = main.leaderboard_profile.pending.duplicate(true)
	var payload := sending.duplicate(true)
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
