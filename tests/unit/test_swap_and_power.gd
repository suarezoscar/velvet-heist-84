## @file test_swap_and_power.gd
## El cambiazo con piezas de pega y el corte de corriente (heist.md R9, FEAT-032).
extends GutTest

const MAP_SCENE: PackedScene = preload("res://scenes/maps/museum_v2.tscn")
const RULES: HeistRules = preload("res://data/balance/heist_rules.tres")

var _saved_state: GameManager.MatchState


func before_each() -> void:
	_saved_state = GameManager.current_state


func after_each() -> void:
	GameManager.current_state = _saved_state


func _map() -> HeistMap3D:
	var map: HeistMap3D = MAP_SCENE.instantiate() as HeistMap3D
	add_child_autofree(map)
	for guard: GuardController3D in map.guards:
		guard.set_physics_process(false)
	return map


func _piece(protection: StringName) -> TargetPiece3D:
	for node: Node in get_tree().get_nodes_in_group(&"heist_targets"):
		if (node as TargetPiece3D).protection == protection:
			return node as TargetPiece3D
	return null


func _run(node: Node, seconds: float) -> void:
	for i: int in range(roundi(seconds / 0.1)):
		node._physics_process(0.1)


func test_swap_leaves_a_fake_that_must_be_inspected() -> void:
	var map: HeistMap3D = _map()
	await wait_physics_frames(2)
	var heist: HeistDirector = GameManager.heist
	var alert: AlertDirector = AlertDirector.of(get_tree())
	var piece: TargetPiece3D = _piece(&"pressure")
	heist.targets.assign([piece.piece_id])
	var thief: ThiefController3D = map.thief
	var table: ReplicaTable3D = map.find_child("ReplicaTable", true, false) as ReplicaTable3D
	assert_false(table.can_interact(map.guards[0]), "Solo el ladrón")
	table.interact(thief)
	assert_true(heist.carrying_fake, "Coge una pieza de pega")
	assert_false(table.can_interact(thief), "Solo una cada vez")
	thief.global_position = piece.global_position + Vector3(1.0, 0.05, 0.0)
	assert_string_contains(piece.get_interaction_text(thief), "cambiazo")
	piece.interact(thief)
	thief.global_position += Vector3(RULES.task_leash + 1.0, 0.0, 0.0)
	_run(piece, RULES.swap_time + 0.5)
	assert_false(piece.stolen, "Si se va, no hay cambiazo")
	thief.global_position = piece.global_position + Vector3(1.0, 0.05, 0.0)
	piece.interact(thief)
	_run(piece, RULES.swap_time + 0.5)
	assert_true(piece.stolen and piece.is_faked(), "Cambiazo hecho")
	assert_true(piece.model.visible, "La copia se ve en el pedestal")
	assert_false(heist.carrying_fake)
	assert_eq(alert.level, AlertDirector.Level.CALM, "En silencio")
	var guard: GuardController3D = map.guards[0]
	guard.global_position = piece.global_position + Vector3(-2.0, 0.05, 0.0)
	await wait_physics_frames(2)
	alert.scan()
	assert_false(piece.discovered, "Mirarla no basta: no es un pedestal vacío")
	assert_true(piece.can_inspect(guard))
	piece.interact(guard)
	_run(piece, RULES.inspect_time + 0.5)
	assert_true(piece.discovered, "Examinada: ¡falsificación!")


func test_inspecting_an_authentic_piece_marks_it() -> void:
	var map: HeistMap3D = _map()
	await wait_physics_frames(2)
	var piece: TargetPiece3D = _piece(&"pressure")
	var guard: GuardController3D = map.guards[0]
	guard.global_position = piece.global_position + Vector3(1.0, 0.05, 0.0)
	piece.interact(guard)
	_run(piece, RULES.inspect_time + 0.5)
	assert_true(piece.inspected, "Auténtica")
	assert_false(piece.discovered)
	assert_false(piece.can_inspect(guard), "No hace falta volver a mirarla")


func test_power_cut_silences_sensor_pieces_and_pilot_tells_guards() -> void:
	var map: HeistMap3D = _map()
	await wait_physics_frames(2)
	var heist: HeistDirector = GameManager.heist
	var alert: AlertDirector = AlertDirector.of(get_tree())
	var piece: TargetPiece3D = _piece(&"sensor")
	heist.targets.assign([piece.piece_id])
	var box: PowerBox3D = piece.power_box
	assert_not_null(box, "La pieza de sensor tiene su cuadro")
	assert_string_contains(piece.get_interaction_text(map.thief), "a lo bruto", "Con corriente")
	map.thief.global_position = box.global_position + Vector3(1.0, 0.05, 0.0)
	box.interact(map.thief)
	_run(box, RULES.cut_time + 0.5)
	assert_true(box.is_cut)
	for node: Node in get_tree().get_nodes_in_group(&"lamps"):
		var lamp: Lamp3D = node as Lamp3D
		if box.circuits.has(lamp.circuit_id):
			assert_false(lamp.is_switched_on, "Ala a oscuras")
	piece.interact(map.thief)
	assert_true(piece.stolen)
	assert_eq(alert.level, AlertDirector.Level.CALM, "Sin alarma")
	for guard: GuardController3D in map.guards:  # salen de la garita, lejos del panel
		guard.global_position = map.thief.global_position + Vector3(0.0, 0.0, 40.0)
	alert.scan()
	assert_false(box.noticed, "Nadie ha visto el piloto")
	var panel: Node3D = map.find_child("PilotPanel", true, false) as Node3D
	map.guards[0].global_position = panel.global_position + Vector3(1.0, 0.05, 0.0)
	alert.scan()
	assert_true(box.noticed, "El piloto avisa")
	assert_eq(alert.discovered_count(), 1)
	map.guards[0].global_position = box.global_position + Vector3(1.0, 0.05, 0.0)
	assert_true(box.can_interact(map.guards[0]))
	box.interact(map.guards[0])
	_run(box, RULES.restore_time + 0.5)
	assert_false(box.is_cut, "Restablecida")
	for node: Node in get_tree().get_nodes_in_group(&"lamps"):
		var lamp: Lamp3D = node as Lamp3D
		if box.circuits.has(lamp.circuit_id):
			assert_eq(lamp.is_switched_on, lamp.start_on, "Las luces vuelven a como estaban")
	assert_true(box.noticed, "Pero el rastro sigue")


func test_replica_table_does_not_hide_a_piece_and_hints() -> void:
	var map: HeistMap3D = _map()
	await wait_physics_frames(2)
	var table: Node3D = map.find_child("ReplicaTable", true, false) as Node3D
	for node: Node in get_tree().get_nodes_in_group(&"heist_targets"):
		var piece: TargetPiece3D = node as TargetPiece3D
		assert_gt(piece.global_position.distance_to(table.global_position), 2.0, piece.piece_name)
		assert_ne(ContractList84.hint(piece), "", "Cada pieza dice cómo robarla")
	assert_eq(ContractList84.hint(_piece(&"pressure")), "pieza de pega del taller")
