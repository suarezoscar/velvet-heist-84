## @file test_lockdown.gd
## La cuenta atrás de las rejas (heist.md R3 y R7b, #120): arranca con la primera alarma, no se
## para, las rejas bajan y se cierran; huida a medias por una salida o el callejón; ENCERRADO y
## SIN BOTÍN; y la IA cubre una salida cada guardia.
extends GutTest

const MAP_SCENE: PackedScene = preload("res://scenes/maps/museum_v2.tscn")
const RULES: HeistRules = preload("res://data/balance/heist_rules.tres")

var _saved_state: GameManager.MatchState
var _saved_timer: float


func before_each() -> void:
	_saved_state = GameManager.current_state
	_saved_timer = GameManager.match_timer


func after_each() -> void:
	GameManager.current_state = _saved_state
	GameManager.match_timer = _saved_timer


func _map() -> HeistMap3D:
	var map: HeistMap3D = MAP_SCENE.instantiate() as HeistMap3D
	add_child_autofree(map)
	for guard: GuardController3D in map.guards:
		guard.set_physics_process(false)
	return map


func _start(map: HeistMap3D) -> HeistLockdown:
	await wait_physics_frames(2)
	GameManager.current_state = GameManager.MatchState.IN_PROGRESS
	GameManager.match_timer = 600.0
	var inside: Node3D = get_tree().get_first_node_in_group(&"heist_targets") as Node3D
	map.thief.global_position = inside.global_position + Vector3(1.0, 0.1, 0.0)  # dentro
	return HeistLockdown.of(get_tree())


func _exit(outdoor: bool) -> ExitZone3D:
	for node: Node in get_tree().get_nodes_in_group(&"heist_exits"):
		if (node as ExitZone3D).outdoor == outdoor:
			return node as ExitZone3D
	return null


func test_escape_state_rules() -> void:
	var heist: HeistDirector = HeistDirector.new()
	autofree(heist)
	heist.targets.assign([&"A", &"B"])
	heist.contract_size = 2
	var lockdown: HeistLockdown = HeistLockdown.new()
	autofree(lockdown)
	assert_eq(HeistLockdown.escape_state(heist, lockdown), -1, "Sin piezas ni alarma, nada")
	heist.stolen.assign([&"A"])
	assert_eq(HeistLockdown.escape_state(heist, lockdown), -1, "Sin alarma hace falta todo")
	lockdown.left = 10.0
	assert_eq(
		HeistLockdown.escape_state(heist, lockdown),
		GameManager.MatchState.THIEF_ESCAPED_PARTIAL,
		"Con la cuenta atrás y una pieza, huida a medias"
	)
	heist.stolen.assign([&"A", &"B"])
	assert_eq(
		HeistLockdown.escape_state(heist, lockdown),
		GameManager.MatchState.THIEF_ESCAPED,
		"Con el encargo completo, huida completa aunque haya alarma"
	)
	heist.stolen.clear()
	assert_eq(
		HeistLockdown.escape_state(heist, lockdown), -1, "Con 0 piezas la salida no hace nada"
	)
	lockdown.closed = true
	heist.stolen.assign([&"A"])
	assert_eq(HeistLockdown.escape_state(heist, lockdown), -1, "Con las rejas cerradas, nada")


func test_alarm_starts_the_countdown_and_it_never_stops() -> void:
	var map: HeistMap3D = _map()
	var lockdown: HeistLockdown = await _start(map)
	assert_false(lockdown.is_running(), "Sin alarma no corre")
	AlertDirector.of(get_tree()).raise(AlertDirector.Level.ALARM)
	await wait_physics_frames(2)
	assert_true(lockdown.is_running())
	var left: float = lockdown.left
	assert_lt(left, RULES.lockdown_time)
	AlertDirector.of(get_tree()).raise(AlertDirector.Level.ALARM)
	await wait_physics_frames(2)
	assert_lt(lockdown.left, left, "Otra alarma no la reinicia")


func test_gates_close_and_thief_inside_is_locked_in() -> void:
	var map: HeistMap3D = _map()
	var lockdown: HeistLockdown = await _start(map)
	lockdown.left = RULES.gate_drop_time + 0.05
	await wait_physics_frames(3)
	assert_gt(lockdown.drop_progress(), 0.0, "Las rejas empiezan a bajar")
	assert_eq(GameManager.current_state, GameManager.MatchState.IN_PROGRESS, "Aún se pasa")
	lockdown.left = 0.01
	await wait_physics_frames(2)
	assert_true(lockdown.closed)
	assert_eq(GameManager.current_state, GameManager.MatchState.THIEF_LOCKED_IN, "ENCERRADO")
	var gate: ExitGate3D = map.find_child("Gate_P01", true, false) as ExitGate3D
	assert_true(gate != null and gate.is_closed(), "La reja tapa el paso")


func test_thief_in_the_alley_without_loot_is_no_loot() -> void:
	var map: HeistMap3D = _map()
	var lockdown: HeistLockdown = await _start(map)
	var alley: ExitZone3D = _exit(true)
	map.thief.global_position = Vector3(alley.global_position.x, 0.1, alley.global_position.z)
	await wait_physics_frames(3)
	lockdown.left = 0.01
	await wait_physics_frames(2)
	assert_eq(GameManager.current_state, GameManager.MatchState.THIEF_NO_LOOT, "SIN BOTÍN")


func test_partial_escape_through_a_door() -> void:
	var map: HeistMap3D = _map()
	var lockdown: HeistLockdown = await _start(map)
	GameManager.heist.stolen.assign([GameManager.heist.targets[0]])
	lockdown.left = 20.0
	var door: ExitZone3D = _exit(false)
	map.thief.global_position = Vector3(door.global_position.x, 0.1, door.global_position.z)
	await wait_physics_frames(3)
	assert_eq(GameManager.current_state, GameManager.MatchState.THIEF_ESCAPED_PARTIAL)


func test_ai_guards_cover_different_exits() -> void:
	var map: HeistMap3D = _map()
	var lockdown: HeistLockdown = await _start(map)
	lockdown.left = 20.0
	var picked: Array[ExitZone3D] = []
	for guard: GuardController3D in map.guards:
		var ai: GuardAI3D = guard.get_node_or_null("GuardAI") as GuardAI3D
		if ai == null:
			continue
		assert_true(GuardExitCover.pick(ai, guard) is Vector3, "Hay salida libre")
		assert_false(picked.has(ai.cover_exit), "Una salida por guardia")
		picked.append(ai.cover_exit)
	assert_gt(picked.size(), 1, "Hay varios guardias de IA")
	lockdown.left = -1.0
	var first: GuardAI3D = map.guards[0].get_node("GuardAI") as GuardAI3D
	assert_null(GuardExitCover.pick(first, map.guards[0]), "Sin cuenta atrás no cubre")
