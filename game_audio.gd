extends Node

signal settings_changed
signal cue_played(cue: StringName)

const SOUNDS := {
	&"navigate": preload("res://audio/kenney/interface/click_003.ogg"),
	&"confirm": preload("res://audio/kenney/interface/confirmation_001.ogg"),
	&"back": preload("res://audio/kenney/interface/back_001.ogg"),
	&"place": preload("res://audio/kenney/impact/impactWood_medium_000.ogg"),
	&"shot": preload("res://audio/kenney/scifi/laserSmall_001.ogg"),
	&"rain": preload("res://audio/kenney/scifi/slime_000.ogg"),
	&"damage": preload("res://audio/kenney/impact/impactPunch_heavy_000.ogg"),
	&"upgrade": preload("res://audio/kenney/interface/glass_001.ogg"),
	&"brightness": preload("res://audio/kenney/interface/toggle_001.ogg"),
}
const LEVELS := {&"navigate": -16.0, &"confirm": -10.0, &"back": -12.0, &"place": -10.0, &"shot": -22.0, &"rain": -14.0, &"damage": -12.0, &"upgrade": -12.0, &"brightness": -14.0}
const COMBAT_CUES := [&"shot", &"damage", &"brightness", &"rain"]
const INTERVALS := {&"navigate": 0.08, &"shot": 0.12, &"damage": 0.25}
var players: Dictionary = {}
var cooldowns: Dictionary = {}
var volume: float = 0.5
var muted := false
var settings_path := "user://audio-settings.cfg"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for cue in SOUNDS:
		var player := AudioStreamPlayer.new()
		player.stream = SOUNDS[cue]
		# One shared player per cue bounds the mix even with hundreds of turrets.
		player.max_polyphony = 2 if cue == &"shot" else 1
		add_child(player)
		players[cue] = player
	load_settings()


func _process(delta: float) -> void:
	for cue in cooldowns:
		cooldowns[cue] = maxf(0.0, cooldowns[cue] - delta)


func _exit_tree() -> void:
	for player in players.values():
		player.stop()


func play(cue: StringName) -> bool:
	if muted or volume <= 0.0 or cooldowns.get(cue, 0.0) > 0.0:
		return false
	if get_tree().paused and cue in COMBAT_CUES:
		return false
	var player: AudioStreamPlayer = players[cue]
	player.volume_db = LEVELS[cue] + linear_to_db(volume)
	# Headless checks have no audio device; still exercise cue routing and limits.
	if AudioServer.get_driver_name() != "Dummy":
		player.play()
	cooldowns[cue] = INTERVALS.get(cue, 0.0)
	cue_played.emit(cue)
	return true


func stop_combat() -> void:
	for cue in COMBAT_CUES:
		players[cue].stop()


func bind_buttons(parent: Node, action_buttons: Array) -> void:
	# Button signals cover mouse, keyboard and the controller's pressed.emit().
	for button in parent.find_children("*", "BaseButton", true, false):
		button.focus_entered.connect(func(): play(&"navigate"))
		button.mouse_entered.connect(func():
			if not button.disabled:
				play(&"navigate")
		)
		if button not in action_buttons:
			button.pressed.connect(func(): play(&"confirm"))


func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	_apply_settings()
	save_settings()


func set_muted(value: bool) -> void:
	muted = value
	_apply_settings()
	save_settings()


func _apply_settings() -> void:
	for cue in players:
		if muted or volume <= 0.0:
			players[cue].stop()
		else:
			players[cue].volume_db = LEVELS[cue] + linear_to_db(volume)
	settings_changed.emit()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) == OK:
		volume = clampf(float(config.get_value("sound", "volume", 0.5)), 0.0, 1.0)
		muted = bool(config.get_value("sound", "muted", false))
	_apply_settings()


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("sound", "volume", volume)
	config.set_value("sound", "muted", muted)
	var error := config.save(settings_path)
	if error != OK:
		push_warning("Could not save sound preferences: %s" % error_string(error))
