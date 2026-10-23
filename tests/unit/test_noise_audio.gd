## @file test_noise_audio.gd
## Tests de aceptación para audio de ruido posicional, mezcla, vúmetro y chevron.
## Cubre los criterios 2, 3, 4, 5, 6, 9, 12 y 13 de FEAT-012.
extends GutTest

const NOISE_MIX_PATH: String = "res://assets/audio/noise_mix.tres"
const NOISE_FEEDBACK_PATH: String = "res://data/balance/noise_feedback.tres"
const HUD_SCENE_PATH: String = "res://scenes/ui/hud_84.tscn"


func after_each() -> void:
	GameManager.current_state = GameManager.MatchState.LOBBY
	for node: Node in get_tree().get_nodes_in_group(&"noise_audio"):
		node.queue_free()


func _create_test_map() -> HeistMap3D:
	var map: HeistMap3D = autofree(HeistMap3D.new())
	map.set_physics_process(false)

	var hud_scene: PackedScene = load(HUD_SCENE_PATH) as PackedScene
	var hud: HUD84 = hud_scene.instantiate() as HUD84
	hud.name = "HUD84"
	map.add_child(hud)

	var camera: Camera3D = Camera3D.new()
	camera.name = "IsometricCamera3D"
	map.add_child(camera)

	var thief: ThiefController3D = autofree(ThiefController3D.new())
	thief.name = "Thief"
	thief.position = Vector3.ZERO
	map.add_child(thief)

	var guard: GuardController3D = autofree(GuardController3D.new())
	guard.name = "Guard"
	guard.position = Vector3(50.0, 0.0, 50.0)
	map.add_child(guard)

	add_child_autofree(map)
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
	for p: Node in players:
		p.queue_free()
	await wait_physics_frames(1)

	SignalBus.noise_event_3d.emit(Vector3(0.0, 0.0, r + 0.01), r, &"thief", &"impact", other)
	players = get_tree().get_nodes_in_group(&"noise_audio")
	assert_eq(players.size(), 0, "A r + 0.01m no debe crearse ningún reproductor")


## Criterio 3: D8: El ladrón oye ruidos de guardia a r * thief_hearing_mult
func test_thief_hearing_mult() -> void:
	var map: HeistMap3D = _create_test_map()
	var thief: ThiefController3D = map.thief
	var guard: GuardController3D = map.guards[0]
	var other: Node3D = autofree(Node3D.new())
	add_child_autofree(other)

	# 1. Ladrón local con ruido de guardia (r=4.0, mult=1.5 -> r_ef=6.0)
	map.set_local_player(thief)
	thief.global_position = Vector3.ZERO
	SignalBus.noise_event_3d.emit(Vector3(0.0, 0.0, 5.5), 4.0, &"guard", &"impact", other)
	var players: Array[Node] = get_tree().get_nodes_in_group(&"noise_audio")
	assert_eq(players.size(), 1, "Ladrón oye ruido de guardia a 5.5m cuando r=4.0 (r_ef=6.0)")
	for p: Node in players:
		p.queue_free()
	await wait_physics_frames(1)

	SignalBus.noise_event_3d.emit(Vector3(0.0, 0.0, 6.05), 4.0, &"guard", &"impact", other)
	players = get_tree().get_nodes_in_group(&"noise_audio")
	assert_eq(players.size(), 0, "Ladrón no oye ruido de guardia a 6.05m (r_ef=6.0)")

	# 2. Guardia local con ruido de ladrón (sin multiplicador, r_ef=4.0)
	map.set_local_player(guard)
	guard.global_position = Vector3.ZERO
	SignalBus.noise_event_3d.emit(Vector3(0.0, 0.0, 4.5), 4.0, &"thief", &"impact", other)
	players = get_tree().get_nodes_in_group(&"noise_audio")
	assert_eq(players.size(), 0, "Guardia no oye ruido de ladrón a 4.5m > 4.0m")

	SignalBus.noise_event_3d.emit(Vector3(0.0, 0.0, 3.5), 4.0, &"thief", &"impact", other)
	players = get_tree().get_nodes_in_group(&"noise_audio")
	assert_eq(players.size(), 1, "Guardia oye ruido de ladrón a 3.5m < 4.0m")


## Criterio 4: Fórmula de ganancia y volumen atenuado del reproductor 3D
func test_gain_formula() -> void:
	assert_almost_eq(NoiseAudioRules.gain(0.0, 5.0, 0.2), 1.0, 0.0001, "gain en d=0 vale 1")
	assert_almost_eq(NoiseAudioRules.gain(5.0, 5.0, 0.2), 0.2, 0.0001, "gain en d=r vale f")
	assert_almost_eq(NoiseAudioRules.gain(3.0, 5.25, 0.2), 0.5429, 0.001, "gain 0.5429 en d=3")
	assert_almost_eq(NoiseAudioRules.gain(6.0, 5.0, 0.2), 0.0, 0.0001, "gain en d > r vale 0")

	var map: HeistMap3D = _create_test_map()
	map.set_local_player(map.thief)
	var other: Node3D = autofree(Node3D.new())
	add_child_autofree(other)

	SignalBus.noise_event_3d.emit(Vector3(3.0, 0.0, 0.0), 5.25, &"other", &"impact", other)
	var players: Array[Node] = get_tree().get_nodes_in_group(&"noise_audio")
	assert_eq(players.size(), 1, "Debe crearse 1 reproductor")
	var p3d: AudioStreamPlayer3D = players[0] as AudioStreamPlayer3D
	assert_not_null(p3d, "Debe ser AudioStreamPlayer3D")
	assert_eq(p3d.attenuation_model, AudioStreamPlayer3D.ATTENUATION_DISABLED, "Sin atenuación")

	var g: float = NoiseAudioRules.gain(3.0, 5.25, 0.2)
	var expected_db: float = -6.0 + linear_to_db(g)
	assert_almost_eq(p3d.volume_db, expected_db, 0.01, "volume_db = v_cat + linear_to_db(g)")


## Criterio 5: Ruido propio: AudioStreamPlayer sin posición y dB de paso según ratio
func test_own_noise_audio() -> void:
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

	var exp_db: float = -22.0 + linear_to_db(clampf(3.5 / 10.0, 0.05, 1.0))
	assert_almost_eq(p2d.volume_db, exp_db, 0.01, "volume_db propio de paso correcto")
	assert_gte(p2d.pitch_scale, 1.0 - 0.06 - 0.001, "pitch_scale >= 1 - jitter")
	assert_lte(p2d.pitch_scale, 1.0 + 0.06 + 0.001, "pitch_scale <= 1 + jitter")
	for p: Node in players:
		p.queue_free()
	await wait_physics_frames(1)

	# 2. Golpe y mecanismo propios usan v_cat (-6.0 y -10.0)
	SignalBus.noise_event_3d.emit(thief.global_position, 3.5, &"thief", &"impact", thief)
	players = get_tree().get_nodes_in_group(&"noise_audio")
	assert_almost_eq((players[0] as AudioStreamPlayer).volume_db, -6.0, 0.01, "impact -6dB")
	for p: Node in players:
		p.queue_free()
	await wait_physics_frames(1)

	SignalBus.noise_event_3d.emit(thief.global_position, 3.5, &"thief", &"mechanism", thief)
	players = get_tree().get_nodes_in_group(&"noise_audio")
	assert_almost_eq((players[0] as AudioStreamPlayer).volume_db, -10.0, 0.01, "mechanism -10dB")


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

	# 1. Multiplicador 0.4 -> step_soft
	detector.set("mock_mult", 0.4)
	SignalBus.noise_event_3d.emit(guard.global_position, 3.0, &"guard", &"step", guard)
	var players: Array[Node] = get_tree().get_nodes_in_group(&"noise_audio")
	assert_true(mix.step_soft.has(players[0].get("stream")), "Suelo 0.4 usa step_soft")
	players[0].queue_free()
	await wait_physics_frames(1)

	# 2. Multiplicador 1.0 -> step_wood
	detector.set("mock_mult", 1.0)
	SignalBus.noise_event_3d.emit(guard.global_position, 3.0, &"guard", &"step", guard)
	players = get_tree().get_nodes_in_group(&"noise_audio")
	assert_true(mix.step_wood.has(players[0].get("stream")), "Suelo 1.0 usa step_wood")
	players[0].queue_free()
	await wait_physics_frames(1)

	# 3. Multiplicador 1.6 -> step_hard
	detector.set("mock_mult", 1.6)
	SignalBus.noise_event_3d.emit(guard.global_position, 3.0, &"guard", &"step", guard)
	players = get_tree().get_nodes_in_group(&"noise_audio")
	assert_true(mix.step_hard.has(players[0].get("stream")), "Suelo 1.6 usa step_hard")


## Criterio 9: Chevron para ruidos no-paso que alcanzan al local fuera de pantalla
func test_offscreen_marker() -> void:
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
	assert_almost_eq((markers[0] as OffscreenChevron84).lifetime, 2.0, 0.01, "Duración 2.0s")
	for m: Node in markers:
		m.free()

	# 2. Paso en la misma situación fuera de frustum NO crea chevron
	SignalBus.noise_event_3d.emit(offscreen_pos, 5.0, &"guard", &"step", guard)
	assert_eq(map.hud.get_active_offscreen_markers().size(), 0, "Paso no genera chevron")

	# 3. Ruido dentro de pantalla NO crea chevron
	var onscreen_pos: Vector3 = Vector3.ZERO
	thief.global_position = onscreen_pos
	guard.global_position = onscreen_pos
	assert_true(map.camera.is_position_in_frustum(onscreen_pos), "Posición dentro de frustum")
	SignalBus.noise_event_3d.emit(onscreen_pos, 5.0, &"guard", &"impact", guard)
	assert_eq(map.hud.get_active_offscreen_markers().size(), 0, "Ruido en pantalla no crea chevron")


## Criterio 12: No quedan archivos de anillos ni MeshInstance3D generados por ruido
func test_no_noise_rings() -> void:
	assert_false(
		FileAccess.file_exists("res://src/vfx/sound_wave_3d.gd"), "sound_wave_3d.gd no debe existir"
	)
	assert_false(
		FileAccess.file_exists("res://assets/shaders/sound_wave_3d.gdshader"),
		"sound_wave_3d.gdshader no debe existir"
	)

	var map: HeistMap3D = _create_test_map()
	map.set_local_player(map.thief)
	var guard: GuardController3D = map.guards[0]
	guard.global_position = Vector3(0.0, 0.0, 2.0)
	SignalBus.noise_event_3d.emit(guard.global_position, 5.0, &"guard", &"impact", guard)

	var meshes: Array[Node] = map.find_children("*", "MeshInstance3D", true, false)
	var ring_mesh_count: int = 0
	for m: Node in meshes:
		if m.is_in_group(&"noise_audio"):
			ring_mesh_count += 1
	assert_eq(ring_mesh_count, 0, "Ningún MeshInstance3D debe ser creado por ruidos")


## Criterio 13: 25 muestras existen, cargan, están en CREDITS.md y ordenadas en noise_mix.tres
func test_noise_mix_streams() -> void:
	var carpets: String = "res://assets/audio/sfx/step_carpet/footstep_carpet_%03d.ogg"
	var woods: String = "res://assets/audio/sfx/step_wood/footstep_wood_%03d.ogg"
	var hards: String = "res://assets/audio/sfx/step_hard/footstep_concrete_%03d.ogg"
	var impacts: String = "res://assets/audio/sfx/impact/impact_punch_%03d.ogg"
	var mechs: String = "res://assets/audio/sfx/mechanism/switch_%03d.ogg"

	for i: int in range(5):
		for path_fmt: String in [carpets, woods, hards, impacts]:
			var path: String = path_fmt % i
			assert_true(FileAccess.file_exists(path), "Muestra %s debe existir" % path)
			assert_not_null(load(path) as AudioStream, "Muestra %s carga como AudioStream" % path)
		var path_m: String = mechs % (i + 1)
		assert_true(FileAccess.file_exists(path_m), "Muestra %s debe existir" % path_m)
		assert_not_null(load(path_m) as AudioStream, "Muestra %s carga como AudioStream" % path_m)

	assert_true(FileAccess.file_exists("res://assets/audio/CREDITS.md"), "CREDITS.md existe")
	var credits: String = FileAccess.get_file_as_string("res://assets/audio/CREDITS.md")
	assert_true(credits.contains("CC0"), "CREDITS.md menciona licencia CC0")
	assert_true(credits.contains("Kenney"), "CREDITS.md menciona autor Kenney")

	var mix: NoiseMix = load(NOISE_MIX_PATH) as NoiseMix
	assert_not_null(mix, "noise_mix.tres debe cargarse")
	var arrays: Array[Array] = [
		mix.step_soft, mix.step_wood, mix.step_hard, mix.impact, mix.mechanism
	]
	for arr: Array in arrays:
		assert_eq(arr.size(), 5, "Cada array debe contener 5 muestras")
		for i: int in range(1, arr.size()):
			assert_gt(
				arr[i].resource_path, arr[i - 1].resource_path, "Muestras ordenadas por nombre"
			)
