## @file test_step_noise.gd
## Tests de aceptación para perfiles acústicos y ruido de pasos (FEAT-007).
extends GutTest

const THIEF_PROFILE_PATH: String = "res://data/balance/movement_thief.tres"
const GUARD_PROFILE_PATH: String = "res://data/balance/movement_guard.tres"
const STEP_NOISE_PATH: String = "res://data/balance/step_noise.tres"
const CARPET_PATH: String = "res://data/balance/surface_carpet.tres"
const MARBLE_PATH: String = "res://data/balance/surface_marble.tres"
const PARQUET_PATH: String = "res://data/balance/surface_wood_parquet.tres"


func _create_thief(pos: Vector3 = Vector3.ZERO) -> ThiefController3D:
	var thief: ThiefController3D = autofree(ThiefController3D.new())
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "CollisionShape3D"
	thief.add_child(col)
	thief.position = pos
	add_child_autofree(thief)
	return thief


func _create_floor(noise_multiplier: float = 1.0) -> StaticBody3D:
	var floor_body: StaticBody3D = autofree(StaticBody3D.new())
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	floor_body.set_meta("noise_multiplier", noise_multiplier)
	var col: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(20.0, 0.2, 20.0)
	col.shape = box
	floor_body.add_child(col)
	floor_body.position = Vector3(0.0, -0.1, 0.0)
	add_child_autofree(floor_body)
	return floor_body


## Criterio 4: Invariante 3: radius_for >= min_radius > 0 para todo modo, bando y superficie.
func test_invariant_3_never_silent() -> void:
	var step_noise: StepNoiseProfile = load(STEP_NOISE_PATH) as StepNoiseProfile
	var thief_prof: MovementProfile = load(THIEF_PROFILE_PATH) as MovementProfile
	var guard_prof: MovementProfile = load(GUARD_PROFILE_PATH) as MovementProfile
	var carpet: SurfaceAcousticData = load(CARPET_PATH) as SurfaceAcousticData
	var marble: SurfaceAcousticData = load(MARBLE_PATH) as SurfaceAcousticData
	var parquet: SurfaceAcousticData = load(PARQUET_PATH) as SurfaceAcousticData

	assert_gt(step_noise.min_radius, 0.0, "min_radius > 0")

	var modes: Array[MovementProfile.Mode] = [
		MovementProfile.Mode.WALK,
		MovementProfile.Mode.SNEAK,
		MovementProfile.Mode.SPRINT,
		MovementProfile.Mode.CROUCH,
	]
	var surfaces: Array[SurfaceAcousticData] = [carpet, marble, parquet]
	var profiles: Array[MovementProfile] = [thief_prof, guard_prof]

	for prof: MovementProfile in profiles:
		for mode: MovementProfile.Mode in modes:
			for surf: SurfaceAcousticData in surfaces:
				var sm: float = surf.noise_multiplier
				var tm: float = prof.team_noise_mult
				var r: float = step_noise.radius_for(mode, sm, tm)
				assert_gte(r, step_noise.min_radius, "radius_for >= min_radius")
				assert_gt(r, 0.0, "radius_for > 0")


## Criterio 4: Personaje parado no emite noise_emitted_3d en 2 s de simulación.
func test_standing_still_emits_nothing() -> void:
	_create_floor(1.0)
	var thief: ThiefController3D = _create_thief(Vector3(0.0, 0.05, 0.0))
	await wait_physics_frames(2)

	watch_signals(SignalBus)

	for i in range(120):
		thief.simulate_movement(1.0 / 60.0)
		if i % 10 == 0:
			await wait_physics_frames(1)

	assert_signal_not_emitted(SignalBus, "noise_emitted_3d")


## Criterio 5: Invariante 4: sprint_mult > sprint_ratio en los dos perfiles.
func test_invariant_4_sprint_louder_per_metre() -> void:
	var step_noise: StepNoiseProfile = load(STEP_NOISE_PATH) as StepNoiseProfile
	var thief_prof: MovementProfile = load(THIEF_PROFILE_PATH) as MovementProfile
	var guard_prof: MovementProfile = load(GUARD_PROFILE_PATH) as MovementProfile

	assert_gt(step_noise.sprint_mult, thief_prof.sprint_ratio, "sprint_mult > sprint_ratio")
	assert_gt(step_noise.sprint_mult, guard_prof.sprint_ratio, "sprint_mult > sprint_ratio")


## Criterio 7: Invariante 6: radio del guardia >= ladrón y team_noise_mult >= 1.
func test_invariant_6_guard_boots() -> void:
	var step_noise: StepNoiseProfile = load(STEP_NOISE_PATH) as StepNoiseProfile
	var thief_prof: MovementProfile = load(THIEF_PROFILE_PATH) as MovementProfile
	var guard_prof: MovementProfile = load(GUARD_PROFILE_PATH) as MovementProfile
	var carpet: SurfaceAcousticData = load(CARPET_PATH) as SurfaceAcousticData
	var marble: SurfaceAcousticData = load(MARBLE_PATH) as SurfaceAcousticData
	var parquet: SurfaceAcousticData = load(PARQUET_PATH) as SurfaceAcousticData

	assert_gte(guard_prof.team_noise_mult, 1.0, "team_noise_mult del guardia >= 1")
	assert_gte(guard_prof.team_noise_mult, thief_prof.team_noise_mult, "guardia >= ladron")

	var modes: Array[MovementProfile.Mode] = [
		MovementProfile.Mode.WALK,
		MovementProfile.Mode.SNEAK,
		MovementProfile.Mode.SPRINT,
	]
	var surfaces: Array[SurfaceAcousticData] = [carpet, marble, parquet]

	for mode: MovementProfile.Mode in modes:
		for surf: SurfaceAcousticData in surfaces:
			var sm: float = surf.noise_multiplier
			var rg: float = step_noise.radius_for(mode, sm, guard_prof.team_noise_mult)
			var rt: float = step_noise.radius_for(mode, sm, thief_prof.team_noise_mult)
			assert_gte(rg, rt, "Radio guardia >= ladron en %s" % surf.surface_id)


## Criterio 8: Invariante 10: alfombra < 1 <= mármol <= parqué.
func test_invariant_10_surface_order() -> void:
	var carpet: SurfaceAcousticData = load(CARPET_PATH) as SurfaceAcousticData
	var marble: SurfaceAcousticData = load(MARBLE_PATH) as SurfaceAcousticData
	var parquet: SurfaceAcousticData = load(PARQUET_PATH) as SurfaceAcousticData

	assert_lt(carpet.noise_multiplier, 1.0, "alfombra < 1")
	assert_lte(1.0, marble.noise_multiplier, "1 <= marmol")
	assert_lte(marble.noise_multiplier, parquet.noise_multiplier, "marmol <= parque")


## Criterio 9: Un paso real emite el radio de radius_for con la superficie de ese suelo.
func test_real_step_on_each_surface() -> void:
	var step_noise: StepNoiseProfile = load(STEP_NOISE_PATH) as StepNoiseProfile
	var floor_body: StaticBody3D = _create_floor(1.0)
	var thief: ThiefController3D = _create_thief(Vector3(0.0, 0.05, 0.0))
	await wait_physics_frames(2)

	var surfaces: Array[SurfaceAcousticData] = [
		load(CARPET_PATH) as SurfaceAcousticData,
		load(MARBLE_PATH) as SurfaceAcousticData,
		load(PARQUET_PATH) as SurfaceAcousticData,
	]

	for surf: SurfaceAcousticData in surfaces:
		floor_body.set_meta("noise_multiplier", surf.noise_multiplier)
		await wait_physics_frames(2)

		thief.apply_input({"movement_vector": Vector2(0.0, 1.0)})
		var rec: Array[float] = [-1.0]
		var on_noise: Callable = func(_pos: Vector3, radius: float, _team: StringName) -> void:
			rec[0] = radius

		SignalBus.noise_emitted_3d.connect(on_noise)

		for tick: int in range(60):
			thief.simulate_movement(1.0 / 60.0)
			if tick % 10 == 0:
				await wait_physics_frames(1)
			if rec[0] >= 0.0:
				break

		SignalBus.noise_emitted_3d.disconnect(on_noise)

		var t_mode: MovementProfile.Mode = thief.get_move_mode()
		var t_noise: float = thief.movement_profile.team_noise_mult
		var exp_rad: float = step_noise.radius_for(t_mode, surf.noise_multiplier, t_noise)
		assert_gt(rec[0], 0.0, "Paso emitido en %s" % surf.surface_id)
		assert_almost_eq(rec[0], exp_rad, 0.001, "Radio coincide en %s" % surf.surface_id)
