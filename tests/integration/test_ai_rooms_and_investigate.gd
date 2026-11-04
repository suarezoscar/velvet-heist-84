## @file test_ai_rooms_and_investigate.gd
## #116: dos guardias de IA no van a la misma sala a la vez (R5c) y, al investigar un punto
## tras un muro, la IA se rinde en vez de empujar la pared.
extends GutTest

const MAP_SCENE: PackedScene = preload("res://scenes/maps/museum_v2.tscn")

var _saved_state: GameManager.MatchState


func before_each() -> void:
	_saved_state = GameManager.current_state


func after_each() -> void:
	Engine.time_scale = 1.0
	Engine.max_physics_steps_per_frame = 8
	GameManager.current_state = _saved_state


func _start() -> HeistMap3D:
	var map: HeistMap3D = MAP_SCENE.instantiate() as HeistMap3D
	add_child_autofree(map)
	await wait_physics_frames(2)
	map.thief.global_position = Vector3(-27.0, 0.4, 24.0)
	map.thief.set_physics_process(false)
	GameManager.start_match()
	return map


func _ai(guard: GuardController3D) -> GuardAI3D:
	return guard.get_node("GuardAI") as GuardAI3D


func test_two_ai_guards_never_share_target_room() -> void:
	var map: HeistMap3D = await _start()
	var first: GuardAI3D = _ai(map.guards[0])
	var second: GuardAI3D = _ai(map.guards[1])
	for i: int in range(40):
		first._next_room()
		second._next_room()
		assert_ne(first.target_room, "", "Elige sala")
		assert_ne(first.target_room, second.target_room, "Cada uno a su sala (ronda %d)" % i)


func test_investigating_behind_a_wall_gives_up() -> void:
	var map: HeistMap3D = await _start()
	var patrol: GuardPatrol = GuardPatrol.of(get_tree())
	var guard: GuardController3D = map.guards[0]
	guard.global_position = patrol.graph.data.to_world(
		[3.0, 3.0], LevelEntitiesBuilder.ACTOR_HEIGHT  # ANT
	)
	var ai: GuardAI3D = _ai(guard)
	(guard.get_node("Sleep") as GuardSleep).fresh_left = 10000.0
	ai.investigation_point = patrol.graph.data.to_world(
		[28.0, 3.0], LevelEntitiesBuilder.ACTOR_HEIGHT  # VLT, tras el muro x=16
	)
	ai.current_state = GuardAI3D.AIState.INVESTIGATE
	ai._investigate_timer = GuardAI3D.NOISE_INVESTIGATE_TIME
	var gave_up: bool = false
	for _step: int in range(15 * 60):  # 15 s
		await wait_physics_frames(1)
		if ai.current_state != GuardAI3D.AIState.INVESTIGATE:
			gave_up = true
			break
	assert_true(gave_up, "Se rinde en un tiempo acotado en vez de empujar el muro")
