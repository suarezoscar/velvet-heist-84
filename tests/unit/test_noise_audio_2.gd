## @file test_noise_audio_2.gd
## Tests de aceptación para vúmetro, chevron y muestras de ruido (FEAT-012), parte 2: criterios
## 6, 9, 12 y 13. El audio posicional y la mezcla están en test_noise_audio.gd.
extends GutTest

const NOISE_MIX_PATH: String = "res://assets/audio/noise_mix.tres"
const NOISE_FEEDBACK_PATH: String = "res://data/balance/noise_feedback.tres"
const HUD_PALETTE_PATH: String = "res://assets/ui/hud_palette.tres"
const HUD_SCENE_PATH: String = "res://scenes/ui/hud_84.tscn"


func after_each() -> void:
	GameManager.current_state = GameManager.MatchState.LOBBY
	for node: Node in get_tree().get_nodes_in_group(&"noise_audio"):
		node.queue_free()


func _clear_noise() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"noise_audio"):
		node.queue_free()
	await wait_physics_frames(1)


func _create_test_map() -> HeistMap3D:
	var map: HeistMap3D = autofree(HeistMap3D.new())
	var hud_scene: PackedScene = load(HUD_SCENE_PATH) as PackedScene
	var hud: HUD84 = hud_scene.instantiate() as HUD84
	var camera: Camera3D = Camera3D.new()
	var thief: ThiefController3D = autofree(ThiefController3D.new())
	var guard: GuardController3D = autofree(GuardController3D.new())
	hud.name = "HUD84"
	camera.name = "IsometricCamera3D"
	thief.name = "Thief"
	guard.name = "Guard"
	guard.position = Vector3(10.0, 0.0, 0.0)
	map.add_child(hud)
	map.add_child(camera)
	map.add_child(thief)
	map.add_child(guard)
	add_child_autofree(map)
	map.set_physics_process(false)
	thief.set_physics_process(false)
	guard.set_physics_process(false)
	if map.noise_audio_presenter != null:
		map.noise_audio_presenter.rng.seed = 12345
	return map


## Criterio 6: Familia de pasos según multiplicador de suelo (0.4 soft, 1.0 wood, 1.6 hard)
func test_step_surface_family() -> void:
	var map: HeistMap3D = _create_test_map()
	var thief: ThiefController3D = map.thief
	var guard: GuardController3D = map.guards[0]
	map.set_local_player(thief)
	guard.global_position = Vector3(0.0, 0.0, 2.0)

	var detector: SurfaceDetector3D = autofree(SurfaceDetector3D.new())
	var gd_script: GDScript = GDScript.new()
	var src: String = "@tool\nextends SurfaceDetector3D\n"
	src += "var mock_mult: float = 1.0\n"
	src += "func get_surface_noise_multiplier() -> float:\n\treturn mock_mult\n"
	gd_script.source_code = src
	gd_script.reload()
	detector.set_script(gd_script)
	guard.surface_detector = detector
	var mix: NoiseMix = load(NOISE_MIX_PATH) as NoiseMix

	var mults: Array[float] = [0.4, 1.0, 1.6]
	var families: Array = [mix.step_soft, mix.step_wood, mix.step_hard]
	for i: int in range(3):
		detector.set("mock_mult", mults[i])
		SignalBus.noise_event_3d.emit(guard.global_position, 3.0, &"guard", &"step", guard)
		var players: Array[Node] = get_tree().get_nodes_in_group(&"noise_audio")
		assert_eq(players.size(), 1, "Debe crearse 1 reproductor")
		assert_true(families[i].has(players[0].get("stream")), "Suelo usa familia")
		await _clear_noise()


## Criterio 9: Chevron para ruidos no-paso que alcanzan al local fuera de pantalla
func test_offscreen_marker() -> void:
	var feedback: NoiseFeedbackProfile = load(NOISE_FEEDBACK_PATH) as NoiseFeedbackProfile
	var palette: HudPalette = load(HUD_PALETTE_PATH) as HudPalette
	var map: HeistMap3D = _create_test_map()
	var thief: ThiefController3D = map.thief
	var guard: GuardController3D = map.guards[0]
	map.set_local_player(thief)

	var offscreen_pos: Vector3 = Vector3(80.0, 0.0, 80.0)
	thief.global_position = offscreen_pos
	guard.global_position = offscreen_pos
	map.camera.global_position = Vector3(0.0, 10.0, 10.0)
	map.camera.look_at(Vector3.ZERO, Vector3.UP)
	assert_false(map.camera.is_position_in_frustum(offscreen_pos), "Posición fuera de frustum")

	# 1. Golpe fuera de pantalla audible crea chevron
	SignalBus.noise_event_3d.emit(offscreen_pos, 5.0, &"guard", &"impact", guard)
	var markers: Array[Node] = map.hud.get_active_offscreen_markers()
	assert_eq(markers.size(), 1, "Golpe fuera de frustum crea chevron en HUD")
	var chevron: OffscreenChevron84 = markers[0] as OffscreenChevron84
	assert_not_null(chevron, "Marcador debe ser OffscreenChevron84")
	assert_almost_eq(chevron.lifetime, feedback.offscreen_marker_time, 0.01, "Duración")
	assert_eq(chevron.chevron_color, palette.color_guard, "Color del chevron es guard")
	if chevron.get("role") != null:
		assert_eq(chevron.get("role"), &"guard", "Role del chevron debe ser &'guard'")
	for m: Node in markers:
		m.free()

	# 2. Paso en la misma situación fuera de frustum NO crea chevron
	SignalBus.noise_event_3d.emit(offscreen_pos, 5.0, &"guard", &"step", guard)
	assert_eq(map.hud.get_active_offscreen_markers().size(), 0, "Paso no genera chevron")

	# 3. Ruido dentro de pantalla NO crea chevron
	thief.global_position = Vector3.ZERO
	guard.global_position = Vector3.ZERO
	assert_true(map.camera.is_position_in_frustum(Vector3.ZERO), "Posición dentro de frustum")
	SignalBus.noise_event_3d.emit(Vector3.ZERO, 5.0, &"guard", &"impact", guard)
	assert_eq(map.hud.get_active_offscreen_markers().size(), 0, "Ruido en pantalla no crea chevron")


## Criterio 12: No quedan archivos de anillos ni MeshInstance3D generados por ruido
func test_no_noise_rings() -> void:
	assert_false(FileAccess.file_exists("res://src/vfx/sound_wave_3d.gd"))
	assert_false(FileAccess.file_exists("res://assets/shaders/sound_wave_3d.gdshader"))

	var map: HeistMap3D = _create_test_map()
	map.set_local_player(map.thief)
	var guard: GuardController3D = map.guards[0]
	guard.global_position = Vector3(0.0, 0.0, 2.0)
	var count_before: int = map.find_children("*", "MeshInstance3D", true, false).size()

	for cat: StringName in [&"step", &"impact", &"mechanism"]:
		SignalBus.noise_event_3d.emit(guard.global_position, 5.0, &"guard", cat, guard)
	await wait_physics_frames(1)

	var count_after: int = map.find_children("*", "MeshInstance3D", true, false).size()
	assert_eq(count_after, count_before, "No deben crearse nuevos MeshInstance3D por ruidos")


## Criterio 13: 25 muestras existen, cargan, están en CREDITS.md y ordenadas en noise_mix.tres
func test_noise_mix_streams() -> void:
	var carpets: String = "res://assets/audio/sfx/step_carpet/footstep_carpet_%03d.ogg"
	var woods: String = "res://assets/audio/sfx/step_wood/footstep_wood_%03d.ogg"
	var hards: String = "res://assets/audio/sfx/step_hard/footstep_concrete_%03d.ogg"
	var impacts: String = "res://assets/audio/sfx/impact/impact_punch_%03d.ogg"
	var mechs: String = "res://assets/audio/sfx/mechanism/switch_%03d.ogg"

	var mix: NoiseMix = load(NOISE_MIX_PATH) as NoiseMix
	assert_not_null(mix, "noise_mix.tres debe cargarse")
	for i: int in range(5):
		assert_eq(mix.step_soft[i].resource_path, carpets % i)
		assert_eq(mix.step_wood[i].resource_path, woods % i)
		assert_eq(mix.step_hard[i].resource_path, hards % i)
		assert_eq(mix.impact[i].resource_path, impacts % i)
		assert_eq(mix.mechanism[i].resource_path, mechs % (i + 1))

	assert_true(FileAccess.file_exists("res://assets/audio/CREDITS.md"), "CREDITS.md existe")
	var credits: String = FileAccess.get_file_as_string("res://assets/audio/CREDITS.md")
	assert_true(credits.contains("CC0"), "CREDITS.md menciona licencia CC0")
	for f: String in ["step_carpet", "step_wood", "step_hard", "impact", "mechanism"]:
		assert_true(credits.contains(f), "CREDITS.md contiene carpeta %s" % f)
	var sha1: String = "029d734af1582474edf3a694d1b0cebc97c1c152f2f39fa34d4c2bafc5de77f8"
	var sha2: String = "f2193d072726d6758a5f7871b2dcc54dcce0d5c35c6f0a62f92549b327c81232"
	assert_true(credits.contains(sha1), "CREDITS.md contiene SHA-256 de Impact")
	assert_true(credits.contains(sha2), "CREDITS.md contiene SHA-256 de Interface")
