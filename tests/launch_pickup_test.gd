extends SceneTree

# Isolated visual/playable fixture: normal movement and pickup behavior, no save
# pollution. Pass -- --capture to save rendered states and exit automatically.
var path := "/tmp/lll-pickup-playtest-%d.json" % OS.get_process_id()

func _initialize() -> void:
	call_deferred("launch")

func launch() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.save_path = path
	root.add_child(scene)
	scene.start_run()
	scene.lantern.max_health = 1000.0
	scene.lantern.health = 1000.0
	var pickups = scene.pickups
	pickups.next_spawn = 10000.0
	pickups.active = true
	pickups.remaining = 18.0
	pickups.kind = pickups.Kind.KINDLING
	pickups.pickup_position = scene.lantern.position + Vector2(180, 40)
	if not OS.get_cmdline_user_args().has("--capture"):
		# After the first marker, return to normal cadence; the second type is random.
		pickups.next_spawn = 30.0
		return
	scene.set_process(false)
	scene.lantern.set_process(false)
	scene.lantern.set_physics_process(false)
	scene._set_turrets_active(false)
	await capture("kindling")
	pickups.kind = pickups.Kind.FLARE
	await capture("flare")
	scene.lantern.position = pickups.pickup_position
	await capture("burst")
	pickups.active = true
	pickups.kind = pickups.Kind.KINDLING
	await capture("active")
	scene.free()
	DirAccess.remove_absolute(path)
	quit()

func capture(state: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/lll-pickup-%s.png" % state)
