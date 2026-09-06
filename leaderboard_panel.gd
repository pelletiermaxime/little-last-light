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
	scores_heading = Label.new()
	scores_heading.add_theme_color_override("font_color", Color("#ffcf7a"))
	add_child(scores_heading)
	scores_notice = Label.new()
	scores_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(scores_notice)
	scores_page = VBoxContainer.new()
	add_child(scores_page)
	scores_rows = VBoxContainer.new()
	scores_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scores_rows.add_theme_constant_override("separation", 10)
	scores_page.add_child(scores_rows)
	refresh_scores = Button.new()
	refresh_scores.text = "Refresh leaderboard"
	refresh_scores.pressed.connect(_load_scores)
	add_child(refresh_scores)
	var site_url := str(ProjectSettings.get_setting("leaderboard/site_url", ""))
	if not site_url.is_empty():
		all_versions = LinkButton.new()
		all_versions.text = "All versions · online leaderboard"
		all_versions.uri = site_url
		add_child(all_versions)
	scores_request = HTTPRequest.new()
	scores_request.timeout = 15.0
	scores_request.request_completed.connect(_scores_completed)
	add_child(scores_request)
	request = HTTPRequest.new()
	request.timeout = 15.0
	request.body_size_limit = 8192
	request.request_completed.connect(_completed)
	add_child(request)
	_create_pages()
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
	var offered := not pending.is_empty()
	if pending != displayed_section_pending:
		displayed_section_pending = pending.duplicate(true)
		show_submission(offered)
	submission_button.visible = offered
	rankings_button.get_parent().visible = offered
	prompt.visible = offered
	username.visible = offered
	publish.visible = offered
	skip.visible = offered
	if offered:
		prompt.text = "New personal best · %s\nPublish %.3f seconds with a public username?" % [_version_label(str(pending.version)), float(pending.durationMs) / 1000.0]
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
		var row := Label.new()
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.text = "#%d  %s\n%s" % [int(score.rank), str(score.username), _score_time(int(score.durationMs))]
		if score.has("energyInvested"):
			row.text += " · %d energy invested" % int(score.energyInvested)
		if str(score.username) == main.leaderboard_profile.username:
			row.add_theme_color_override("font_color", Color("#ffcf7a"))
		scores_rows.add_child(row)
	scores_page.visible = not score_data.is_empty()
	pager.visible = score_data.size() > PAGE_SIZE
	previous_page.disabled = page_index == 0
	next_page.disabled = (page_index + 1) * PAGE_SIZE >= score_data.size()
	page_label.text = "%d / %d" % [page_index + 1, maxi(1, ceili(float(score_data.size()) / PAGE_SIZE))]
	scores_notice.text = "No scores yet for this version. Set the first record!" if score_data.is_empty() else "Top %d · survival time" % score_data.size()


func _score_time(duration_ms: int) -> String:
	return "%02d:%02d.%03d" % [duration_ms / 60000, (duration_ms / 1000) % 60, duration_ms % 1000]


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


func _page_button(text: String, callback: Callable, parent: Node) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preload("res://ui_style.gd").button(button)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _create_pages() -> void:
	var tabs := HBoxContainer.new()
	add_child(tabs)
	move_child(tabs, 0)
	rankings_button = _page_button("Rankings", func(): show_submission(false), tabs)
	submission_button = _page_button("Publish record", func(): show_submission(true), tabs)
	submission = VBoxContainer.new()
	submission.add_theme_constant_override("separation", 8)
	add_child(submission)
	for control in [prompt, username, publish, skip]:
		control.reparent(submission)
	rankings = VBoxContainer.new()
	rankings.add_theme_constant_override("separation", 8)
	add_child(rankings)
	for control in [scores_heading, scores_notice, scores_page]:
		control.reparent(rankings)
	pager = HBoxContainer.new()
	rankings.add_child(pager)
	previous_page = _page_button("Previous", func(): _change_page(-1), pager)
	page_label = Label.new()
	page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pager.add_child(page_label)
	next_page = _page_button("Next", func(): _change_page(1), pager)
	refresh_scores.reparent(rankings)
	if all_versions != null:
		all_versions.reparent(rankings)
		all_versions.text = "All versions online"
	for button in [publish, skip, refresh_scores]:
		preload("res://ui_style.gd").button(button)
	move_child(notice, get_child_count() - 1)
	pager.hide()
	show_submission(false)


func show_submission(show_form: bool) -> void:
	submission.visible = show_form
	rankings.visible = not show_form


func _change_page(direction: int) -> void:
	page_index = clampi(page_index + direction, 0, maxi(0, ceili(float(score_data.size()) / PAGE_SIZE) - 1))
	_render_scores()
