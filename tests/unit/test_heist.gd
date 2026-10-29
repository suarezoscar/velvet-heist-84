## @file test_heist.gd
## El golpe (heist.md, entrega 1): piezas según los guardias, sorteo del encargo, quién sabe
## qué, cómo se roba cada protección (combinación, a lo bruto), la salida y el resumen.
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
	return map


func _first(map: HeistMap3D, variant: StringName, in_contract: bool) -> TargetPiece3D:
	for node: Node in map.get_tree().get_nodes_in_group(&"heist_targets"):
		var piece: TargetPiece3D = node as TargetPiece3D
		if (
			piece.variant == variant
			and GameManager.heist.is_in_contract(piece.piece_id) == in_contract
		):
			return piece
	return null


func test_pieces_depend_on_guards() -> void:
	assert_eq(RULES.pieces_for(1, 6), 4)
	assert_eq(RULES.pieces_for(2, 6), 3)
	assert_eq(RULES.pieces_for(3, 6), 2)
	assert_eq(RULES.pieces_for(5, 6), 2, "Más guardias: el último valor")
	assert_eq(RULES.pieces_for(1, 3), 3, "Nunca más que las candidatas")


func test_draw_picks_distinct_candidates() -> void:
	var ids: Array[StringName] = [&"A", &"B", &"C", &"D", &"E", &"F"]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var picked: Array[StringName] = HeistDirector.draw(ids, 3, rng)
	assert_eq(picked.size(), 3)
	for id: StringName in picked:
		assert_has(ids, id)
		assert_eq(picked.count(id), 1, "Sin repetir")


func test_museum_contract_and_who_knows_what() -> void:
	var map: HeistMap3D = _map()
	await wait_physics_frames(2)
	var heist: HeistDirector = GameManager.heist
	assert_not_null(heist, "El museo tiene encargo")
	assert_eq(heist.candidates().size(), 20, "FEAT-034: 20 obras candidatas")
	assert_eq(heist.contract_size, 3, "Sin red: 2 guardias, 3 piezas")
	assert_false(GameManager.can_thief_escape(), "Sin piezas no hay salida")
	var public: Dictionary = heist.get_net_state()
	assert_false(public.has("targets"), "A los guardias no les llega cuáles")
	assert_false(public.has("stolen"), "Ni cuántas lleva")
	assert_eq(heist.get_net_state_private()["targets"], heist.targets, "Al ladrón, sí")
	assert_eq(heist.net_private_audience(), &"thief")
	assert_string_contains(ContractList84.compose(heist), "ENCARGO")
	assert_null(map.find_child("EscapeCar3D", true, false), "El coche ya no es la salida")


func test_steal_each_protection_and_escape() -> void:
	var map: HeistMap3D = _map()
	await wait_physics_frames(2)
	var heist: HeistDirector = GameManager.heist
	var thief: ThiefController3D = map.thief
	# Fuera del encargo no se puede tocar
	var other: TargetPiece3D = null
	for node: Node in get_tree().get_nodes_in_group(&"heist_targets"):
		if not heist.is_in_contract((node as TargetPiece3D).piece_id):
			other = node as TargetPiece3D
	assert_false(other.can_interact(thief) or other.can_force(thief), "No está en el encargo")
	if other.lock != null:
		assert_false(other.lock.can_interact(thief), "Su candado ni se activa")
	# Fuerza las tres variantes en el encargo para probar cada protección
	heist.targets = [] as Array[StringName]
	for variant: StringName in [&"pedestal", &"case", &"safe"]:
		for node: Node in get_tree().get_nodes_in_group(&"heist_targets"):
			var piece: TargetPiece3D = node as TargetPiece3D
			if piece.variant == variant:
				heist.targets.append(piece.piece_id)
				break
	heist.contract_size = 3
	var safe_piece: TargetPiece3D = _first(map, &"safe", true)
	assert_false(safe_piece.can_force(thief), "La caja fuerte no se rompe")
	safe_piece.interact(thief)
	assert_eq(
		safe_piece.lock.current_state, SafeBox3D.SafeState.CRACKING, "Cerrada: E abre el dial"
	)
	assert_false(safe_piece.stolen, "Y no la roba")
	safe_piece.lock.current_state = SafeBox3D.SafeState.OPENED
	safe_piece.interact(thief)
	assert_true(safe_piece.stolen, "Abierta, se coge en silencio")
	var case_piece: TargetPiece3D = _first(map, &"case", true)
	assert_true(case_piece.can_force(thief), "La vitrina se rompe a lo bruto")
	thief.global_position = case_piece.global_position + Vector3(1.0, 0.0, 0.0)
	await wait_physics_frames(1)
	assert_true(thief.perform_action(&"force"), "Q junto a la vitrina")
	assert_true(case_piece.stolen)
	var pedestal_piece: TargetPiece3D = _first(map, &"pedestal", true)
	pedestal_piece.interact(thief)
	assert_true(pedestal_piece.stolen, "Pedestal: E a lo bruto")
	assert_true(heist.is_complete())
	assert_true(GameManager.can_thief_escape())
	thief.global_position = map.find_child("Exit_P01", true, false).global_position
	await wait_physics_frames(3)
	assert_eq(GameManager.current_state, GameManager.MatchState.THIEF_ESCAPED, "Sale y gana")
	assert_true(heist.get_net_state().has("targets"), "Al acabar se revela el encargo")
	assert_string_contains(MatchSummary.heist_stats(heist, 120.0, 0, 2), "Encargo: 3 de 3 piezas")


func test_exit_without_contract_does_nothing() -> void:
	var map: HeistMap3D = _map()
	await wait_physics_frames(2)
	map.thief.global_position = map.find_child("Exit_P02", true, false).global_position
	await wait_physics_frames(3)
	assert_eq(GameManager.current_state, GameManager.MatchState.IN_PROGRESS, "Sin piezas, sigue")


func test_guards_see_the_letter_not_the_contract() -> void:
	var lines: Array[String] = RoleBriefing84.heist_objectives(false, [] as Array[String], 3, 10, 4)
	assert_string_contains(lines[0], "me llevaré 3 piezas")
	var thief_lines: Array[String] = RoleBriefing84.heist_objectives(
		true, ["Busto de bronce (Archivo)"] as Array[String], 3, 10, 4
	)
	assert_string_contains(thief_lines[0], "Busto de bronce")


func test_briefing_waits_for_the_contract() -> void:
	var lines: Array[String] = RoleBriefing84.heist_objectives(true, [] as Array[String], 0, 10, 4)
	assert_false(lines[0].contains("0 piezas"), "Sin encargo aún no dice «0 piezas»")
	assert_false(lines[0].contains("…."), "Ni puntuación doble")


## El encargo se sortea justo después de abrirse la tarjeta: la tarjeta acaba diciéndolo bien
func test_briefing_shows_the_drawn_contract() -> void:
	var map: HeistMap3D = _map()
	await wait_physics_frames(4)
	var card: RoleBriefing84 = map.find_child("RoleBriefing", true, false) as RoleBriefing84
	assert_not_null(card, "Tarjeta de inicio")
	var size: int = GameManager.heist.contract_size
	assert_gt(size, 0, "Hay encargo")
	assert_string_contains(card.lines_label.text, "(%d piezas)" % size)


## Jugando de verdad: el rayo del ladrón da en el área de la pieza y la E llega a su candado
func test_dial_reachable_through_the_piece() -> void:
	var map: HeistMap3D = _map()
	await wait_physics_frames(2)
	var heist: HeistDirector = GameManager.heist
	var thief: ThiefController3D = map.thief
	for variant: StringName in [&"case", &"safe"]:
		var piece: TargetPiece3D = null
		for node: Node in get_tree().get_nodes_in_group(&"heist_targets"):
			if (node as TargetPiece3D).variant == variant:
				piece = node as TargetPiece3D
		heist.targets = [piece.piece_id] as Array[StringName]
		heist.contract_size = 1
		var focused: bool = false
		for dir: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
			thief.global_position = piece.global_position + dir * 1.2
			thief.look_at(
				(
					piece.global_position
					+ Vector3(0.0, thief.global_position.y - piece.global_position.y, 0.0)
				),
				Vector3.UP
			)
			await wait_physics_frames(3)
			if thief.interactor.current_target == piece:
				focused = true
				break
		assert_true(focused, "El ladrón enfoca la pieza (%s)" % variant)
		assert_string_contains(piece.get_interaction_text(thief), "[E]", "Texto del candado")
		assert_true(thief.perform_action(&"interact"), "E abre el dial")
		assert_eq(
			piece.lock.current_state, SafeBox3D.SafeState.CRACKING, "Dial abierto (%s)" % variant
		)
		piece.lock.cancel_cracking()


## heist.md R4: con encargo, la ronda rota al acabar el tiempo es empate aunque lleve la Pieza
func test_time_out_with_broken_round_is_a_draw() -> void:
	var map: HeistMap3D = _map()
	await wait_physics_frames(2)
	var rounds: Array = get_tree().get_nodes_in_group(&"guard_round")
	for node: Node in rounds:
		(node as GuardRound).assign([1] as Array[int], [90.0] as Array[float])
	(rounds[0] as GuardRound).faults = GameManager.CLOCK_RULES.allowed_misses * rounds.size() + 1
	GameManager.has_masterpiece = true
	assert_eq(GameManager.time_expired_state(), GameManager.MatchState.TIME_EXPIRED_DRAW)
	GameManager.has_masterpiece = false
	assert_not_null(map)
