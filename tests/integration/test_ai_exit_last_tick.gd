## @file test_ai_exit_last_tick.gd
## #116 (heist.md R4): quien cruza la salida en el último tick escapa; la salida decide antes
## que el tiempo. Con el ladrón fuera, el tiempo da la victoria a los guardias.
extends GutTest

const MAP_SCENE: PackedScene = preload("res://scenes/maps/museum_v2.tscn")

var _saved_state: GameManager.MatchState


func before_each() -> void:
	_saved_state = GameManager.current_state


func after_each() -> void:
	GameManager.current_state = _saved_state


func _ready_map() -> HeistMap3D:
	var map: HeistMap3D = MAP_SCENE.instantiate() as HeistMap3D
	add_child_autofree(map)
	await wait_physics_frames(2)
	for piece_id: StringName in GameManager.heist.targets:
		GameManager.heist.mark_stolen(piece_id)
	GameManager.start_match()
	return map


func test_thief_inside_exit_escapes_on_last_tick() -> void:
	var map: HeistMap3D = await _ready_map()
	var exit_zone: Node3D = map.find_child("Exit_P01", true, false)
	map.thief.global_position = exit_zone.global_position
	await wait_physics_frames(2)
	GameManager.current_state = GameManager.MatchState.IN_PROGRESS
	GameManager.match_timer = 0.001
	await wait_physics_frames(1)
	assert_eq(GameManager.current_state, GameManager.MatchState.THIEF_ESCAPED, "Escapa, no caduca")


func test_thief_outside_exit_loses_on_time() -> void:
	var map: HeistMap3D = await _ready_map()
	map.thief.global_position = Vector3(-27.0, 0.4, 24.0)
	await wait_physics_frames(2)
	GameManager.current_state = GameManager.MatchState.IN_PROGRESS
	GameManager.match_timer = 0.001
	await wait_physics_frames(1)
	assert_eq(GameManager.current_state, GameManager.MatchState.TIME_EXPIRED, "Fuera: caduca")
