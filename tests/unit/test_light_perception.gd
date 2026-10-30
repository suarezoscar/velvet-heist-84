## @file test_light_perception.gd
## Tests de aceptación para linterna Maglite, detección por luz y reglas de percepción (FEAT-011).
extends GutTest

const PROFILE_PATH: String = "res://data/balance/perception_guard.tres"
const LAMP_CEILING_PATH: String = "res://data/balance/lamp_ceiling.tres"
const GUARD_SCENE_PATH: String = "res://scenes/entities/guard_player.tscn"
const THIEF_SCENE_PATH: String = "res://scenes/entities/thief_player.tscn"
const LAMP_SCENE_PATH: String = "res://scenes/entities/lamp.tscn"


func _create_guard(pos: Vector3 = Vector3.ZERO) -> GuardController3D:
	var scene: PackedScene = load(GUARD_SCENE_PATH) as PackedScene
	var guard: GuardController3D = autofree(scene.instantiate() as GuardController3D)
	guard.position = pos
	add_child_autofree(guard)
	guard.apply_flashlight_state(true)  # un guardia humano empieza apagado (#112)
	guard.set_physics_process(false)
	return guard


func _create_thief(pos: Vector3 = Vector3.ZERO) -> ThiefController3D:
	var scene: PackedScene = load(THIEF_SCENE_PATH) as PackedScene
	var thief: ThiefController3D = autofree(scene.instantiate() as ThiefController3D)
	thief.position = pos
	add_child_autofree(thief)
	thief.set_physics_process(false)
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


func _create_lamp(pos: Vector3, profile: LampProfile, start_on: bool = true) -> Lamp3D:
	var scene: PackedScene = load(LAMP_SCENE_PATH) as PackedScene
	var lamp: Lamp3D = autofree(scene.instantiate() as Lamp3D)
	lamp.profile = profile
	lamp.start_on = start_on
	lamp.position = pos
	add_child_autofree(lamp)
	lamp.set_physics_process(false)
	return lamp


func after_each() -> void:
	GameManager.current_state = GameManager.MatchState.LOBBY


## Criterio 1: Invariante 13: flashlight_range > proximity_radius y medio ángulo <= campo frontal
func test_inv13_cone_in_front_field() -> void:
	var profile: PerceptionProfile = load(PROFILE_PATH) as PerceptionProfile
	assert_not_null(profile, "perception_guard.tres debe cargarse")
	assert_gt(profile.flashlight_range, profile.proximity_radius, "Inv 13: range > proximity")
	assert_lte(profile.flashlight_half_angle_deg, (360.0 - profile.rear_blind_arc_deg) / 2.0)


## Criterio 2: Invariante 14: SpotLight3D tiene spot_range, spot_angle y altura de perception_guard
func test_inv14_beam_is_truth() -> void:
	var guard: GuardController3D = _create_guard(Vector3.ZERO)
	var profile: PerceptionProfile = guard.perception
	assert_not_null(guard.maglite_light, "Guardia debe tener maglite_light asignado")
	assert_almost_eq(guard.maglite_light.spot_range, profile.flashlight_range, 0.01)
	assert_almost_eq(guard.maglite_light.spot_angle, profile.flashlight_half_angle_deg, 0.01)
	assert_almost_eq(guard.maglite_light.position.y, profile.flashlight_height, 0.01)


## Criterio 3: Invariante 15: bordes de distancia y ángulo del cono horizontal de la linterna
func test_inv15_cone_edges() -> void:
	var guard: GuardController3D = _create_guard(Vector3.ZERO)
	var profile: PerceptionProfile = guard.perception
	guard.look_target_position = Vector3(0.0, profile.flashlight_height, -10.0)

	var d_in: float = profile.flashlight_range - 0.01
	var thief: ThiefController3D = _create_thief(Vector3(0.0, 0.0, -d_in))
	await wait_physics_frames(2)
	assert_true(guard.check_detection_on_thief(thief), "Detectado a range - 0.01m")

	thief.position = Vector3(0.0, 0.0, -(profile.flashlight_range + 0.01))
	await wait_physics_frames(2)
	assert_false(guard.check_detection_on_thief(thief), "No detectado a range + 0.01m")
	assert_true(
		PerceptionRules.is_in_flashlight_cone(
			Vector3.ZERO,
			Vector3.FORWARD,
			Vector3(0.0, 0.0, -profile.flashlight_range),
			profile.flashlight_range,
			profile.flashlight_half_angle_deg
		)
	)

	var d_mid: float = (profile.flashlight_range + profile.proximity_radius) * 0.5
	var angle_in_rad: float = deg_to_rad(profile.flashlight_half_angle_deg - 0.5)
	thief.position = Vector3(d_mid * sin(angle_in_rad), 0.0, -d_mid * cos(angle_in_rad))
	await wait_physics_frames(2)
	assert_true(guard.check_detection_on_thief(thief), "Detectado a angle - 0.5 deg")

	var angle_out_rad: float = deg_to_rad(profile.flashlight_half_angle_deg + 0.5)
	thief.position = Vector3(d_mid * sin(angle_out_rad), 0.0, -d_mid * cos(angle_out_rad))
	await wait_physics_frames(2)
	assert_false(guard.check_detection_on_thief(thief), "No detectado a angle + 0.5 deg")

	# El cono de detección es horizontal y no el cono 3D de SpotLight3D inclinado al suelo
	thief.position = Vector3(0.0, 0.0, -d_in)
	guard.maglite_light.rotation_degrees = Vector3(-70.0, 0.0, 0.0)
	assert_lt((-guard.maglite_light.global_transform.basis.z).y, -0.5, "foco inclinado")
	await wait_physics_frames(2)
	assert_true(guard.check_detection_on_thief(thief), "Detecta con foco inclinado a suelo")


## Criterio 4: Invariante 16: cobertura de 1.0m oculta al ladrón agachado a 3m; de pie es detectado
func test_inv16_crouch_hides_from_flashlight() -> void:
	var guard: GuardController3D = _create_guard(Vector3.ZERO)
	guard.look_target_position = Vector3(0.0, guard.perception.flashlight_height, -10.0)

	var thief: ThiefController3D = _create_thief(Vector3(0.0, 0.0, -3.0))
	_create_obstacle(Vector3(0.0, 0.5, -2.55), Vector3(2.0, 1.0, 0.1))

	thief.is_crouching = true
	await wait_physics_frames(2)
	assert_false(guard.check_detection_on_thief(thief), "Agachado tras 1.0m no detectado")

	thief.is_crouching = false
	await wait_physics_frames(2)
	assert_true(guard.check_detection_on_thief(thief), "De pie tras 1.0m sí detectado")


## Origen del cono a la altura de la linterna (1.4m) y no de los ojos (1.5m)
func test_cone_origin_is_flashlight_height() -> void:
	var guard: GuardController3D = _create_guard(Vector3.ZERO)
	var thief: ThiefController3D = _create_thief(Vector3(0.0, 0.0, -8.0))
	_create_obstacle(Vector3(0.0, 1.5, -0.5), Vector3(2.0, 0.12, 0.1))

	await wait_physics_frames(2)
	assert_true(guard.check_detection_on_thief(thief))


## Criterio 5: linterna apagada oculta SpotLight3D y no detecta; emite ruido al cambiar
func test_flashlight_toggle() -> void:
	var guard: GuardController3D = _create_guard(Vector3.ZERO)
	var profile: PerceptionProfile = guard.perception
	guard.look_target_position = Vector3(0.0, profile.flashlight_height, -10.0)

	var thief: ThiefController3D = _create_thief(Vector3(0.0, 0.0, -4.0))
	var noises: Array[Dictionary] = []
	var on_noise: Callable = func(pos: Vector3, radius: float, team: StringName) -> void:
		noises.append({"pos": pos, "radius": radius, "team": team})
	SignalBus.noise_emitted_3d.connect(on_noise)

	await wait_physics_frames(2)
	assert_true(guard.check_detection_on_thief(thief), "Detectado con linterna encendida")
	assert_true(guard.maglite_light.visible, "SpotLight3D visible encendida")

	guard.set_flashlight(false)
	assert_false(guard.flashlight_on, "flashlight_on debe ser false")
	assert_false(guard.maglite_light.visible, "SpotLight3D oculta apagada")
	assert_false(noises.is_empty(), "set_flashlight emite ruido")
	var off_noise: Dictionary = noises.back()
	assert_almost_eq(off_noise.get("radius", 0.0), profile.flashlight_toggle_noise_radius, 0.01)
	assert_eq(off_noise.get("team"), &"guard", "Equipo guard en ruido")

	await wait_physics_frames(2)
	assert_false(guard.check_detection_on_thief(thief), "Linterna apagada no detecta en cono")

	noises.clear()
	guard.set_flashlight(true)
	assert_true(guard.flashlight_on, "flashlight_on debe ser true tras reencender")
	assert_true(guard.maglite_light.visible, "SpotLight3D visible tras reencender")
	assert_false(noises.is_empty(), "set_flashlight(true) emite ruido")
	var on_noise_dict: Dictionary = noises.back()
	assert_almost_eq(on_noise_dict.get("radius", 0.0), profile.flashlight_toggle_noise_radius, 0.01)

	await wait_physics_frames(2)
	assert_true(guard.check_detection_on_thief(thief), "Detectado tras encender linterna")

	SignalBus.noise_emitted_3d.disconnect(on_noise)


## Criterio 6: Invariante 17: lámpara encendida detecta sin linterna hasta lit_sight_range
func test_inv17_light_detects() -> void:
	var guard: GuardController3D = _create_guard(Vector3.ZERO)
	var profile: PerceptionProfile = guard.perception
	guard.rotation = Vector3.ZERO
	guard.look_target_position = Vector3(0.0, profile.flashlight_height, -10.0)
	guard.set_flashlight(false)

	var d: float = profile.lit_sight_range - 0.01
	var thief: ThiefController3D = _create_thief(Vector3(0.0, 0.0, -d))

	await wait_physics_frames(2)
	assert_false(guard.check_detection_on_thief(thief), "Sin lámpara no detecta")

	var lamp_prof: LampProfile = load(LAMP_CEILING_PATH) as LampProfile
	var lamp: Lamp3D = _create_lamp(Vector3(0.0, 2.5, -d), lamp_prof, true)

	await wait_physics_frames(2)
	assert_true(guard.check_detection_on_thief(thief), "Lámpara encendida detecta a d")

	lamp.set_switched(false)
	await wait_physics_frames(2)
	assert_false(guard.check_detection_on_thief(thief), "Lámpara apagada no detecta")


## Luz respeta el arco ciego trasero del guardia
func test_light_respects_blind_arc() -> void:
	var guard: GuardController3D = _create_guard(Vector3.ZERO)
	guard.set_flashlight(false)

	var thief: ThiefController3D = _create_thief(Vector3(0.0, 0.0, 3.0))
	var lamp_prof: LampProfile = load(LAMP_CEILING_PATH) as LampProfile
	_create_lamp(Vector3(0.0, 2.5, 3.0), lamp_prof, true)

	await wait_physics_frames(2)
	assert_false(guard.check_detection_on_thief(thief))


## Criterio 7: Invariante 18: un punto dentro de lit_radius con rayo bloqueado no está iluminado
func test_inv18_furniture_casts_shadow() -> void:
	var lamp_prof: LampProfile = load(LAMP_CEILING_PATH) as LampProfile
	var lamp: Lamp3D = _create_lamp(Vector3(0.0, 2.5, 0.0), lamp_prof, true)
	var test_point: Vector3 = Vector3(0.0, 0.5, 2.0)

	var space_state: PhysicsDirectSpaceState3D = lamp.get_world_3d().direct_space_state
	await wait_physics_frames(2)
	assert_true(
		LightingRules.is_point_lit(space_state, test_point, [lamp]),
		"Punto en línea directa de visión está iluminado"
	)

	var wall: StaticBody3D = _create_obstacle(Vector3(0.0, 1.5, 1.0), Vector3(2.0, 2.0, 0.2))
	await wait_physics_frames(2)
	assert_false(
		LightingRules.is_point_lit(space_state, test_point, [lamp]),
		"Punto tras mueble sólido queda en sombra"
	)


## Criterio 14: O4: porra y captura emiten radios leídos de perception_guard.tres
func test_o4_noises_from_tres() -> void:
	var guard: GuardController3D = _create_guard(Vector3.ZERO)
	var p: PerceptionProfile = guard.perception.duplicate() as PerceptionProfile
	p.baton_swing_noise_radius += 1.0
	p.capture_noise_radius += 1.0
	guard.perception = p

	var noises: Array[Dictionary] = []
	var on_noise: Callable = func(pos: Vector3, radius: float, team: StringName) -> void:
		noises.append({"pos": pos, "radius": radius, "team": team})
	SignalBus.noise_emitted_3d.connect(on_noise)

	guard.swing_baton(null)
	assert_false(noises.is_empty(), "swing_baton debe emitir ruido")
	var baton_noise: Dictionary = noises.back()
	assert_almost_eq(baton_noise.get("radius", 0.0), p.baton_swing_noise_radius, 0.01)

	guard.call("_capture_thief")
	var capture_noise: Dictionary = noises.back()
	assert_almost_eq(capture_noise.get("radius", 0.0), p.capture_noise_radius, 0.01)

	SignalBus.noise_emitted_3d.disconnect(on_noise)

	var script: GDScript = load("res://src/entities/guard/guard_controller_3d.gd") as GDScript
	var source: String = script.source_code
	assert_false(source.contains("BATON_SWING_NOISE_RADIUS"), "Sin const BATON_SWING_NOISE_RADIUS")
	assert_false(source.contains("CAPTURE_NOISE_RADIUS"), "Sin const CAPTURE_NOISE_RADIUS")


## Criterio 15: ambos miran hacia look_target_position (hacia donde andan o adonde apuntan, #112)
func test_guard_faces_aim() -> void:
	var guard: GuardController3D = _create_guard(Vector3.ZERO)
	guard.look_target_position = Vector3(0.0, 1.4, -5.0)
	guard.velocity = Vector3(5.0, 0.0, 0.0)
	guard.rotation.y = deg_to_rad(90.0)

	for _i: int in range(25):
		guard.update_presentation(0.1)

	var guard_fwd: Vector3 = -guard.global_transform.basis.z
	assert_gt(guard_fwd.dot(Vector3(0.0, 0.0, -1.0)), 0.8, "Guardia mira a look_target (-Z)")

	var thief: ThiefController3D = _create_thief(Vector3.ZERO)
	thief.look_target_position = Vector3(0.0, 1.4, -5.0)
	thief.velocity = Vector3(5.0, 0.0, 0.0)

	for _i: int in range(25):
		thief.update_presentation(0.1)

	var thief_fwd: Vector3 = -thief.global_transform.basis.z
	assert_gt(thief_fwd.dot(Vector3(0.0, 0.0, -1.0)), 0.8, "Ladrón mira a look_target (-Z)")
