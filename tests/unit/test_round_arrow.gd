## @file test_round_arrow.gd
## La flecha de la ronda en el museo (FEAT-042): el camino pasa por las puertas y con la
## alarma se esconde.
extends GutTest

const MAP_SCENE: PackedScene = preload("res://scenes/maps/museum_v2.tscn")

var _saved_state: GameManager.MatchState


func before_each() -> void:
	_saved_state = GameManager.current_state


## El mapa deja la partida en curso: los tests que vienen detrás (red) no deben heredarla
func after_each() -> void:
	GameManager.current_state = _saved_state


## La flecha de verdad: el camino pasa por las puertas y con la alarma se esconde
func test_arrow_in_the_museum() -> void:
	var map: HeistMap3D = MAP_SCENE.instantiate() as HeistMap3D
	add_child_autofree(map)
	await wait_physics_frames(5)
	var planner: RoundPlanner = RoundPlanner.of(get_tree())
	var clocks: Array[Node] = get_tree().get_nodes_in_group(&"time_clock")
	var far: Vector3 = (clocks[0] as Node3D).global_position
	var other: Vector3 = (clocks[clocks.size() - 1] as Node3D).global_position
	assert_gt(planner.walk_between(far, other).size(), 1, "Pasa por alguna puerta")
	var guard: GuardController3D = map.guards[0]
	map.set_local_player(guard)
	await wait_physics_frames(3)
	var arrow: RoundArrow3D = map.find_child("RoundArrow", true, false) as RoundArrow3D
	await wait_process_frames(2)
	assert_true(arrow.visible, "Con ruta, la flecha se ve")
	GuardRound.of(guard).suspended = true
	await wait_process_frames(2)
	assert_false(arrow.visible, "Con la alarma, no")
