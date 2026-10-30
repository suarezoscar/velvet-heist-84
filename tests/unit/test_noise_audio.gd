## @file test_noise_audio.gd
## Tests de aceptación para audio de ruido posicional, mezcla, vúmetro y chevron.
## Cubre los criterios 2, 3, 4, 5, 6, 9, 12 y 13 de FEAT-012.
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


## Criterio 2: Inv. 24: Audio si y solo si alcanza al oyente local (+-0.01 m)
func test_inv24_audio_iff_reaches() -> void:
	var map: HeistMap3D = _create_test_map()
	var guard: GuardController3D = map.guards[0]
	map.set_local_player(guard)
	guard.global_position = Vector3.ZERO
	var r: float = 5.0
	var other: Node3D = autofree(Node3D.new())
	add_child_autofree(other)

	SignalBus.noise_event_3d.emit(Vector3(0.0, 0.0, r - 0.01), r, &"thief", &"impact", other)
	var players: Array[Node] = get_tree().get_nodes_in_group(&"noise_audio")
	assert_eq(players.size(), 1, "A r - 0.01m debe crearse exactamente 1 reproductor")
	assert_true(players[0] is AudioStreamPlayer3D, "Reproductor ajeno debe ser AudioStreamPlayer3D")
	await _clear_noise()

	SignalBus.noise_event_3d.emit(Vector3(0.0, 0.0, r), r, &"thief", &"impact", other)
	players = get_tree().get_nodes_in_group(&"noise_audio")
	assert_eq(players.size(), 1, "A r exacto crea 1 reproductor")
	await _clear_noise()

	SignalBus.noise_event_3d.emit(Vector3(0.0, 0.0, r + 0.01), r, &"thief", &"impact", other)
	players = get_tree().get_nodes_in_group(&"noise_audio")
	assert_eq(players.size(), 0, "A r + 0.01m no debe crearse ningún reproductor")


## Criterio 3: D8: El ladrón oye ruidos de guardia a r * thief_hearing_mult
func test_thief_hearing_mult() -> void:
	var feedback: NoiseFeedbackProfile = load(NOISE_FEEDBACK_PATH) as NoiseFeedbackProfile
	var mult: float = feedback.thief_hearing_mult
	var map: HeistMap3D = _create_test_map()
	var thief: ThiefController3D = map.thief
	var guard: GuardController3D = map.guards[0]
	var other: Node3D = autofree(Node3D.new())
	add_child_autofree(other)
	var r: float = 4.0

	# 1. Ladrón local con ruido de guardia (guardia al menos a 1 m del ladrón)
	map.set_local_player(thief)
	thief.global_position = Vector3.ZERO
	guard.global_position = Vector3(10.0, 0.0, 0.0)

	await _clear_noise()
	var t_pos: Vector3 = Vector3(0.0, 0.0, r * mult)
	SignalBus.noise_event_3d.emit(t_pos - Vector3(0.0, 0.0, 0.01), r, &"guard", &"impact", other)
	var players: Array[Node] = get_tree().get_nodes_in_group(&"noise_audio")
	assert_eq(players.size(), 1, "Ladrón oye ruido de guardia a r*mult - 0.01")

	await _clear_noise()
	SignalBus.noise_event_3d.emit(t_pos + Vector3(0.0, 0.0, 0.01), r, &"guard", &"impact", other)
	players = get_tree().get_nodes_in_group(&"noise_audio")
	assert_eq(players.size(), 0, "Ladrón no oye ruido de guardia a r*mult + 0.01")

	# 2. Guardia local con ruido de ladrón (sin multiplicador)
	map.set_local_player(guard)
	var gpos: Vector3 = guard.global_position

	await _clear_noise()
	SignalBus.noise_event_3d.emit(gpos + Vector3(0.0, 0.0, r + 0.01), r, &"thief", &"impact", other)
	players = get_tree().get_nodes_in_group(&"noise_audio")
	assert_eq(players.size(), 0, "Guardia no oye ruido de ladrón a r + 0.01")

	await _clear_noise()
	SignalBus.noise_event_3d.emit(gpos + Vector3(0.0, 0.0, r - 0.01), r, &"thief", &"impact", other)
	players = get_tree().get_nodes_in_group(&"noise_audio")
	assert_eq(players.size(), 1, "Guardia oye ruido de ladrón a r - 0.01")


## Criterio 4: Fórmula de ganancia y volumen atenuado del reproductor 3D
func test_gain_formula() -> void:
	assert_almost_eq(NoiseAudioRules.gain(0.0, 5.0, 0.2), 1.0, 0.0001, "gain en d=0 vale 1")
	assert_almost_eq(NoiseAudioRules.gain(5.0, 5.0, 0.2), 0.2, 0.0001, "gain en d=r vale f")
	assert_almost_eq(NoiseAudioRules.gain(3.0, 5.25, 0.2), 0.5429, 0.001, "gain 0.5429 en d=3")
	assert_almost_eq(NoiseAudioRules.gain(6.0, 5.0, 0.2), 0.0, 0.0001, "gain en d > r vale 0")

	var feedback: NoiseFeedbackProfile = load(NOISE_FEEDBACK_PATH) as NoiseFeedbackProfile
	var mix: NoiseMix = load(NOISE_MIX_PATH) as NoiseMix
	var map: HeistMap3D = _create_test_map()
	map.set_local_player(map.thief)
	var other: Node3D = autofree(Node3D.new())
	add_child_autofree(other)

	SignalBus.noise_event_3d.emit(Vector3(3.0, 0.0, 0.0), 5.25, &"other", &"impact", other)
	var players: Array[Node] = get_tree().get_nodes_in_group(&"noise_audio")
	assert_eq(players.size(), 1, "Debe crearse 1 reproductor")
	var p3d: AudioStreamPlayer3D = players[0] as AudioStreamPlayer3D
	assert_not_null(p3d, "Debe ser AudioStreamPlayer3D")
	assert_eq(p3d.attenuation_model, AudioStreamPlayer3D.ATTENUATION_DISABLED)

	var g: float = NoiseAudioRules.gain(3.0, 5.25, feedback.audio_edge_floor)
	var expected_db: float = mix.impact_db + linear_to_db(g)
	assert_almost_eq(p3d.volume_db, expected_db, 0.01, "volume_db = v_cat + linear_to_db(g)")


## Criterio 5: Ruido propio: AudioStreamPlayer sin posición y dB de paso según ratio
func test_own_noise_audio() -> void:
	var feedback: NoiseFeedbackProfile = load(NOISE_FEEDBACK_PATH) as NoiseFeedbackProfile
	var mix: NoiseMix = load(NOISE_MIX_PATH) as NoiseMix
	var map: HeistMap3D = _create_test_map()
	var thief: ThiefController3D = map.thief
	map.set_local_player(thief)

	# 1. Paso propio (r=3.5 sobre escala 10.0 -> ratio 0.35)
	SignalBus.noise_event_3d.emit(thief.global_position, 3.5, &"thief", &"step", thief)
	var players: Array[Node] = get_tree().get_nodes_in_group(&"noise_audio")
	assert_eq(players.size(), 1, "Crea reproductor para paso propio")
	var p2d: AudioStreamPlayer = players[0] as AudioStreamPlayer
	assert_not_null(p2d, "Debe ser AudioStreamPlayer 2D sin posición")
	assert_false(players[0] is AudioStreamPlayer3D, "No debe ser 3D")

	var ratio: float = clampf(3.5 / feedback.meter_full_scale, feedback.own_step_min_ratio, 1.0)
	var exp_db: float = maxf(
		feedback.own_step_volume_db + linear_to_db(ratio), feedback.min_audible_db
	)
	assert_almost_eq(p2d.volume_db, exp_db, 0.01, "volume_db propio de paso correcto")
	var p_min: float = 1.0 - feedback.pitch_jitter - 0.001
	var p_max: float = 1.0 + feedback.pitch_jitter + 0.001
	assert_gte(p2d.pitch_scale, p_min, "pitch_scale >= 1 - jitter")
	assert_lte(p2d.pitch_scale, p_max, "pitch_scale <= 1 + jitter")
	await _clear_noise()

	# 2. Golpe y mecanismo propios usan mix.impact_db y mix.mechanism_db
	SignalBus.noise_event_3d.emit(thief.global_position, 3.5, &"thief", &"impact", thief)
	players = get_tree().get_nodes_in_group(&"noise_audio")
	assert_eq(players.size(), 1, "Crea reproductor para golpe propio")
	assert_almost_eq((players[0] as AudioStreamPlayer).volume_db, mix.impact_db, 0.01)
	await _clear_noise()

	SignalBus.noise_event_3d.emit(thief.global_position, 3.5, &"thief", &"mechanism", thief)
	players = get_tree().get_nodes_in_group(&"noise_audio")
	assert_eq(players.size(), 1, "Crea reproductor para mecanismo propio")
	assert_almost_eq((players[0] as AudioStreamPlayer).volume_db, mix.mechanism_db, 0.01)


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
