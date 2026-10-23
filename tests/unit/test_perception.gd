## @file test_perception.gd
## Tests de aceptación para la percepción cercana, porra y anillos (FEAT-008).
extends GutTest

const PROFILE_PATH: String = "res://data/balance/perception_guard.tres"


func _create_guard(pos: Vector3 = Vector3.ZERO) -> GuardController3D:
	var guard: GuardController3D = autofree(GuardController3D.new())
	guard.position = pos
	guard.set_physics_process(false)
	var maglite: SpotLight3D = SpotLight3D.new()
	maglite.name = "Maglite"
	maglite.spot_range = 10.0
	maglite.spot_angle = 35.0
	maglite.visible = false
	guard.add_child(maglite)
	guard.maglite_light = maglite
	add_child_autofree(guard)
	if guard.perception != null:
		maglite.position = Vector3(0.0, guard.perception.eye_height, 0.0)
	return guard


func _create_thief(pos: Vector3 = Vector3.ZERO) -> ThiefController3D:
	var thief: ThiefController3D = autofree(ThiefController3D.new())
	thief.position = pos
	thief.set_physics_process(false)
	add_child_autofree(thief)
	return thief


func _create_obstacle(pos: Vector3, size: Vector3) -> StaticBody3D:
	var wall: StaticBody3D = autofree(StaticBody3D.new())
	wall.collision_layer = 1
	wall.collision_mask = 0
	var col: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	col.shape = box
	wall.add_child(col)
	wall.position = pos
	add_child_autofree(wall)
	return wall


func _count_sound_waves(parent: Node) -> int:
	var count: int = 0
	for child: Node in parent.get_children():
		if child is SoundWave3D:
			count += 1
	return count


func after_each() -> void:
	GameManager.current_state = GameManager.MatchState.LOBBY


## Criterio 1: perception_guard.tres cumple invariantes 7, 8 y 9
func test_profile_invariants() -> void:
	var profile: PerceptionProfile = load(PROFILE_PATH) as PerceptionProfile
	assert_not_null(profile, "El perfil de percepción debe cargarse")
	assert_lt(
		profile.melee_range,
		profile.proximity_radius,
		"Invariante 7: melee_range < proximity_radius"
	)
	assert_gt(profile.rear_blind_arc_deg, 0.0, "Invariante 8: rear_blind_arc_deg > 0")
	for cp: float in profile.crouch_points:
		assert_lt(cp, 1.0, "Invariante 9: punto agachado < 1.0m")
	var max_stand: float = -INF
	for sp: float in profile.stand_points:
		max_stand = maxf(max_stand, sp)
	assert_gt(max_stand, 1.0, "Invariante 9: mayor punto de pie > 1.0m")


## Criterio 2: Invariante 12: proximidad horizontal en Y=0 a +-0.01m
func test_proximity_horizontal_edge() -> void:
	var guard: GuardController3D = _create_guard()
	var profile: PerceptionProfile = guard.perception
	var thief: ThiefController3D = _create_thief(
		Vector3(0.0, 0.0, -(profile.proximity_radius - 0.01))
	)
	await wait_physics_frames(2)
	assert_true(guard.check_detection_on_thief(thief), "Detectado a proximity_radius - 0.01m")

	thief.position = Vector3(0.0, 0.0, -(profile.proximity_radius + 0.01))
	await wait_physics_frames(1)
	assert_false(guard.check_detection_on_thief(thief), "No detectado a proximity_radius + 0.01m")


## Criterio 3: La altura no cuenta en la distancia horizontal de proximidad
func test_proximity_ignores_height() -> void:
	var guard: GuardController3D = _create_guard()
	var profile: PerceptionProfile = guard.perception
	var thief: ThiefController3D = _create_thief(
		Vector3(0.0, 0.8, -(profile.proximity_radius - 0.01))
	)
	await wait_physics_frames(2)
	assert_true(guard.check_detection_on_thief(thief), "Detectado con 0.8m de altura")


## Criterio 4: Arco ciego trasero a 1.0m (180 deg y bordes)
func test_rear_blind_arc() -> void:
	var guard: GuardController3D = _create_guard()
	var profile: PerceptionProfile = guard.perception
	var half_arc: float = profile.rear_blind_arc_deg * 0.5
	var angle_vis: float = 180.0 - half_arc - 1.0
	var angle_blind: float = 180.0 - half_arc + 1.0

	var thief: ThiefController3D = _create_thief(Vector3(0.0, 0.0, 1.0))
	await wait_physics_frames(2)
	assert_false(
		guard.check_detection_on_thief(thief), "No detectado directamente detrás (180 deg)"
	)

	var dir_vis: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(angle_vis))
	thief.position = dir_vis * 1.0
	await wait_physics_frames(1)
	assert_true(guard.check_detection_on_thief(thief), "Detectado en borde visible del arco")

	var dir_blind: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(angle_blind))
	thief.position = dir_blind * 1.0
	await wait_physics_frames(1)
	assert_false(guard.check_detection_on_thief(thief), "No detectado en borde ciego del arco")


## Criterio 5: Cobertura baja de 1.0m oculta al ladrón agachado pero no de pie
func test_low_cover_hides_crouched_only() -> void:
	var cover_z: float = -1.0
	var cover_depth: float = 0.2
	var guard: GuardController3D = _create_guard()
	var thief: ThiefController3D = _create_thief(Vector3(0.0, 0.0, cover_z - cover_depth))
	_create_obstacle(Vector3(0.0, 0.5, cover_z), Vector3(2.0, 1.0, cover_depth))
	await wait_physics_frames(2)
	assert_true(guard.check_detection_on_thief(thief), "De pie se detecta sobre cobertura baja")

	thief.is_crouching = true
	await wait_physics_frames(1)
	assert_false(
		guard.check_detection_on_thief(thief), "Agachado tras cobertura baja no se detecta"
	)


## Criterio 6: Muro de 3m bloquea la detección por proximidad
func test_full_wall_blocks_proximity() -> void:
	var guard: GuardController3D = _create_guard()
	var profile: PerceptionProfile = guard.perception
	var thief_z: float = -(profile.proximity_radius * 0.5)
	var thief: ThiefController3D = _create_thief(Vector3(0.0, 0.0, thief_z))
	_create_obstacle(Vector3(0.0, 3.0 * 0.5, thief_z * 0.5), Vector3(2.0, 3.0, 0.2))
	await wait_physics_frames(2)
	assert_false(guard.check_detection_on_thief(thief), "Muro de 3m bloquea la proximidad")


## Criterio 7: Linterna usa puntos de visibilidad: detecta de pie y no agachado tras cobertura
func test_cone_uses_visibility_points() -> void:
	var guard: GuardController3D = _create_guard()
	var thief: ThiefController3D = _create_thief(Vector3(0.0, 0.0, -5.0))
	_create_obstacle(Vector3(0.0, 0.5, -4.8), Vector3(2.0, 1.0, 0.2))

	guard.maglite_light.visible = true
	guard.look_target_position = Vector3(0.0, guard.perception.eye_height, -5.0)
	guard.update_presentation(0.0)

	await wait_physics_frames(2)
	assert_true(
		guard.check_detection_on_thief(thief), "Linterna detecta de pie sobre cobertura baja"
	)

	thief.is_crouching = true
	await wait_physics_frames(1)
	assert_false(
		guard.check_detection_on_thief(thief), "Linterna no detecta agachado tras cobertura baja"
	)


## Criterio 8: Validación autoritativa de golpe de porra (alcance horizontal, altura y muro)
func test_melee_range_edge() -> void:
	var guard: GuardController3D = _create_guard()
	var profile: PerceptionProfile = guard.perception
	var hit_z: float = -(profile.melee_range - 0.01)
	var thief: ThiefController3D = _create_thief(Vector3(0.0, 0.0, hit_z))
	await wait_physics_frames(2)
	assert_true(guard.validate_melee_hit(thief), "Porra acierta a melee_range - 0.01m")

	thief.position = Vector3(0.0, 0.0, -(profile.melee_range + 0.01))
	await wait_physics_frames(1)
	assert_false(guard.validate_melee_hit(thief), "Porra falla a melee_range + 0.01m")

	thief.position = Vector3(0.0, 0.5, hit_z)
	await wait_physics_frames(1)
	assert_true(guard.validate_melee_hit(thief), "Porra acierta con 0.5m de desnivel")

	thief.position = Vector3(0.0, 0.0, hit_z)
	_create_obstacle(Vector3(0.0, 3.0 * 0.5, hit_z * 0.5), Vector3(2.0, 3.0, 0.2))
	await wait_physics_frames(2)
	assert_false(guard.validate_melee_hit(thief), "Porra bloqueada por muro intermedio")


## Criterio 9: Invariante 11: IA oye exactamente hasta el radio del anillo emitido
func test_ai_hears_exactly_the_ring() -> void:
	var guard: GuardController3D = _create_guard()
	var ai: GuardAI3D = GuardAI3D.new()
	guard.add_child(ai)

	var ring_radius: float = 4.0
	SignalBus.noise_emitted_3d.emit(Vector3(0.0, 0.5, -(ring_radius + 0.01)), ring_radius, &"thief")
	assert_eq(
		ai.current_state, GuardAI3D.AIState.PATROL, "Ruido a R + 0.01m no altera estado de patrulla"
	)

	SignalBus.noise_emitted_3d.emit(Vector3(0.0, 0.5, -(ring_radius - 0.01)), ring_radius, &"thief")
	assert_eq(
		ai.current_state,
		GuardAI3D.AIState.INVESTIGATE,
		"Ruido a R - 0.01m cambia estado a INVESTIGATE"
	)


## Criterio 10: Invariante 11: visibilidad del anillo según rol y distancia horizontal
func test_ring_visibility_rule() -> void:
	var guard: GuardController3D = _create_guard()
	var thief: ThiefController3D = _create_thief(Vector3(0.0, 0.0, 10.0))
	var ring_radius: float = 4.0

	assert_true(
		PerceptionRules.ring_visible_to(
			guard, Vector3(0.0, 0.0, -(ring_radius - 0.01)), ring_radius
		),
		"Guardia a R - 0.01m ve el anillo"
	)
	assert_false(
		PerceptionRules.ring_visible_to(
			guard, Vector3(0.0, 0.0, -(ring_radius + 0.01)), ring_radius
		),
		"Guardia a R + 0.01m no ve el anillo"
	)
	assert_true(
		PerceptionRules.ring_visible_to(thief, Vector3(0.0, 0.0, 100.0), ring_radius),
		"Ladrón ve el anillo a cualquier distancia"
	)
	assert_true(
		PerceptionRules.ring_visible_to(null, Vector3(0.0, 0.0, 100.0), ring_radius),
		"Espectador null siempre ve el anillo"
	)


## Criterio 11: HeistMap3D crea SoundWave3D solo si el ruido alcanza al guardia local
func test_map_filters_rings_for_local_guard() -> void:
	var map: HeistMap3D = autofree(HeistMap3D.new())
	map.set_physics_process(false)
	add_child_autofree(map)

	var guard: GuardController3D = autofree(GuardController3D.new())
	guard.position = Vector3.ZERO
	guard.set_physics_process(false)
	map.add_child(guard)
	map.set_local_player(guard)

	var ring_radius: float = 4.0
	SignalBus.noise_emitted_3d.emit(Vector3(0.0, 0.0, -(ring_radius + 1.0)), ring_radius, &"thief")
	assert_eq(_count_sound_waves(map), 0, "No crea SoundWave3D si está fuera de alcance")

	SignalBus.noise_emitted_3d.emit(Vector3(0.0, 0.0, -(ring_radius - 1.0)), ring_radius, &"thief")
	assert_eq(_count_sound_waves(map), 1, "Crea SoundWave3D si está dentro de alcance")
