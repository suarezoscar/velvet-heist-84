## @file test_local_control_regression.gd
## Regresión de control local y presentación de personajes en los tres mapas jugables.
## Cubre los fallos de la auditoría previa a Gemini: WASD movía a varios personajes a la vez
## (OfflineMultiplayerPeer da autoridad sobre todo), la IA flotaba sin gravedad y no
## encontraba al ladrón, los modelos de Mixamo miraban hacia atrás y las animaciones no
## tenían bucle.
## Un mapa por test y liberado solo por autofree: liberar mapas a mitad de test colgaba
## GUT 9.6.1 de forma intermitente.
extends GutTest

const GYM_PATH: String = "res://scenes/maps/test_isometric_gym.tscn"
const MANSION_PATH: String = "res://scenes/maps/mansion_belmonte.tscn"
const MUSEUM_PATH: String = "res://scenes/maps/museum_velvet_84.tscn"
const LAYER_CHARACTERS: int = 2
const LAYER_WORLD_SOLID: int = 1
## Distancia (m) por debajo de la cual un personaje se considera quieto
const STILL_TOLERANCE: float = 0.05
## Distancia (m) mínima que debe recorrer el jugador local con WASD
const MIN_LOCAL_DISPLACEMENT: float = 0.3
const SETTLE_FRAMES: int = 40
const MOVE_FRAMES: int = 40


func before_each() -> void:
	if NetManager.is_online():
		NetManager.disconnect_network()


func after_each() -> void:
	Input.action_release(&"move_up")


func _load_map(path: String) -> HeistMap3D:
	var map: HeistMap3D = (load(path) as PackedScene).instantiate() as HeistMap3D
	add_child_autofree(map)
	await wait_physics_frames(SETTLE_FRAMES)
	return map


func _is_ai(actor: PlayerBase3D) -> bool:
	return actor is GuardController3D and (actor as GuardController3D).is_ai_controlled


## Comprueba en un mapa: un único jugador local (el ladrón), capas de colisión, personajes
## apoyados en el suelo y que WASD mueve solo al jugador local.
func _check_map(path: String) -> void:
	var map: HeistMap3D = await _load_map(path)
	var controlled: Array[PlayerBase3D] = []
	var before: Dictionary = {}
	for actor: PlayerBase3D in map.get_actors():
		if actor.is_locally_controlled:
			controlled.append(actor)
		before[actor] = actor.global_position
		assert_eq(actor.collision_layer, LAYER_CHARACTERS, "%s en capa Characters" % actor.name)
		assert_eq(actor.collision_mask, LAYER_WORLD_SOLID, "%s choca con el mundo" % actor.name)
		assert_true(actor.is_on_floor(), "%s apoyado en el suelo" % actor.name)
	assert_eq(controlled.size(), 1, "Un único personaje controlado por teclado")
	assert_eq(map.local_player, map.thief, "Sin red se controla al ladrón")
	assert_true(map.thief.is_locally_controlled, "El ladrón lee el teclado")

	Input.action_press(&"move_up")
	await wait_physics_frames(MOVE_FRAMES)
	Input.action_release(&"move_up")
	for actor: PlayerBase3D in map.get_actors():
		if _is_ai(actor):
			continue
		var moved: float = actor.global_position.distance_to(before[actor])
		if actor == map.local_player:
			assert_gt(moved, MIN_LOCAL_DISPLACEMENT, "%s se mueve con WASD" % actor.name)
		else:
			assert_lt(moved, STILL_TOLERANCE, "%s NO se mueve con WASD" % actor.name)


func test_gym_local_control_and_physics() -> void:
	await _check_map(GYM_PATH)


func test_mansion_local_control_and_physics() -> void:
	await _check_map(MANSION_PATH)


func test_museum_local_control_and_physics() -> void:
	await _check_map(MUSEUM_PATH)


func test_debug_switch_transfers_control() -> void:
	var map: HeistMap3D = await _load_map(GYM_PATH)
	var guard: GuardController3D = map.guards[0]
	map.set_local_player(guard)
	assert_true(guard.is_locally_controlled, "El guardia pasa a ser el jugador local")
	assert_false(map.thief.is_locally_controlled, "El ladrón deja de leer el teclado")
	var thief_before: Vector3 = map.thief.global_position
	var guard_before: Vector3 = guard.global_position
	Input.action_press(&"move_up")
	await wait_physics_frames(MOVE_FRAMES)
	Input.action_release(&"move_up")
	var guard_moved: float = guard.global_position.distance_to(guard_before)
	assert_gt(guard_moved, MIN_LOCAL_DISPLACEMENT, "El guardia se mueve")
	var thief_moved: float = map.thief.global_position.distance_to(thief_before)
	assert_lt(thief_moved, STILL_TOLERANCE, "El ladrón queda quieto")
	assert_eq(map.hud.target_player, guard, "El HUD sigue al personaje controlado")


func test_museum_ai_guard_finds_thief_and_patrols_on_floor() -> void:
	var map: HeistMap3D = await _load_map(MUSEUM_PATH)
	var guard: GuardController3D = map.get_node("GuardPlayer2")
	var ai: GuardAI3D = guard.get_node("GuardAI")
	assert_true(guard.is_ai_controlled, "GuardPlayer2 es de IA sin red")
	assert_eq(ai._thief, map.thief, "La IA localiza al ladrón")
	var start: Vector3 = guard.global_position
	await wait_physics_frames(60)
	assert_gt(guard.global_position.distance_to(start), 0.5, "La IA patrulla")
	assert_true(guard.is_on_floor(), "La IA no flota: aplica gravedad")


func test_model_faces_body_forward_and_body_faces_movement() -> void:
	var map: HeistMap3D = await _load_map(GYM_PATH)
	var thief: ThiefController3D = map.thief
	# Los modelos Mixamo miran a +Z; VisualRoot los gira para alinearlos con -Z (frente Godot)
	var model_forward: Vector3 = thief.visual_root.global_basis.z
	var body_forward: Vector3 = -thief.global_basis.z
	assert_gt(model_forward.dot(body_forward), 0.99, "El modelo mira al frente del cuerpo")
	Input.action_press(&"move_up")
	await wait_physics_frames(MOVE_FRAMES)
	var move_dir: Vector3 = thief.velocity.slide(Vector3.UP).normalized()
	Input.action_release(&"move_up")
	assert_gt((-thief.global_basis.z).dot(move_dir), 0.9, "El cuerpo mira hacia donde camina")


func test_locomotion_animations_loop() -> void:
	var thief: ThiefController3D = (
		(load("res://scenes/entities/thief_player.tscn") as PackedScene).instantiate()
	)
	add_child_autofree(thief)
	await wait_physics_frames(2)
	var player: AnimationPlayer = thief.find_child("AnimationPlayer", true, false)
	for anim_name: StringName in CharacterAnimator3D.LOOPED_ANIMATIONS:
		assert_eq(
			player.get_animation(anim_name).loop_mode,
			Animation.LOOP_LINEAR,
			"%s se repite en bucle" % anim_name
		)
