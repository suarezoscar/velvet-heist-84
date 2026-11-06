## @file test_light_perception_2.gd
## Tests de aceptación para detección por luz y reglas de percepción (FEAT-011), parte 2:
## lámparas, sombras, ruido de la porra y orientación. El resto está en test_light_perception.gd.
extends GutTest

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
