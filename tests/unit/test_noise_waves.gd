## @file test_noise_waves.gd
## Tests de las miniondas de ruido (#114): reglas puras, reserva y enganche en el presentador.
extends GutTest

const HUD_SCENE_PATH: String = "res://scenes/ui/hud_84.tscn"
const FEEDBACK: NoiseFeedbackProfile = preload("res://data/balance/noise_feedback.tres")
const HEARING: float = 1.5


func _guard(pos: Vector3 = Vector3.ZERO) -> GuardController3D:
	var guard: GuardController3D = autofree(GuardController3D.new())
	add_child_autofree(guard)
	guard.set_physics_process(false)
	guard.global_position = pos
	return guard


func _thief(pos: Vector3 = Vector3.ZERO) -> ThiefController3D:
	var thief: ThiefController3D = autofree(ThiefController3D.new())
	add_child_autofree(thief)
	thief.set_physics_process(false)
	thief.global_position = pos
	return thief


func test_guard_sees_thief_noise_that_reaches() -> void:
	var guard: GuardController3D = _guard()
	var thief: ThiefController3D = _thief(Vector3(50, 0, 0))
	var got: bool = NoiseWaveRules.should_show(
		guard, Vector3(3, 0, 0), 3.5, &"thief", thief, HEARING
	)
	assert_true(got, "El guardia ve el ruido del ladrón que le alcanza")


func test_guard_does_not_see_out_of_radius() -> void:
	var guard: GuardController3D = _guard()
	var thief: ThiefController3D = _thief(Vector3(50, 0, 0))
	var got: bool = NoiseWaveRules.should_show(
		guard, Vector3(4, 0, 0), 3.5, &"thief", thief, HEARING
	)
	assert_false(got, "Fuera de radio no hay onda")


func test_own_noise_has_no_wave() -> void:
	var guard: GuardController3D = _guard()
	var got: bool = NoiseWaveRules.should_show(
		guard, Vector3(1, 0, 0), 3.5, &"thief", guard, HEARING
	)
	assert_false(got, "Lo propio no hace onda")


func test_same_team_noise_has_no_wave() -> void:
	var guard: GuardController3D = _guard()
	var other: GuardController3D = _guard(Vector3(50, 0, 0))
	var got: bool = NoiseWaveRules.should_show(
		guard, Vector3(1, 0, 0), 3.5, &"guard", other, HEARING
	)
	assert_false(got, "El ruido del propio bando no hace onda")


func test_thief_hears_guard_with_multiplier() -> void:
	var thief: ThiefController3D = _thief()
	var guard: GuardController3D = _guard(Vector3(50, 0, 0))
	# radio 4: distancia 5 queda entre el radio (4) y radio x 1,5 (6)
	var got: bool = NoiseWaveRules.should_show(
		thief, Vector3(5, 0, 0), 4.0, &"guard", guard, HEARING
	)
	assert_true(got, "El ladrón ve ruidos de guardia hasta radio x 1,5")
	got = NoiseWaveRules.should_show(thief, Vector3(6.5, 0, 0), 4.0, &"guard", guard, HEARING)
	assert_false(got, "Más allá de radio x 1,5 no")


func test_neutral_team_and_null_local() -> void:
	var guard: GuardController3D = _guard()
	var thief: ThiefController3D = _thief(Vector3(50, 0, 0))
	assert_false(
		NoiseWaveRules.should_show(guard, Vector3(1, 0, 0), 3.5, &"neutral", thief, HEARING),
		"Un equipo neutral no hace onda"
	)
	assert_false(
		NoiseWaveRules.should_show(null, Vector3(1, 0, 0), 3.5, &"thief", thief, HEARING),
		"Sin jugador local no hay onda"
	)


func test_wave_radius_clamps_and_scales() -> void:
	assert_eq(
		NoiseWaveRules.wave_radius(0.5, FEEDBACK), FEEDBACK.wave_min_radius, "Pequeño: mínimo"
	)
	assert_eq(
		NoiseWaveRules.wave_radius(100.0, FEEDBACK), FEEDBACK.wave_max_radius, "Grande: máximo"
	)
	var mid: float = (FEEDBACK.wave_min_radius + FEEDBACK.wave_max_radius) * 0.5
	var r: float = mid / FEEDBACK.wave_radius_scale
	assert_almost_eq(NoiseWaveRules.wave_radius(r, FEEDBACK), mid, 0.001, "Medio: radio x escala")


func test_pool_spawn_and_reuse() -> void:
	var pool: NoiseWavePool = NoiseWavePool.new()
	add_child_autofree(pool)
	var wave: NoiseWave3D = pool.spawn(Vector3(1, 0, 2), 1.0, 5.0)
	assert_true(wave.visible, "La onda lanzada se ve")
	assert_true(wave.is_playing())
	for i: int in NoiseWavePool.SIZE:
		pool.spawn(Vector3(i, 0, 0), 1.0, 5.0)
	assert_eq(pool.waves.size(), NoiseWavePool.SIZE, "Al llenarse, reutiliza: la lista no crece")
	assert_eq(pool.get_child_count(), NoiseWavePool.SIZE)


func _visible_waves(map: HeistMap3D) -> int:
	var n: int = 0
	for wave: NoiseWave3D in map.noise_audio_presenter.waves.waves:
		if wave.visible:
			n += 1
	return n


func _create_map() -> HeistMap3D:
	var map: HeistMap3D = autofree(HeistMap3D.new())
	var hud: HUD84 = (load(HUD_SCENE_PATH) as PackedScene).instantiate() as HUD84
	var camera: Camera3D = Camera3D.new()
	var thief: ThiefController3D = autofree(ThiefController3D.new())
	var guard: GuardController3D = autofree(GuardController3D.new())
	hud.name = "HUD84"
	camera.name = "IsometricCamera3D"
	thief.name = "Thief"
	guard.name = "Guard"
	guard.position = Vector3(30.0, 0.0, 0.0)
	for node: Node in [hud, camera, thief, guard]:
		map.add_child(node)
	add_child_autofree(map)
	map.set_physics_process(false)
	thief.set_physics_process(false)
	guard.set_physics_process(false)
	return map


func test_presenter_spawns_wave_for_enemy_noise_only() -> void:
	var map: HeistMap3D = _create_map()
	var guard: GuardController3D = map.guards[0]
	map.set_local_player(guard)
	guard.global_position = Vector3.ZERO
	assert_eq(_visible_waves(map), 0)

	SignalBus.noise_event_3d.emit(Vector3(2, 0, 0), 3.5, &"thief", &"step", map.thief)
	assert_eq(_visible_waves(map), 1, "El ruido del ladrón que alcanza al guardia lanza una onda")

	for wave: NoiseWave3D in map.noise_audio_presenter.waves.waves:
		wave.hide()
	SignalBus.noise_event_3d.emit(Vector3(2, 0, 0), 3.5, &"guard", &"step", guard)
	assert_eq(_visible_waves(map), 0, "El ruido propio no lanza onda")
