## @file test_ai_rounds.gd
## FEAT-034: los guardias de la IA recorren su ronda en el museo real sin quedarse atascados en
## los muebles y fichan sus relojes (al menos 60 s de partida, simulados deprisa).
extends GutTest

const MAP_SCENE: PackedScene = preload("res://scenes/maps/museum_v2.tscn")
const SIM_SECONDS: float = 60.0
const SPEEDUP: float = 8.0

var _saved_state: GameManager.MatchState
var _punches: Dictionary = {}


func before_each() -> void:
	_saved_state = GameManager.current_state
	_punches.clear()


func after_each() -> void:
	Engine.time_scale = 1.0
	Engine.max_physics_steps_per_frame = 8
	GameManager.current_state = _saved_state


func _on_punch(clock_id: int, _peer: int) -> void:
	_punches[clock_id] = int(_punches.get(clock_id, 0)) + 1


func test_ai_guards_walk_their_rounds() -> void:
	var map: HeistMap3D = MAP_SCENE.instantiate() as HeistMap3D
	add_child_autofree(map)
	await wait_physics_frames(2)
	map.thief.global_position = Vector3(-27.0, 0.4, 24.0)  # fuera, lejos: que no lo persigan
	map.thief.set_physics_process(false)
	SignalBus.time_clock_punched.connect(_on_punch)
	GameManager.start_match()
	Engine.max_physics_steps_per_frame = 32
	Engine.time_scale = SPEEDUP
	var travelled: Array[float] = [0.0, 0.0]
	var last: Array[Vector3] = [map.guards[0].global_position, map.guards[1].global_position]
	for _second: int in range(int(SIM_SECONDS)):
		await wait_physics_frames(60)
		for index: int in range(2):
			var pos: Vector3 = map.guards[index].global_position
			travelled[index] += Vector2(pos.x - last[index].x, pos.z - last[index].z).length()
			last[index] = pos
	Engine.time_scale = 1.0
	SignalBus.time_clock_punched.disconnect(_on_punch)
	var total: int = 0
	for count: int in _punches.values():
		total += count
	assert_gte(total, 4, "Entre los dos fichan al menos 4 relojes (%s)" % str(_punches))
	for index: int in range(2):
		var round_node: GuardRound = GuardRound.of(map.guards[index])
		assert_lte(round_node.faults, 1, "El guardia %d llega a tiempo a sus relojes" % index)
		assert_gt(travelled[index], 60.0, "El guardia %d no se queda quieto" % index)
