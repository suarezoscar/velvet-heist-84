## @file test_light_perception.gd
## Tests de aceptación para linterna Maglite y reglas de percepción (FEAT-011), parte 1:
## invariantes del cono, agachado y encendido de la linterna. La luz de lámparas, el ruido de la
## porra y el encaro están en test_light_perception_2.gd.
extends GutTest

const PROFILE_PATH: String = "res://data/balance/perception_guard.tres"
const GUARD_SCENE_PATH: String = "res://scenes/entities/guard_player.tscn"
const THIEF_SCENE_PATH: String = "res://scenes/entities/thief_player.tscn"


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
