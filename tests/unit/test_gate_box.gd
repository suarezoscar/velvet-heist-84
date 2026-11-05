## @file test_gate_box.gd
## La caja de la reja (heist.md R7c, #121): los tres pasos del sabotaje, cortar fuera de orden,
## retomarlo, la reja que se queda arriba, reparar (también tras el cierre, que lleva a
## ENCERRADO), la huida por la salida saboteada y la IA que repara lo que ve.
extends GutTest

const MAP_SCENE: PackedScene = preload("res://scenes/maps/museum_v2.tscn")
const RULES: HeistRules = preload("res://data/balance/heist_rules.tres")

var _saved_state: GameManager.MatchState
var _saved_timer: float


func before_each() -> void:
	_saved_state = GameManager.current_state
	_saved_timer = GameManager.match_timer
	GameManager.current_state = GameManager.MatchState.IN_PROGRESS


func after_each() -> void:
	GameManager.current_state = _saved_state
	GameManager.match_timer = _saved_timer


## Caja suelta con un actor en el árbol
func _box() -> Array:
	var box: GateBox3D = GateBox3D.create("P01")
	add_child_autofree(box)
	var actor: Node3D = Node3D.new()
	add_child_autofree(actor)
	return [box, actor]


func _run(session: SabotageSession, seconds: float) -> void:
	for i: int in range(roundi(seconds / 0.05)):
		session.tick(0.05)


## Corta los cables en el orden de sus bornes (eligiendo la punta a mano)
func _cut_all(session: SabotageSession, box: GateBox3D) -> void:
	for terminal: int in range(RULES.box_wires):
		session.selected = box.terminal_of.find(terminal)
		session.press()


func test_three_steps_sabotage_the_box() -> void:
	var pair: Array = _box()
	var box: GateBox3D = pair[0]
	var session: SabotageSession = SabotageSession.start(box, pair[1])
	assert_eq(box.step, GateBox3D.Step.UNSCREW)
	_run(session, RULES.box_screws * RULES.box_screw_time + 0.1)
	assert_eq(box.step, GateBox3D.Step.CUT, "Tapa fuera")
	_cut_all(session, box)
	session.tick(0.05)
	assert_eq(box.step, GateBox3D.Step.SCREW, "Cables cortados")
	session.press()  # vuelve a mantener E
	_run(session, RULES.box_screws * RULES.box_screw_time + 0.1)
	assert_true(box.is_sabotaged(), "Tapa cerrada: saboteada")


func test_wrong_wire_sparks_and_costs_a_splice() -> void:
	var pair: Array = _box()
	var box: GateBox3D = pair[0]
	var session: SabotageSession = SabotageSession.start(box, pair[1])
	box.step = GateBox3D.Step.CUT
	session.selected = box.terminal_of.find(1)  # el del borne 2, antes que el del 1
	session.press()
	assert_eq(box.fails, 1, "Chispazo")
	assert_eq(box.cut_tips.size(), 0, "No corta")
	session.selected = box.terminal_of.find(0)
	session.press()
	assert_eq(box.cut_tips.size(), 0, "Empalmando no se corta")
	_run(session, RULES.box_splice_time + 0.1)
	session.press()
	assert_eq(box.cut_tips.size(), 1, "Tras empalmar, sí")


func test_cancel_keeps_progress_in_the_box() -> void:
	var pair: Array = _box()
	var box: GateBox3D = pair[0]
	var session: SabotageSession = SabotageSession.start(box, pair[1])
	_run(session, RULES.box_screw_time * 2.0 + 0.3)
	assert_eq(box.screws_out, 2)
	session.cancel()
	assert_eq(session.tick(0.05), SabotageSession.Result.CANCELLED)
	var again: SabotageSession = SabotageSession.start(box, pair[1])
	assert_eq(box.screws_out, 2, "Los tornillos quitados siguen fuera")
	assert_eq(again.screw_progress, 0.0, "El tornillo a medias vuelve a empezar")


func test_selection_skips_cut_wires_and_vertical_cancels() -> void:
	var pair: Array = _box()
	var box: GateBox3D = pair[0]
	var session: SabotageSession = SabotageSession.start(box, pair[1])
	box.step = GateBox3D.Step.CUT
	box.cut_tips.assign([1])
	session.selected = 0
	session.steer(Vector2.ZERO)
	session.steer(Vector2(1, 0))
	assert_eq(session.selected, 2, "Salta la punta ya cortada")
	session.steer(Vector2(0, 1))
	assert_eq(session.tick(0.05), SabotageSession.Result.CANCELLED, "W S salen")


func test_sabotaged_gate_stays_up_and_repair_brings_it_down() -> void:
	var map: HeistMap3D = MAP_SCENE.instantiate() as HeistMap3D
	add_child_autofree(map)
	for guard: GuardController3D in map.guards:
		guard.set_physics_process(false)
	await wait_physics_frames(2)
	GameManager.current_state = GameManager.MatchState.IN_PROGRESS
	GameManager.match_timer = 600.0
	var inside: Node3D = get_tree().get_first_node_in_group(&"heist_targets") as Node3D
	map.thief.global_position = inside.global_position + Vector3(1.0, 0.1, 0.0)
	var box: GateBox3D = map.find_child("GateBox_P01", true, false) as GateBox3D
	assert_not_null(box, "Cada salida tiene su caja")
	box.step = GateBox3D.Step.SABOTAGED
	var lockdown: HeistLockdown = HeistLockdown.of(get_tree())
	lockdown.left = RULES.gate_drop_time + 0.05
	await wait_physics_frames(3)
	assert_true(lockdown.held.has("P01"), "Su reja se queda arriba")
	lockdown.left = 0.001
	await wait_physics_frames(2)
	assert_true(lockdown.closed)
	assert_eq(GameManager.current_state, GameManager.MatchState.IN_PROGRESS, "Queda una abierta")
	assert_eq(lockdown.open_count(), 1)
	assert_true(lockdown.exit_open("P01"))
	assert_false(lockdown.exit_open("P02"))
	assert_false(box.can_sabotage(), "Ya no se sabotea otra")
	var guard: GuardController3D = map.guards[0]
	box._finish_repair(guard)
	assert_eq(int(guard.get_meta(GateBox3D.REPAIRS_META, 0)), 1, "Cuenta la reparación")
	assert_true(lockdown.late.has("P01"), "Baja ahora")
	await wait_physics_frames(roundi(RULES.gate_drop_time * 60.0) + 10)
	assert_eq(GameManager.current_state, GameManager.MatchState.THIEF_LOCKED_IN, "ENCERRADO")


func test_escape_through_the_sabotaged_exit_after_closing() -> void:
	var map: HeistMap3D = MAP_SCENE.instantiate() as HeistMap3D
	add_child_autofree(map)
	for guard: GuardController3D in map.guards:
		guard.set_physics_process(false)
	await wait_physics_frames(2)
	GameManager.current_state = GameManager.MatchState.IN_PROGRESS
	GameManager.match_timer = 600.0
	GameManager.heist.stolen.assign([GameManager.heist.targets[0]])
	var lockdown: HeistLockdown = HeistLockdown.of(get_tree())
	var inside: Node3D = get_tree().get_first_node_in_group(&"heist_targets") as Node3D
	map.thief.global_position = inside.global_position + Vector3(1.0, 0.1, 0.0)
	await wait_physics_frames(3)  # fuera del callejón donde empieza
	lockdown.left = 0.0
	lockdown.closed = true
	lockdown.held["P01"] = true
	var other: Node3D = map.find_child("Exit_P02", true, false)
	# Dentro, pegado a la reja cerrada (en la zona de la puerta, no en el callejón)
	map.thief.global_position = Vector3(other.global_position.x, 0.1, other.global_position.z - 0.7)
	await wait_physics_frames(3)
	assert_eq(GameManager.current_state, GameManager.MatchState.IN_PROGRESS, "P02 está cerrada")
	var door: Node3D = map.find_child("Exit_P01", true, false)
	map.thief.global_position = Vector3(door.global_position.x, 0.1, door.global_position.z)
	await wait_physics_frames(3)
	assert_eq(GameManager.current_state, GameManager.MatchState.THIEF_ESCAPED_PARTIAL)
	assert_true(lockdown.sabotage_escape, "Huyó gracias al sabotaje")


func test_ai_guard_spots_a_tampered_box_nearby() -> void:
	var map: HeistMap3D = MAP_SCENE.instantiate() as HeistMap3D
	add_child_autofree(map)
	for guard: GuardController3D in map.guards:
		guard.set_physics_process(false)
	await wait_physics_frames(2)
	var box: GateBox3D = map.find_child("GateBox_P01", true, false) as GateBox3D
	var guard: GuardController3D = map.guards[0]
	guard.global_position = box.global_position + Vector3(0.0, 0.1, -2.0)
	await wait_physics_frames(2)
	assert_null(GuardExitCover.spot_box(guard), "Entera no hay nada que ver")
	box.step = GateBox3D.Step.SABOTAGED
	assert_eq(GuardExitCover.spot_box(guard), box, "Saboteada de cerca, sí")
	guard.global_position = box.global_position + Vector3(0.0, 0.1, -6.0)
	await wait_physics_frames(2)
	assert_null(GuardExitCover.spot_box(guard), "Lejos, no")
