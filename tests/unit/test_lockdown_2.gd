## @file test_lockdown_2.gd
## Revisión de #120 (heist.md R3, R7b y R11): el orden en el mismo tick (huye quien está en la
## salida al cerrarse), el callejón, menos partida que cuenta atrás, el final que ya no cambia
## y lo que apunta el informe (proteger y encerrado).
extends GutTest

const MAP_SCENE: PackedScene = preload("res://scenes/maps/museum_v2.tscn")

var _saved_state: GameManager.MatchState
var _saved_timer: float


func before_each() -> void:
	_saved_state = GameManager.current_state
	_saved_timer = GameManager.match_timer


func after_each() -> void:
	GameManager.current_state = _saved_state
	GameManager.match_timer = _saved_timer


func _start() -> HeistMap3D:
	var map: HeistMap3D = MAP_SCENE.instantiate() as HeistMap3D
	add_child_autofree(map)
	for guard: GuardController3D in map.guards:
		guard.set_physics_process(false)
	await wait_physics_frames(2)
	GameManager.current_state = GameManager.MatchState.IN_PROGRESS
	GameManager.match_timer = 600.0
	return map


func _zone(outdoor: bool) -> ExitZone3D:
	for node: Node in get_tree().get_nodes_in_group(&"heist_exits"):
		if (node as ExitZone3D).outdoor == outdoor:
			return node as ExitZone3D
	return null


func _put(map: HeistMap3D, zone: Node3D) -> void:
	map.thief.global_position = Vector3(zone.global_position.x, 0.1, zone.global_position.z)


func test_thief_in_the_exit_when_gates_close_escapes() -> void:
	var map: HeistMap3D = await _start()
	GameManager.heist.stolen.assign([GameManager.heist.targets[0]])
	_put(map, _zone(false))
	await wait_physics_frames(2)
	assert_eq(GameManager.current_state, GameManager.MatchState.IN_PROGRESS, "Sin alarma, nada")
	HeistLockdown.of(get_tree()).left = 0.001
	await wait_physics_frames(2)
	assert_eq(
		GameManager.current_state,
		GameManager.MatchState.THIEF_ESCAPED_PARTIAL,
		"En la salida en el tick del cierre: huye, no queda encerrado"
	)


func test_alley_with_loot_is_partial_escape_only_with_countdown() -> void:
	var map: HeistMap3D = await _start()
	GameManager.heist.stolen.assign([GameManager.heist.targets[0]])
	_put(map, _zone(true))
	await wait_physics_frames(3)
	assert_eq(GameManager.current_state, GameManager.MatchState.IN_PROGRESS, "Sin alarma, nada")
	AlertDirector.of(get_tree()).raise(AlertDirector.Level.ALARM)
	await wait_physics_frames(3)
	assert_eq(GameManager.current_state, GameManager.MatchState.THIEF_ESCAPED_PARTIAL)


func test_less_match_than_countdown_is_dawn() -> void:
	await _start()
	GameManager.match_timer = 0.5
	AlertDirector.of(get_tree()).raise(AlertDirector.Level.ALARM)
	await wait_physics_frames(3)
	var lockdown: HeistLockdown = HeistLockdown.of(get_tree())
	assert_almost_eq(
		lockdown.shown_time(), GameManager.match_timer, 0.001, "Enseña lo que llega antes"
	)
	await wait_physics_frames(60)
	assert_eq(GameManager.current_state, GameManager.MatchState.TIME_EXPIRED, "AMANECE")


func test_the_ending_does_not_change_afterwards() -> void:
	await _start()
	GameManager.end_match(GameManager.MatchState.THIEF_ESCAPED_PARTIAL)
	await wait_physics_frames(1)
	GameManager.end_match(GameManager.MatchState.THIEF_CAPTURED)
	assert_eq(
		GameManager.current_state,
		GameManager.MatchState.THIEF_ESCAPED_PARTIAL,
		"Un golpe después de la huida no la convierte en captura"
	)


func test_capture_in_the_same_tick_beats_the_escape() -> void:
	await _start()
	GameManager.end_match(GameManager.MatchState.THIEF_ESCAPED_PARTIAL)
	GameManager.end_match(GameManager.MatchState.THIEF_CAPTURED)
	assert_eq(GameManager.current_state, GameManager.MatchState.THIEF_CAPTURED, "Captura > huida")


func test_report_counts_protected_pieces_and_lockdown() -> void:
	var map: HeistMap3D = await _start()
	var heist: HeistDirector = GameManager.heist
	heist.stolen.assign([heist.targets[0]])
	var inside: Node3D = get_tree().get_first_node_in_group(&"heist_targets") as Node3D
	map.thief.global_position = inside.global_position + Vector3(1.0, 0.1, 0.0)
	await wait_physics_frames(3)  # que las zonas ya no lo vean en el callejón de salida
	HeistLockdown.of(get_tree()).left = 0.001
	await wait_physics_frames(2)
	assert_eq(GameManager.current_state, GameManager.MatchState.THIEF_LOCKED_IN)
	var recorder: MatchRecorder = map.find_children("*", "MatchRecorder", true, false)[0]
	var report: Dictionary = recorder.build_report()
	for guard: Dictionary in report["guards"]:
		assert_eq(int(guard["protected"]), heist.targets.size() - 1, "Piezas en su sitio")
		assert_true(bool(guard["locked_in"]), "Encerrado")
