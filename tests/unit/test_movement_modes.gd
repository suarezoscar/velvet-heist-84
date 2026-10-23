## @file test_movement_modes.gd
## Tests de aceptación para modos de movimiento y resolución de gait (FEAT-007).
extends GutTest

const THIEF_PROFILE_PATH: String = "res://data/balance/movement_thief.tres"
const GUARD_PROFILE_PATH: String = "res://data/balance/movement_guard.tres"
const STEP_NOISE_PATH: String = "res://data/balance/step_noise.tres"


func _create_thief() -> ThiefController3D:
	var thief: ThiefController3D = ThiefController3D.new()
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "CollisionShape3D"
	thief.add_child(col)
	add_child_autofree(thief)
	return thief


func _create_guard() -> GuardController3D:
	var guard: GuardController3D = GuardController3D.new()
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "CollisionShape3D"
	guard.add_child(col)
	add_child_autofree(guard)
	return guard


func _check_no_dominant(prof: MovementProfile, modes: Array, noise: StepNoiseProfile) -> void:
	for a: MovementProfile.Mode in modes:
		var va: float = prof.speed_for(a)
		var na: float = noise.radius_for(a, 1.0, prof.team_noise_mult)
		var ha: float = CrouchCollision.STAND_HEIGHT
		if a == MovementProfile.Mode.CROUCH:
			ha = CrouchCollision.CROUCH_HEIGHT
		for b: MovementProfile.Mode in modes:
			if a == b:
				continue
			var vb: float = prof.speed_for(b)
			var nb: float = noise.radius_for(b, 1.0, prof.team_noise_mult)
			var hb: float = CrouchCollision.STAND_HEIGHT
			if b == MovementProfile.Mode.CROUCH:
				hb = CrouchCollision.CROUCH_HEIGHT
			var not_worse: bool = va >= vb and na <= nb and ha <= hb
			var strictly_better: bool = va > vb or na < nb or ha < hb
			assert_false(not_worse and strictly_better, "Modo %d no domina a %d" % [a, b])


## Criterio 1: Modos WALK, SNEAK, SPRINT, CROUCH; prioridad CROUCH > SNEAK > SPRINT > WALK.
func test_mode_resolution_priority() -> void:
	var thief: ThiefController3D = _create_thief()
	assert_eq(thief.get_move_mode(), MovementProfile.Mode.WALK, "Por defecto es WALK")

	thief.is_sprinting = true
	assert_eq(thief.get_move_mode(), MovementProfile.Mode.SPRINT, "Sprint activo -> SPRINT")

	thief.is_sneaking = true
	assert_eq(thief.get_move_mode(), MovementProfile.Mode.SNEAK, "Sneak + sprint -> SNEAK")

	thief.is_sprinting = false
	assert_eq(thief.get_move_mode(), MovementProfile.Mode.SNEAK, "Solo sneak -> SNEAK")

	assert_true(thief.set_crouching(true), "Ladrón puede agacharse")
	assert_eq(thief.get_move_mode(), MovementProfile.Mode.CROUCH, "Agachado -> CROUCH")

	thief.is_sprinting = true
	thief.is_sneaking = true
	assert_eq(thief.get_move_mode(), MovementProfile.Mode.CROUCH, "CROUCH anula sneak y sprint")

	thief.set_crouching(false)
	assert_eq(thief.get_move_mode(), MovementProfile.Mode.SNEAK, "Al levantarse vuelve a SNEAK")


## Criterio 2: Invariante 1: sneak < walk < sprint en velocidad y multiplicador de ruido.
func test_invariant_1_gait_order() -> void:
	var thief_profile: MovementProfile = load(THIEF_PROFILE_PATH) as MovementProfile
	var guard_profile: MovementProfile = load(GUARD_PROFILE_PATH) as MovementProfile
	var step_noise: StepNoiseProfile = load(STEP_NOISE_PATH) as StepNoiseProfile

	var profiles: Array[MovementProfile] = [thief_profile, guard_profile]
	for profile: MovementProfile in profiles:
		var speed_sneak: float = profile.speed_for(MovementProfile.Mode.SNEAK)
		var speed_walk: float = profile.speed_for(MovementProfile.Mode.WALK)
		var speed_sprint: float = profile.speed_for(MovementProfile.Mode.SPRINT)
		assert_lt(speed_sneak, speed_walk, "Velocidad sneak < walk")
		assert_lt(speed_walk, speed_sprint, "Velocidad walk < sprint")

	var noise_sneak: float = step_noise.mode_mult(MovementProfile.Mode.SNEAK)
	var noise_walk: float = step_noise.mode_mult(MovementProfile.Mode.WALK)
	var noise_sprint: float = step_noise.mode_mult(MovementProfile.Mode.SPRINT)
	assert_lt(noise_sneak, noise_walk, "Ruido sneak < walk")
	assert_lt(noise_walk, noise_sprint, "Ruido walk < sprint")


## Criterio 3: Invariante 2: ningún par de modos en cada bando domina estrictamente a otro.
func test_invariant_2_no_dominant_mode() -> void:
	var thief_prof: MovementProfile = load(THIEF_PROFILE_PATH) as MovementProfile
	var guard_prof: MovementProfile = load(GUARD_PROFILE_PATH) as MovementProfile
	var step_noise: StepNoiseProfile = load(STEP_NOISE_PATH) as StepNoiseProfile

	var t_modes: Array[MovementProfile.Mode] = [
		MovementProfile.Mode.WALK,
		MovementProfile.Mode.SNEAK,
		MovementProfile.Mode.SPRINT,
		MovementProfile.Mode.CROUCH,
	]
	var g_modes: Array[MovementProfile.Mode] = [
		MovementProfile.Mode.WALK,
		MovementProfile.Mode.SNEAK,
		MovementProfile.Mode.SPRINT,
	]
	_check_no_dominant(thief_prof, t_modes, step_noise)
	_check_no_dominant(guard_prof, g_modes, step_noise)


## Criterio 6: Invariante 5: crouch_ratio < sneak_ratio, crouch_mult == sneak_mult y anula gait.
func test_invariant_5_crouch_overrides_gait() -> void:
	var thief_prof: MovementProfile = load(THIEF_PROFILE_PATH) as MovementProfile
	var guard_prof: MovementProfile = load(GUARD_PROFILE_PATH) as MovementProfile
	var step_noise: StepNoiseProfile = load(STEP_NOISE_PATH) as StepNoiseProfile

	assert_lt(thief_prof.crouch_ratio, thief_prof.sneak_ratio, "crouch_ratio < sneak_ratio")
	assert_lt(guard_prof.crouch_ratio, guard_prof.sneak_ratio, "crouch_ratio < sneak_ratio")
	assert_eq(step_noise.crouch_mult, step_noise.sneak_mult, "crouch_mult == sneak_mult")

	var thief: ThiefController3D = _create_thief()
	thief.set_physics_process(false)
	thief.set_crouching(true)
	thief.apply_input({"movement_vector": Vector2(0.0, 1.0)})
	thief.simulate_movement(1.0 / 60.0)

	var base_spd: float = thief.current_speed
	var base_rad: float = thief.compute_step_radius()
	assert_almost_eq(base_spd, thief.movement_profile.speed_for(MovementProfile.Mode.CROUCH), 0.001)
	assert_almost_eq(
		base_rad,
		step_noise.radius_for(
			MovementProfile.Mode.CROUCH,
			thief.surface_detector.get_surface_noise_multiplier(),
			thief.movement_profile.team_noise_mult
		),
		0.001
	)

	thief.apply_input({"movement_vector": Vector2(0.0, 1.0), "is_sneaking": true})
	thief.simulate_movement(1.0 / 60.0)
	assert_eq(thief.current_speed, base_spd, "Velocidad no cambia con sneak agachado")
	assert_eq(thief.compute_step_radius(), base_rad, "Radio no cambia con sneak agachado")

	thief.apply_input({"movement_vector": Vector2(0.0, 1.0), "is_sprinting": true})
	thief.simulate_movement(1.0 / 60.0)
	assert_eq(thief.current_speed, base_spd, "Velocidad no cambia con sprint agachado")
	assert_eq(thief.compute_step_radius(), base_rad, "Radio no cambia con sprint agachado")

	thief.apply_input({"movement_vector": Vector2.UP, "sneak": true, "sprint": true})
	thief.simulate_movement(1.0 / 60.0)
	assert_eq(thief.current_speed, base_spd, "Velocidad no cambia con sneak+sprint agachado")
	assert_eq(thief.compute_step_radius(), base_rad, "Radio no cambia con sneak+sprint agachado")


## Criterio 10: El guardia no puede agacharse.
func test_guard_cannot_crouch() -> void:
	var guard: GuardController3D = _create_guard()

	var ok: bool = guard.set_crouching(true)
	assert_false(ok, "guard.set_crouching(true) debe devolver false")
	assert_false(guard.is_crouching, "guard.is_crouching debe permanecer en false")

	guard.apply_input({"crouch": true})
	assert_false(guard.is_crouching, "guard.apply_input con 'crouch': true no lo agacha")

	guard.apply_input({"crouching": true})
	assert_false(guard.is_crouching, "guard.apply_input con 'crouching': true no lo agacha")


## Criterio 11: Espacio libre para levantarse; con techo a 1.3 m se bloquea y emite señal.
func test_stand_up_needs_headroom() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	var f_col := CollisionShape3D.new()
	var f_box := BoxShape3D.new()
	f_box.size = Vector3(20.0, 0.2, 20.0)
	f_col.shape = f_box
	floor_body.add_child(f_col)
	floor_body.position = Vector3(0.0, -0.1, 0.0)
	add_child_autofree(floor_body)

	var thief := _create_thief()
	thief.set_physics_process(false)
	assert_true(thief.set_crouching(true))

	var ceiling := StaticBody3D.new()
	ceiling.collision_layer = 1
	ceiling.collision_mask = 0
	var c_col := CollisionShape3D.new()
	var c_box := BoxShape3D.new()
	c_box.size = Vector3(4.0, 0.2, 4.0)
	c_col.shape = c_box
	ceiling.add_child(c_col)
	ceiling.position = Vector3(0.0, 1.3 + 0.1, 0.0)
	add_child_autofree(ceiling)

	await wait_physics_frames(2)
	watch_signals(thief)

	assert_false(thief.set_crouching(false))
	assert_true(thief.is_crouching)
	assert_signal_emit_count(thief, "stand_up_blocked", 1)
	assert_signal_not_emitted(thief, "crouch_changed")

	ceiling.position = Vector3(0.0, 100.0, 0.0)
	await wait_physics_frames(2)

	assert_true(thief.set_crouching(false))
	assert_false(thief.is_crouching)
	assert_signal_emitted_with_parameters(thief, "crouch_changed", [false])


## Criterio 12: Dimensiones de cápsula y aislamiento entre instancias de personaje.
func test_crouch_capsule_and_isolation() -> void:
	var shared := CapsuleShape3D.new()

	var thief1: ThiefController3D = ThiefController3D.new()
	var col1: CollisionShape3D = CollisionShape3D.new()
	col1.name = "CollisionShape3D"
	col1.shape = shared
	thief1.add_child(col1)

	var thief2: ThiefController3D = ThiefController3D.new()
	var col2: CollisionShape3D = CollisionShape3D.new()
	col2.name = "CollisionShape3D"
	col2.shape = shared
	thief2.add_child(col2)

	add_child_autofree(thief1)
	add_child_autofree(thief2)

	thief1.set_physics_process(false)
	thief2.set_physics_process(false)

	var cap1: CapsuleShape3D = thief1.collision_shape.shape as CapsuleShape3D
	assert_almost_eq(cap1.height, CrouchCollision.STAND_HEIGHT, 0.001, "Altura de pie")
	assert_almost_eq(cap1.radius, CrouchCollision.CAPSULE_RADIUS, 0.001, "Radio de pie")
	assert_almost_eq(col1.transform.origin.y, CrouchCollision.STAND_HEIGHT * 0.5, 0.001)

	thief1.set_crouching(true)
	assert_almost_eq(cap1.height, CrouchCollision.CROUCH_HEIGHT, 0.001, "Altura agachado")
	assert_almost_eq(cap1.radius, CrouchCollision.CAPSULE_RADIUS, 0.001, "Radio agachado")
	assert_almost_eq(col1.transform.origin.y, CrouchCollision.CROUCH_HEIGHT * 0.5, 0.001)

	assert_almost_eq(
		(thief2.collision_shape.shape as CapsuleShape3D).height,
		CrouchCollision.STAND_HEIGHT,
		0.001,
		"thief2 conserva alto"
	)
	assert_ne(
		thief1.collision_shape.shape,
		thief2.collision_shape.shape,
		"Formas de colisión independientes"
	)


## Criterio 13: Mapeo de animaciones y poses en CharacterAnimator3D.
func test_animator_mapping() -> void:
	var animator: CharacterAnimator3D = autofree(CharacterAnimator3D.new())
	var moving: float = 1.0
	var stopped: float = 0.0

	var m_walk: StringName = animator.resolve_animation_name(MovementProfile.Mode.WALK, moving)
	assert_eq(m_walk, &"walk", "WALK en movimiento -> walk")
	var m_sprint: StringName = animator.resolve_animation_name(MovementProfile.Mode.SPRINT, moving)
	assert_eq(m_sprint, &"walk", "SPRINT en movimiento -> walk")
	var m_sneak: StringName = animator.resolve_animation_name(MovementProfile.Mode.SNEAK, moving)
	assert_eq(m_sneak, &"sneak_walk", "SNEAK en movimiento -> sneak_walk")
	var m_crouch: StringName = animator.resolve_animation_name(MovementProfile.Mode.CROUCH, moving)
	assert_eq(m_crouch, &"crouch_walk", "CROUCH en movimiento -> crouch_walk")

	var s_walk: StringName = animator.resolve_animation_name(MovementProfile.Mode.WALK, stopped)
	assert_eq(s_walk, &"idle_stand", "WALK parado -> idle_stand")
	var s_sprint: StringName = animator.resolve_animation_name(MovementProfile.Mode.SPRINT, stopped)
	assert_eq(s_sprint, &"idle_stand", "SPRINT parado -> idle_stand")
	var s_sneak: StringName = animator.resolve_animation_name(MovementProfile.Mode.SNEAK, stopped)
	assert_eq(s_sneak, &"idle_stand", "SNEAK parado -> idle_stand")
	var s_crouch: StringName = animator.resolve_animation_name(MovementProfile.Mode.CROUCH, stopped)
	assert_eq(s_crouch, &"idle_crouch", "CROUCH parado -> idle_crouch")
