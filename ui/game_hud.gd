extends CanvasLayer

const STYLE = preload("res://ui/ui_style.gd")
const BOSS_VICTORY_DURATION := 3.0
const BOSS_VICTORY_FADE := 1.0
var main: Node2D
var lantern: Node2D
var scroll: Control
var panel: VBoxContainer
var heading: Label
var subheading: Label
var health_text: Label
var boost_text: Label
var health_bar: ProgressBar
var boss_text: Label
var boss_bar: ProgressBar
var earnings: Label
var schedule_text: Label
var detail: Label
var brightness_indicator: Button
var threat: Label
var controls: Label
var save_notice: Label
var leaderboard: VBoxContainer
var health_group: Control
var timer_group: Control
var boss_card: PanelContainer
var boss_status: Control
var boss_warning: Label
var boss_was_alive := false
var last_boss_name := "THE DRENCHER"
var boss_victory_remaining := 0.0
var refresh_elapsed := 0.0
var displayed_brightness := -1


func _ready() -> void:
	layer = 4
	main = get_parent()
	lantern = main.get_node("Lantern")
	scroll = Control.new()
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Explicit text/bar bounds avoid container minimum heights stretching the HUD.
	health_group = Control.new()
	health_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(health_group)
	health_text = STYLE.label("", 15)
	health_group.add_child(health_text)
	boost_text = STYLE.label("", 13, Color("#ffd58a"))
	boost_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	health_group.add_child(boost_text)
	health_bar = _bar(health_group, Color("#ffcf7a"))
	timer_group = Control.new()
	timer_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(timer_group)
	subheading = STYLE.label("", 28)
	subheading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_group.add_child(subheading)
	earnings = STYLE.label("", 14, Color("#ffcf7a"))
	earnings.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_group.add_child(earnings)
	schedule_text = STYLE.label("", 12, Color("#a8e5df"))
	schedule_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_group.add_child(schedule_text)
	boss_card = _card()
	boss_warning = STYLE.label("THE DRENCHER\nIncoming!", 15, Color("#82e2ec"))
	boss_warning.autowrap_mode = TextServer.AUTOWRAP_OFF
	boss_card.add_child(boss_warning)
	boss_status = Control.new()
	boss_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(boss_status)
	boss_text = STYLE.label("", 15, Color("#82e2ec"))
	boss_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	boss_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_status.add_child(boss_text)
	boss_bar = _bar(boss_status, Color("#82e2ec"))
	brightness_indicator = preload("res://ui/brightness_indicator.gd").new()
	scroll.add_child(brightness_indicator)
	brightness_indicator.pressed.connect(func(): lantern.set_brightness((lantern.brightness + 1) % 3))
	for label in [health_text, subheading, earnings, boss_text]:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.add_theme_color_override("font_shadow_color", Color("#080d13"))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
	save_notice = STYLE.label("", 14, Color("#ff997d"))
	scroll.add_child(save_notice)
	# Keep recap data and the single persistent request panel outside the live HUD.
	panel = VBoxContainer.new()
	add_child(panel)
	panel.hide()
	heading = STYLE.label("", 13)
	panel.add_child(heading)
	detail = STYLE.label("", 16)
	panel.add_child(detail)
	threat = STYLE.label("", 14)
	panel.add_child(threat)
	controls = STYLE.label("", 14)
	panel.add_child(controls)
	leaderboard = preload("res://screens/leaderboard_panel.tscn").instantiate()
	leaderboard.main = main
	panel.add_child(leaderboard)
	get_viewport().size_changed.connect(_layout)
	_layout()
	refresh()


func _card() -> PanelContainer:
	var card := PanelContainer.new()
	var style := STYLE.panel()
	style.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", style)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(card)
	return card


func _bar(parent: Node, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 5
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	health_group.position = Vector2(20, 18)
	health_group.size = Vector2(minf(190, size.x * 0.38), 42)
	health_text.position = Vector2.ZERO
	health_text.size = Vector2(health_group.size.x, 22)
	health_bar.position = Vector2(0, 28)
	health_bar.size = Vector2(health_group.size.x, 5)
	boost_text.position = Vector2(0, 38)
	boost_text.size = Vector2(310, 20)
	timer_group.size = Vector2(160, 64)
	timer_group.position = Vector2((size.x - 160) / 2, 16 if size.x >= 700 else 72)
	subheading.position = Vector2.ZERO
	subheading.size = Vector2(160, 36)
	earnings.position = Vector2(0, 38)
	earnings.size = Vector2(160, 20)
	schedule_text.position = Vector2(0, 60)
	schedule_text.size = Vector2(160, 20)
	boss_card.size = Vector2(minf(360, size.x - 32), 72)
	boss_card.position = Vector2((size.x - boss_card.size.x) / 2, 94 if size.x >= 700 else 150)
	boss_status.size = Vector2(minf(260, size.x - 32), 28)
	boss_status.position = Vector2((size.x - boss_status.size.x) / 2, boss_card.position.y)
	boss_text.size = Vector2(boss_status.size.x, 22)
	boss_bar.position = Vector2(0, 24)
	boss_bar.size = Vector2(boss_status.size.x, 4)
	brightness_indicator.size = Vector2(190, 30)
	brightness_indicator.position = Vector2((size.x - 190) / 2, size.y - 46)
	save_notice.position = Vector2(16, size.y - 88)
	save_notice.size = Vector2(size.x - 32, 36)


func _process(delta: float) -> void:
	boss_victory_remaining = maxf(0.0, boss_victory_remaining - delta)
	if boss_victory_remaining > 0.0:
		boss_text.modulate.a = minf(1.0, boss_victory_remaining / BOSS_VICTORY_FADE)
	elif not boss_was_alive:
		boss_status.hide()
	refresh_elapsed += delta
	if refresh_elapsed >= 0.1:
		refresh_elapsed = 0
		refresh()


func format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%02d:%02d" % [total / 60, total % 60]


func _boss_priority(boss: Node) -> int:
	if boss.is_in_group("final_bosses"): return 2
	if boss.is_in_group("rainkeepers"): return 1
	return 0


func refresh() -> void:
	if is_instance_valid(leaderboard):
		leaderboard.refresh()
	var running: bool = lantern.running
	displayed_brightness = lantern.brightness
	scroll.visible = running
	health_bar.visible = running
	var touch := main.get_node_or_null("TouchLayer/TouchControls")
	brightness_indicator.visible = running and not (touch != null and touch.enabled)
	var bosses := get_tree().get_nodes_in_group("bosses").filter(func(boss: Node): return not boss.is_queued_for_deletion())
	# Show the latest encounter even when an earlier boss survives.
	bosses.sort_custom(func(a: Node, b: Node): return _boss_priority(a) > _boss_priority(b))
	if not running:
		boss_was_alive = false
		boss_victory_remaining = 0.0
	elif not bosses.is_empty():
		boss_was_alive = true
		boss_victory_remaining = 0.0
	elif boss_was_alive:
		boss_was_alive = false
		boss_victory_remaining = BOSS_VICTORY_DURATION
	boss_card.hide()
	boss_status.hide()
	boss_bar.visible = running and not bosses.is_empty()
	boss_text.modulate.a = 1.0
	if running and not bosses.is_empty():
		var boss = bosses[0]
		var final_boss: bool = boss.is_in_group("final_bosses")
		var boss_name := "THE SNUFFER" if final_boss else "THE DRENCHER"
		if boss.has_method("boss_title"):
			boss_name = boss.boss_title()
		last_boss_name = boss_name
		boss_warning.text = boss_name + ("\nIncoming! The fight continues." if final_boss else "\nIncoming!")
		boss_card.visible = boss.arrival_remaining > 0
		boss_status.visible = not boss_card.visible
		boss_text.text = "%s · %d / %d" % [boss_name, int(ceil(boss.health)), int(boss.max_health)]
		if boss.has_method("attack_caption"):
			boss_text.text += "\n" + boss.attack_caption()
			boss_status.size.y = 52
			boss_text.size.y = 44
			boss_bar.position.y = 48
		else:
			boss_status.size.y = 28
			boss_text.size.y = 22
			boss_bar.position.y = 24
		boss_bar.max_value = boss.max_health
		boss_bar.value = boss.health
	elif running and boss_victory_remaining > 0.0:
		boss_status.show()
		boss_text.text = last_boss_name + " DEFEATED"
		boss_text.modulate.a = minf(1.0, boss_victory_remaining / BOSS_VICTORY_FADE)
	save_notice.text = ("ASSISTED · Leaderboards disabled\n" if main.run_assisted else "") + main.save_message
	save_notice.visible = not save_notice.text.is_empty()
	health_bar.max_value = lantern.max_health
	health_bar.value = lantern.health
	boost_text.text = "Nearby turrets: ×%.1f damage & fire rate" % main.proximity_multiplier()
	var danger: bool = lantern.health <= lantern.max_health * 0.25
	health_text.text = "%d / %d HP%s" % [int(ceil(lantern.health)), int(lantern.max_health), " · DANGER" if danger else ""]
	health_bar.modulate = Color("#ff806e") if danger else Color.WHITE
	subheading.text = format_time(lantern.elapsed)
	earnings.text = "+%d energy" % int(lantern.energy)
	schedule_text.text = main.encounters.ENCOUNTER_SCHEDULE.period(main.encounter_time())
	if main.boss_reward_earned and lantern.elapsed < main.boss_reward_notice_until:
		schedule_text.text = "Drencher defeated · +%d energy" % int(main.boss_reward_amount)
	threat.text = "New enemies: %d hits" % int(main.encounters.current_enemy_health()) if running else ""
	brightness_indicator.level = lantern.brightness
	brightness_indicator.text = "%s · +%.1f/s" % [lantern.BRIGHTNESS_NAMES[lantern.brightness], lantern.current_energy_rate()]
	if not running:
		heading.text = ("RUN ENDED" if main.last_run.get("voluntary", false) else "THE LIGHT WENT OUT") if not main.last_run.is_empty() else "LITTLE LAST LIGHT"
		heading.text += " · " + main.game_version
		detail.text = "Survived %s · Best %s%s" % [format_time(main.last_run.get("duration", 0)), format_time(main.best_time), "\nNew personal best" if main.last_run.get("new_best", false) else ""]
		earnings.text = "+%d energy earned" % int(main.last_run.get("energy", 0))
	var preparation := main.get_node_or_null("PreparationUI")
	if preparation != null and preparation.is_node_ready():
		preparation.refresh()
