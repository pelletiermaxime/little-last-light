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
var scores_request: HTTPRequest
var scores_heading: Label
var scores_notice: Label
var scores_rows: VBoxContainer
var scores_page: VBoxContainer
var refresh_scores: Button
var all_versions: LinkButton
var scores_loading := false
var was_visible := false
const PAGE_SIZE := 3
var score_data: Array = []
var page_index := 0
var displayed_section_pending: Dictionary = {}
var submission: VBoxContainer
var rankings: VBoxContainer
var submission_button: Button
var rankings_button: Button
var previous_page: Button
var next_page: Button
var page_label: Label
var pager: HBoxContainer


func _ready() -> void:
	if main == null:
		main = get_tree().current_scene as Node2D
	api_url = str(ProjectSettings.get_setting("leaderboard/api_url", "")).trim_suffix("/")
	prompt = $Submission/Prompt
	username = $Submission/Username
	publish = $Submission/PublishButton
	skip = $Submission/SkipButton
	notice = $Notice
	submission = $Submission
	rankings = $Rankings
	rankings_button = $Tabs/RankingsButton
	submission_button = $Tabs/SubmissionButton
	scores_heading = $Rankings/Heading
	scores_notice = $Rankings/Notice
	scores_page = $Rankings/ScoresPage
	scores_rows = $Rankings/ScoresPage/Rows
	pager = $Rankings/Pager
	previous_page = $Rankings/Pager/PreviousButton
	next_page = $Rankings/Pager/NextButton
	page_label = $Rankings/Pager/PageLabel
	refresh_scores = $Rankings/RefreshButton
	all_versions = $Rankings/AllVersions
	scores_request = $ScoresRequest
	request = $PublishRequest
	publish.pressed.connect(_publish)
	skip.pressed.connect(_skip)
	refresh_scores.pressed.connect(_load_scores)
	rankings_button.pressed.connect(func(): show_submission(false))
	submission_button.pressed.connect(func(): show_submission(true))
	previous_page.pressed.connect(func(): _change_page(-1))
	next_page.pressed.connect(func(): _change_page(1))
	scores_request.request_completed.connect(_scores_completed)
	request.request_completed.connect(_completed)
	all_versions.uri = str(ProjectSettings.get_setting("leaderboard/site_url", ""))
	all_versions.visible = not all_versions.uri.is_empty()
	show_submission(false)
	call_deferred("_restore_username")
	refresh()


func _restore_username() -> void:
	username.text = main.leaderboard_profile.username


func refresh() -> void:
	visible = main.phase != main.Phase.RUNNING
	if visible and not was_visible:
		call_deferred("_load_scores")
	was_visible = visible
	var pending: Dictionary = main.leaderboard_profile.pending
	if pending != displayed_pending:
		displayed_pending = pending.duplicate()
		if not pending.is_empty() and sending.is_empty():
			notice.text = ""
	var offered: bool = main.leaderboard_eligible() and not pending.is_empty()
	if pending != displayed_section_pending:
		displayed_section_pending = pending.duplicate(true)
		show_submission(offered, false)
	submission_button.visible = offered
	rankings_button.get_parent().visible = offered
	prompt.visible = offered
	username.visible = offered
	publish.visible = offered
	skip.visible = offered
	if offered:
		prompt.text = "New personal best · %s\nPublish %.3f seconds with a public username?" % [_version_label(str(pending.version)), float(pending.durationMs) / 1000.0]
		if pending.has("clearTimeMs"):
			prompt.text = "New clear record · %s\nPublish clear time %s with a public username?" % [_version_label(str(pending.version)), _score_time(int(pending.clearTimeMs))]
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
	if not main.leaderboard_eligible():
		notice.text = "Assisted progress · publishing disabled. Reset all progress with assists off to earn eligible records."


func _load_scores() -> void:
	if scores_loading:
		return
	scores_heading.text = "LEADERBOARD · " + ("dev" if main.game_version == "dev" else "v" + main.game_version)
	for row in scores_rows.get_children():
		row.free()
	scores_page.hide()
	pager.hide()
	scores_notice.show()
	refresh_scores.disabled = api_url.is_empty()
	if api_url.is_empty():
		scores_notice.text = "Leaderboard unavailable in this build."
		return
	scores_loading = true
	refresh_scores.disabled = true
	scores_notice.text = "Loading scores…"
	var error := scores_request.request(_scores_url())
	if error != OK:
		_scores_completed(HTTPRequest.RESULT_CANT_CONNECT, 0, [], PackedByteArray())


func _scores_url() -> String:
	return api_url + "/scores?version=" + str(main.game_version).uri_encode()


func _scores_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	scores_loading = false
	refresh_scores.disabled = api_url.is_empty()
	var parser := JSON.new()
	var response: Variant = null
	if not body.is_empty() and parser.parse(body.get_string_from_utf8()) == OK:
		response = parser.data
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or not response is Array:
		scores_notice.text = "Could not load scores. Refresh to try again."
		return
	score_data = response
	page_index = 0
	_render_scores()


func _render_scores() -> void:
	for row in scores_rows.get_children():
		row.free()
	for score in score_data.slice(page_index * PAGE_SIZE, (page_index + 1) * PAGE_SIZE):
		var row := preload("res://screens/leaderboard_row.tscn").instantiate() as Label
		row.text = "#%d  %s\n%s" % [int(score.rank), str(score.username), _score_time(int(score.durationMs))]
		if score.has("clearTimeMs"):
			row.text = "#%d  %s\nCLEAR · %s" % [int(score.rank), str(score.username), _score_time(int(score.clearTimeMs))]
		if score.has("energyInvested"):
			row.text += " · %d energy invested" % int(score.energyInvested)
		if str(score.username) == main.leaderboard_profile.username:
			row.theme_type_variation = &"AccentLabel"
		scores_rows.add_child(row)
	scores_page.visible = not score_data.is_empty()
	pager.visible = score_data.size() > PAGE_SIZE
	previous_page.disabled = page_index == 0
	next_page.disabled = (page_index + 1) * PAGE_SIZE >= score_data.size()
	page_label.text = "%d / %d" % [page_index + 1, maxi(1, ceili(float(score_data.size()) / PAGE_SIZE))]
	scores_notice.text = "No scores yet for this version. Set the first record!" if score_data.is_empty() else "Top %d · fastest clears, then longest survival" % score_data.size()


func _score_time(duration_ms: int) -> String:
	return "%02d:%02d.%03d" % [duration_ms / 60000, (duration_ms / 1000) % 60, duration_ms % 1000]


func _skip() -> void:
	if not sending.is_empty():
		return
	main.leaderboard_profile.pending = {}
	main.save_progress()
	notice.text = "Record kept on this device."
	refresh()
	if is_visible_in_tree():
		main.get_node("Controls").focus_default()


func _publish() -> void:
	if not main.leaderboard_eligible() or not sending.is_empty() or api_url.is_empty() or main.leaderboard_profile.pending.is_empty():
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
		notice.text = "Published! Your record is on the %s leaderboard." % _version_label(str(sending.version))
		# Restart any older read so a successful publish is reflected immediately.
		scores_request.cancel_request()
		scores_loading = false
		_load_scores()
	else:
		notice.text = "Publishing failed. Your record is saved; try again."
		if response is Dictionary and response.get("error") is String:
			notice.text = str(response.error).left(180) + " Your record is saved."
	sending = {}
	refresh()


func _version_label(version: String) -> String:
	return "dev" if version == "dev" else "v" + version


func default_control() -> Control:
	# Prefer the form field or a useful ranking action over the page tabs.
	for control in [username, previous_page, next_page, refresh_scores, all_versions, submission_button, rankings_button]:
		if not control.is_visible_in_tree() or control.focus_mode != Control.FOCUS_ALL:
			continue
		if control is BaseButton and control.disabled or control is LineEdit and not control.editable:
			continue
		return control
	return null


func show_submission(show_form: bool, select_control := true) -> void:
	submission.visible = show_form
	rankings.visible = not show_form
	if select_control and is_visible_in_tree():
		var controls := main.get_node_or_null("Controls")
		if controls != null and controls.is_node_ready():
			controls.focus_default()


func _change_page(direction: int) -> void:
	page_index = clampi(page_index + direction, 0, maxi(0, ceili(float(score_data.size()) / PAGE_SIZE) - 1))
	_render_scores()
