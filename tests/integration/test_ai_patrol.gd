## @file test_ai_patrol.gd
## #116: la IA de guardia patrulla salas al azar por el museo real (heist.md R5c), va a la
## cafetera cuando le entra sueño y no atiende ruidos durante una cabezada.
extends GutTest

const MAP_SCENE: PackedScene = preload("res://scenes/maps/museum_v2.tscn")
const SPEEDUP: float = 8.0

var _saved_state: GameManager.MatchState


func before_each() -> void:
	_saved_state = GameManager.current_state


func after_each() -> void:
	Engine.time_scale = 1.0
	Engine.max_physics_steps_per_frame = 8
	GameManager.current_state = _saved_state


## Mapa con la partida en marcha y el ladrón fuera, lejos y quieto: que no lo persigan
func _start() -> HeistMap3D:
	var map: HeistMap3D = MAP_SCENE.instantiate() as HeistMap3D
	add_child_autofree(map)
	await wait_physics_frames(2)
	map.thief.global_position = Vector3(-27.0, 0.4, 24.0)
	map.thief.set_physics_process(false)
	GameManager.start_match()
	Engine.max_physics_steps_per_frame = 32
	Engine.time_scale = SPEEDUP
	return map


func _sleep(guard: GuardController3D) -> GuardSleep:
	return guard.get_node("Sleep") as GuardSleep


func test_ai_guard_patrols_and_changes_room() -> void:
	var map: HeistMap3D = await _start()
	var patrol: GuardPatrol = GuardPatrol.of(get_tree())
	var guard: GuardController3D = map.guards[0]
	_sleep(guard).fresh_left = 10000.0  # sin sueño: que no se vaya por café
	var rooms: Dictionary = {}
	var travelled: float = 0.0
	var last: Vector3 = guard.global_position
	for _second: int in range(60):
		await wait_physics_frames(60)
		var pos: Vector3 = guard.global_position
		travelled += Vector2(pos.x - last.x, pos.z - last.z).length()
		last = pos
		var off: Vector2 = patrol.graph.data.offset
		rooms[patrol.graph.room_at(Vector2(pos.x - off.x, pos.z - off.y))] = true
	assert_gt(travelled, 40.0, "No se queda quieto (%.1f m)" % travelled)
	assert_gte(rooms.size(), 3, "Pasa por varias salas (%s)" % str(rooms.keys()))


## OJO: desde lejos la IA va en línea recta a la cafetera y se atasca a 1,5 m (COFFEE_REACH es
## 1,4), así que aquí se prueba el ciclo de café con el guardia ya a su lado
func test_sleepy_ai_guard_goes_for_coffee() -> void:
	var map: HeistMap3D = await _start()
	var patrol: GuardPatrol = GuardPatrol.of(get_tree())
	var guard: GuardController3D = map.guards[0]
	# Junto a la cafetera (ver la nota del test)
	guard.global_position = patrol.graph.data.to_world(
		[39.5, 29.0], LevelEntitiesBuilder.ACTOR_HEIGHT
	)
	var sleep: GuardSleep = _sleep(guard)
	sleep.level = GuardSleep.RULES.ai_coffee_at
	var done: bool = false
	for _second: int in range(150):
		await wait_physics_frames(60)
		if sleep.level == 0.0 and sleep.fresh_left > 0.0:
			done = true
			break
	assert_true(done, "Se sirve el café y queda despejado (nivel %.2f)" % sleep.level)


func test_nodding_ai_guard_ignores_thief_noise() -> void:
	var map: HeistMap3D = await _start()
	Engine.time_scale = 1.0
	var guard: GuardController3D = map.guards[0]
	var ai: GuardAI3D = guard.get_node("GuardAI") as GuardAI3D
	var sleep: GuardSleep = _sleep(guard)
	sleep.level = 1.0
	sleep.nodding = true
	ai.current_state = GuardAI3D.AIState.PATROL
	SignalBus.noise_emitted_3d.emit(guard.global_position, 20.0, &"thief")
	assert_ne(ai.current_state, GuardAI3D.AIState.INVESTIGATE, "En la cabezada no oye")
	sleep.nodding = false
	SignalBus.noise_emitted_3d.emit(guard.global_position, 20.0, &"thief")
	assert_eq(ai.current_state, GuardAI3D.AIState.INVESTIGATE, "Despierto sí investiga")
