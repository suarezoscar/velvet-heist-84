## @file test_per_guard_perception.gd
## Tests de aceptación para percepción por guardia, avisos de IA y datos O2 (FEAT-011).
extends GutTest

const GUARD_SCENE_PATH: String = "res://scenes/entities/guard_player.tscn"
const THIEF_SCENE_PATH: String = "res://scenes/entities/thief_player.tscn"


func _create_map_with_actors() -> Dictionary:
	var map: HeistMap3D = autofree(HeistMap3D.new())
	var guard_scene: PackedScene = load(GUARD_SCENE_PATH) as PackedScene
	var thief_scene: PackedScene = load(THIEF_SCENE_PATH) as PackedScene

	var thief: ThiefController3D = thief_scene.instantiate() as ThiefController3D
	thief.name = "Thief"
	thief.position = Vector3(0.0, 0.0, -4.0)
	thief.set_physics_process(false)
	map.add_child(thief)

	var guard_a: GuardController3D = guard_scene.instantiate() as GuardController3D
	guard_a.name = "GuardA"
	guard_a.position = Vector3(0.0, 0.0, 0.0)
	guard_a.rotation = Vector3.ZERO
	guard_a.look_target_position = Vector3(0.0, 1.4, -10.0)
	guard_a.set_physics_process(false)
	map.add_child(guard_a)

	var guard_b: GuardController3D = guard_scene.instantiate() as GuardController3D
	guard_b.name = "GuardB"
	guard_b.position = Vector3(50.0, 0.0, 50.0)
	guard_b.rotation = Vector3.ZERO
	guard_b.look_target_position = Vector3(50.0, 1.4, 60.0)
	guard_b.set_physics_process(false)
	map.add_child(guard_b)

	add_child_autofree(map)
	return {"map": map, "thief": thief, "guard_a": guard_a, "guard_b": guard_b}


func after_each() -> void:
	GameManager.current_state = GameManager.MatchState.LOBBY


## Criterio 11: Invariante 21: visibilidad local del ladrón por guardia
func test_inv21_per_guard_visibility() -> void:
	var setup: Dictionary = _create_map_with_actors()
	var map: HeistMap3D = setup["map"] as HeistMap3D
	var thief: ThiefController3D = setup["thief"] as ThiefController3D
	var guard_a: GuardController3D = setup["guard_a"] as GuardController3D
	var guard_b: GuardController3D = setup["guard_b"] as GuardController3D

	await wait_physics_frames(2)
	map._process_guards_perception(0.1)

	assert_true(guard_a.is_perceiving_thief, "Guardia A percibe al ladrón con su linterna")
	assert_false(guard_b.is_perceiving_thief, "Guardia B no percibe al ladrón (fuera de rango)")

	# 1. Jugador local = Guardia A (que sí lo percibe)
	map.set_local_player(guard_a)
	map._update_thief_local_visibility()
	assert_true(
		thief.visual_root.visible, "Ladrón es visible en pantalla de Guardia A porque lo percibe"
	)

	# 2. Jugador local = Guardia B (que NO lo percibe)
	map.set_local_player(guard_b)
	map._update_thief_local_visibility()
	assert_false(
		thief.visual_root.visible,
		"Ladrón es invisible en pantalla de Guardia B porque no lo percibe"
	)

	# 3. Jugador local = Ladrón (siempre visible para sí mismo)
	map.set_local_player(thief)
	map._update_thief_local_visibility()
	assert_true(thief.visual_root.visible, "Ladrón siempre es visible cuando es el jugador local")


## Criterio 12: IA solo reacciona a su propio guardia; la IA de otro guardia no se alerta
func test_ai_not_alerted_by_other_guard() -> void:
	var setup: Dictionary = _create_map_with_actors()
	var map: HeistMap3D = setup["map"] as HeistMap3D
	var guard_a: GuardController3D = setup["guard_a"] as GuardController3D
	var guard_b: GuardController3D = setup["guard_b"] as GuardController3D

	var ai_a: GuardAI3D = GuardAI3D.new()
	guard_a.add_child(ai_a)
	guard_a.is_ai_controlled = true

	var ai_b: GuardAI3D = GuardAI3D.new()
	guard_b.add_child(ai_b)
	guard_b.is_ai_controlled = true

	var spotted_calls: int = 0
	var on_spotted: Callable = func(_pos: Vector3) -> void: spotted_calls += 1
	SignalBus.thief_spotted.connect(on_spotted)

	await wait_physics_frames(2)
	map._process_guards_perception(0.1)

	assert_eq(ai_a.current_state, GuardAI3D.AIState.CHASE, "IA de Guardia A entra en CHASE")
	assert_ne(ai_b.current_state, GuardAI3D.AIState.CHASE, "IA de Guardia B no pasa a CHASE")
	assert_eq(ai_b.current_state, GuardAI3D.AIState.PATROL, "IA de Guardia B permanece en PATROL")
	assert_eq(spotted_calls, 0, "SignalBus.thief_spotted no debe ser emitido por el mapa")

	SignalBus.thief_spotted.disconnect(on_spotted)


## Criterio 13: O2: persistencia de última posición conocida y temporizador de linger
func test_last_seen_data() -> void:
	var guard_scene: PackedScene = load(GUARD_SCENE_PATH) as PackedScene
	var guard: GuardController3D = autofree(guard_scene.instantiate() as GuardController3D)
	guard.position = Vector3.ZERO
	guard.rotation = Vector3.ZERO
	guard.look_target_position = Vector3(0.0, 1.4, -10.0)
	guard.set_physics_process(false)
	add_child_autofree(guard)

	var thief_scene: PackedScene = load(THIEF_SCENE_PATH) as PackedScene
	var thief_pos: Vector3 = Vector3(0.0, 0.0, -4.0)
	var thief: ThiefController3D = autofree(thief_scene.instantiate() as ThiefController3D)
	thief.position = thief_pos
	thief.set_physics_process(false)
	add_child_autofree(thief)

	await wait_physics_frames(2)
	var profile: PerceptionProfile = guard.perception
	assert_gt(profile.last_seen_linger, 0.0, "last_seen_linger debe ser mayor que 0")

	# 1. El guardia percibe al ladrón
	guard.update_perception(thief, [], 0.1)
	assert_true(guard.is_perceiving_thief, "Guardia percibe al ladrón")
	var perceived_pos: Vector3 = thief.global_position
	assert_eq(
		guard.last_seen_position, perceived_pos, "last_seen_position guarda la posición vista"
	)
	assert_almost_eq(
		guard.last_seen_time_left,
		profile.last_seen_linger,
		0.001,
		"last_seen_time_left inicializado a last_seen_linger"
	)

	# 2. El ladrón sale de la vista (se mueve lejos)
	thief.position = Vector3(50.0, 0.0, 50.0)
	await wait_physics_frames(2)

	guard.update_perception(thief, [], 0.5)
	assert_false(guard.is_perceiving_thief, "Guardia ya no percibe al ladrón")
	assert_eq(guard.last_seen_position, perceived_pos, "last_seen_position persiste sin visión")
	assert_almost_eq(
		guard.last_seen_time_left,
		profile.last_seen_linger - 0.5,
		0.001,
		"last_seen_time_left desciende con el tiempo"
	)

	# 3. Transcurre todo el tiempo restante
	guard.update_perception(thief, [], profile.last_seen_linger)
	assert_false(guard.is_perceiving_thief)
	assert_eq(guard.last_seen_position, perceived_pos, "last_seen_position se sigue conservando")
	assert_almost_eq(guard.last_seen_time_left, 0.0, 0.001, "last_seen_time_left llega a 0")

	# 4. No desciende por debajo de 0
	guard.update_perception(thief, [], 1.0)
	assert_almost_eq(guard.last_seen_time_left, 0.0, 0.001, "last_seen_time_left no es negativo")
