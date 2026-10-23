## @file test_lamps.gd
## Tests de aceptación para lámparas, interruptores y bombillas (FEAT-011).
extends GutTest

const LIGHT_RULES_PATH: String = "res://data/balance/light_rules.tres"
const PERCEPTION_PATH: String = "res://data/balance/perception_guard.tres"
const STEP_NOISE_PATH: String = "res://data/balance/step_noise.tres"
const LAMP_CEILING_PATH: String = "res://data/balance/lamp_ceiling.tres"
const LAMP_DESK_PATH: String = "res://data/balance/lamp_desk.tres"
const SWITCH_SCENE_PATH: String = "res://scenes/entities/light_switch.tscn"
const LAMP_SCENE_PATH: String = "res://scenes/entities/lamp.tscn"
const GUARD_SCENE_PATH: String = "res://scenes/entities/guard_player.tscn"
const THIEF_SCENE_PATH: String = "res://scenes/entities/thief_player.tscn"


func _create_switch(circuit: int, pos: Vector3 = Vector3.ZERO) -> LightSwitch3D:
	var scene: PackedScene = load(SWITCH_SCENE_PATH) as PackedScene
	var sw: LightSwitch3D = autofree(scene.instantiate() as LightSwitch3D)
	sw.circuit_id = circuit
	sw.position = pos
	sw.set_physics_process(false)
	add_child_autofree(sw)
	return sw


func _create_lamp(circuit: int, profile_path: String, pos: Vector3 = Vector3.ZERO) -> Lamp3D:
	var scene: PackedScene = load(LAMP_SCENE_PATH) as PackedScene
	var lamp: Lamp3D = autofree(scene.instantiate() as Lamp3D)
	lamp.circuit_id = circuit
	lamp.profile = load(profile_path) as LampProfile
	lamp.position = pos
	lamp.set_physics_process(false)
	add_child_autofree(lamp)
	return lamp


func _create_thief(pos: Vector3 = Vector3.ZERO) -> ThiefController3D:
	var scene: PackedScene = load(THIEF_SCENE_PATH) as PackedScene
	var thief: ThiefController3D = autofree(scene.instantiate() as ThiefController3D)
	thief.position = pos
	thief.set_physics_process(false)
	add_child_autofree(thief)
	return thief


func _create_guard(pos: Vector3 = Vector3.ZERO) -> GuardController3D:
	var scene: PackedScene = load(GUARD_SCENE_PATH) as PackedScene
	var guard: GuardController3D = autofree(scene.instantiate() as GuardController3D)
	guard.position = pos
	guard.set_physics_process(false)
	add_child_autofree(guard)
	return guard


func after_each() -> void:
	GameManager.current_state = GameManager.MatchState.LOBBY


## Criterio 8: Invariantes 19 y 20: relaciones de luz y ruidos leídas de los .tres
func test_inv19_inv20_light_rules() -> void:
	var perception: PerceptionProfile = load(PERCEPTION_PATH) as PerceptionProfile
	var step_noise: StepNoiseProfile = load(STEP_NOISE_PATH) as StepNoiseProfile
	var rules: LightRulesProfile = load(LIGHT_RULES_PATH) as LightRulesProfile

	assert_not_null(perception, "perception_guard.tres debe cargarse")
	assert_not_null(step_noise, "step_noise.tres debe cargarse")
	assert_not_null(rules, "light_rules.tres debe cargarse")

	# Invariante 19: la luz ve más que la linterna
	assert_gte(
		perception.lit_sight_range,
		perception.flashlight_range,
		"Invariante 19: lit_sight_range >= flashlight_range"
	)

	# Invariante 20: apagar deja rastro y ninguna vía domina
	assert_gte(
		perception.flashlight_toggle_noise_radius,
		step_noise.min_radius,
		"Invariante 20: flashlight_toggle_noise_radius >= min_radius"
	)
	assert_gte(
		rules.switch_noise_radius,
		step_noise.min_radius,
		"Invariante 20: switch_noise_radius >= min_radius"
	)
	assert_gte(
		rules.unscrew_noise_radius,
		step_noise.min_radius,
		"Invariante 20: unscrew_noise_radius >= min_radius"
	)
	assert_gt(rules.unscrew_time, rules.switch_time, "Invariante 20: unscrew_time > switch_time")
	assert_lte(
		rules.unscrew_noise_radius,
		rules.switch_noise_radius,
		"Invariante 20: unscrew_noise_radius <= switch_noise_radius"
	)
	assert_gte(
		rules.rescrew_time, rules.unscrew_time, "Invariante 20: rescrew_time >= unscrew_time"
	)


## Criterio 9: interruptor alterna circuito tras switch_time con foco; emite ruido
func test_switch_toggles_circuit() -> void:
	var sw: LightSwitch3D = _create_switch(1, Vector3.ZERO)
	var lamp_a: Lamp3D = _create_lamp(1, LAMP_CEILING_PATH, Vector3(2.0, 2.5, 0.0))
	var lamp_b: Lamp3D = _create_lamp(1, LAMP_CEILING_PATH, Vector3(-2.0, 2.5, 0.0))
	var lamp_other: Lamp3D = _create_lamp(2, LAMP_CEILING_PATH, Vector3(0.0, 2.5, 5.0))
	var thief: ThiefController3D = _create_thief(Vector3.ZERO)

	var noises: Array[Dictionary] = []
	var on_noise: Callable = func(pos: Vector3, radius: float, team: StringName) -> void:
		noises.append({"pos": pos, "radius": radius, "team": team})
	SignalBus.noise_emitted_3d.connect(on_noise)

	await wait_physics_frames(2)
	assert_true(lamp_a.is_switched_on, "Lámpara A encendida inicialmente")
	assert_true(lamp_b.is_switched_on, "Lámpara B encendida inicialmente")
	assert_true(lamp_other.is_switched_on, "Lámpara de otro circuito encendida")

	# 1. Interacción completada manteniendo el foco
	thief.interactor.current_target = sw
	sw.interact(thief)
	sw._physics_process(sw.rules.switch_time + 0.05)

	assert_false(lamp_a.is_switched_on, "Lámpara A conmutada a apagada")
	assert_false(lamp_b.is_switched_on, "Lámpara B conmutada a apagada")
	assert_true(lamp_other.is_switched_on, "Lámpara de circuito 2 permanece encendida")
	assert_false(noises.is_empty(), "Interruptor completado emite ruido")
	var sw_noise: Dictionary = noises.back()
	assert_almost_eq(
		sw_noise.get("radius", 0.0),
		sw.rules.switch_noise_radius,
		0.01,
		"Radio de ruido del interruptor"
	)
	assert_eq(sw_noise.get("team"), &"thief", "Equipo thief en ruido")

	# 2. Interacción interrumpida al perder el foco antes de tiempo
	noises.clear()
	thief.interactor.current_target = sw
	sw.interact(thief)
	sw._physics_process(sw.rules.switch_time * 0.4)
	thief.interactor.current_target = null
	sw._physics_process(sw.rules.switch_time * 0.7)

	assert_false(lamp_a.is_switched_on, "Lámpara A no cambió por interrupción")
	assert_false(lamp_b.is_switched_on, "Lámpara B no cambió por interrupción")
	assert_true(noises.is_empty(), "No debe emitir ruido si se interrumpe la interacción")

	SignalBus.noise_emitted_3d.disconnect(on_noise)


## Criterio 10: desenroscar y enroscar bombilla según perfil y tiempos de interacción
func test_unscrew_and_rescrew() -> void:
	var ceiling_lamp: Lamp3D = _create_lamp(1, LAMP_CEILING_PATH, Vector3(0.0, 2.5, 0.0))
	var desk_lamp: Lamp3D = _create_lamp(2, LAMP_DESK_PATH, Vector3(2.0, 1.0, 0.0))
	var thief: ThiefController3D = _create_thief(Vector3.ZERO)
	var guard: GuardController3D = _create_guard(Vector3(1.0, 0.0, 0.0))

	var noises: Array[Dictionary] = []
	var on_noise: Callable = func(pos: Vector3, radius: float, team: StringName) -> void:
		noises.append({"pos": pos, "radius": radius, "team": team})
	SignalBus.noise_emitted_3d.connect(on_noise)

	await wait_physics_frames(2)

	# 1. Lámpara de techo no es desenroscable
	assert_false(
		ceiling_lamp.can_interact(thief), "Lámpara no unscrewable no permite interacción al ladrón"
	)

	# 2. Desenroscar bombilla de mesa (thief)
	assert_true(desk_lamp.can_interact(thief), "Lámpara de mesa permite desenroscar")
	assert_false(desk_lamp.can_interact(guard), "Guardia no puede enroscar si ya está enroscada")

	thief.interactor.current_target = desk_lamp
	desk_lamp.interact(thief)
	assert_false(noises.is_empty(), "Ruido suena al empezar a desenroscar")
	var unscrew_noise: Dictionary = noises.back()
	assert_almost_eq(
		unscrew_noise.get("radius", 0.0),
		desk_lamp.rules.unscrew_noise_radius,
		0.01,
		"Radio de ruido al desenroscar"
	)

	desk_lamp._physics_process(desk_lamp.rules.unscrew_time + 0.05)
	assert_true(desk_lamp.is_unscrewed, "Bombilla marcada como desenroscada")
	assert_false(desk_lamp.is_lit(), "is_lit() devuelve false al desenroscar")

	# 3. El interruptor no la arregla
	desk_lamp.set_switched(false)
	assert_false(desk_lamp.is_lit(), "Apagada con switch false")
	desk_lamp.set_switched(true)
	assert_false(desk_lamp.is_lit(), "Sigue apagada con switch true porque está desenroscada")

	# 4. Guardia enrosca la bombilla (sin ruido)
	noises.clear()
	assert_true(desk_lamp.can_interact(guard), "Guardia puede enroscar bombilla desenroscada")
	guard.interactor.current_target = desk_lamp
	desk_lamp.interact(guard)
	assert_true(noises.is_empty(), "El guardia no emite ruido al enroscar")

	desk_lamp._physics_process(desk_lamp.rules.rescrew_time + 0.05)
	assert_false(desk_lamp.is_unscrewed, "Bombilla enroscada nuevamente")
	assert_true(desk_lamp.is_lit(), "Lámpara emite luz de nuevo")

	# 5. Interrupción del desenroscado
	thief.interactor.current_target = desk_lamp
	desk_lamp.interact(thief)
	desk_lamp._physics_process(desk_lamp.rules.unscrew_time * 0.4)
	thief.interactor.current_target = null
	desk_lamp._physics_process(desk_lamp.rules.unscrew_time * 0.7)
	assert_false(desk_lamp.is_unscrewed, "Desenroscado cancelado por pérdida de foco")
	assert_true(desk_lamp.is_lit(), "Permanece encendida tras la interrupción")

	SignalBus.noise_emitted_3d.disconnect(on_noise)
