## @file test_steal_minigames.gd
## Robo con minijuego en la propia pieza (heist.md R9a-R9c, #119): la balanza del cambiazo, el
## piloto del sensor, Q a lo bruto, el texto de E y el estado privado de red.
extends GutTest

const MAP_SCENE: PackedScene = preload("res://scenes/maps/museum_v2.tscn")
const RULES: StealMinigameRules = preload("res://data/balance/steal_minigames.tres")
const HEIST: HeistRules = preload("res://data/balance/heist_rules.tres")

var _saved_state: GameManager.MatchState
var _actor: Node3D


func before_each() -> void:
	_saved_state = GameManager.current_state
	GameManager.current_state = GameManager.MatchState.IN_PROGRESS
	_actor = Node3D.new()
	add_child_autofree(_actor)


func after_each() -> void:
	GameManager.current_state = _saved_state


func _game(kind: StealMinigame.Kind) -> StealMinigame:
	var game: StealMinigame = StealMinigame.start(kind, _actor)
	game.rng.seed = 1
	return game


func _map() -> HeistMap3D:
	var map: HeistMap3D = MAP_SCENE.instantiate() as HeistMap3D
	add_child_autofree(map)
	for guard: GuardController3D in map.guards:
		guard.set_physics_process(false)
	return map


func _piece(protection: StringName) -> TargetPiece3D:
	for node: Node in get_tree().get_nodes_in_group(&"heist_targets"):
		var piece: TargetPiece3D = node as TargetPiece3D
		if piece.protection == protection and piece.lock == null:
			return piece
	return null


## Mapa con una pieza sin candado del tipo dado, en el encargo y con el ladrón a su lado
func _setup(protection: StringName) -> Array:
	var map: HeistMap3D = _map()
	await wait_physics_frames(2)
	var piece: TargetPiece3D = _piece(protection)
	GameManager.heist.targets.assign([piece.piece_id])
	map.thief.global_position = piece.global_position + Vector3(1.0, 0.05, 0.0)
	return [map, piece]


## Avanza la pieza con el minijuego, manteniendo la aguja en el centro
func _play(piece: TargetPiece3D, seconds: float) -> void:
	for i: int in range(roundi(seconds / 0.05)):
		if piece.game == null:
			return
		piece.game.needle = 0.0
		piece._physics_process(0.05)


# --- Lógica pura -----------------------------------------------------------


func test_swap_completes_after_swap_time() -> void:
	var game: StealMinigame = _game(StealMinigame.Kind.SWAP)
	assert_true(game.holding, "La E que abre la balanza ya está pulsada")
	for i: int in range(roundi(RULES.swap_time / 0.05) + 2):
		game.needle = 0.0
		game.tick(0.05)
	assert_true(game.is_done(), "Con E pulsada y la aguja dentro, se completa")


func test_swap_release_pauses_progress_but_needle_moves() -> void:
	var game: StealMinigame = _game(StealMinigame.Kind.SWAP)
	game.tick(0.05)
	var before: float = game.progress
	game.release()
	game.tick(0.05)
	assert_eq(game.progress, before, "Soltar E pausa el progreso")
	var needle: float = game.needle
	game.tick(0.05)
	assert_ne(game.needle, needle, "La aguja sigue yéndose")


func test_swap_needle_outside_band_fails() -> void:
	var game: StealMinigame = _game(StealMinigame.Kind.SWAP)
	game.tick(0.05)
	game.needle = RULES.needle_green_half + 0.01
	game._dir = 1.0
	game._flip_left = 10.0
	game.tick(0.05)
	assert_eq(game.fails, 1, "Fuera de la franja es un fallo")
	assert_eq(game.progress, 0.0, "El progreso vuelve a 0")
	assert_eq(game.needle, 0.0, "La aguja vuelve al centro")


func test_swap_steer_pushes_needle_and_down_cancels() -> void:
	var game: StealMinigame = _game(StealMinigame.Kind.SWAP)
	game._flip_left = 10.0
	game.steer(Vector2(1, 0))
	game._dir = -1.0
	game.tick(0.05)
	var pushed: float = game.needle
	assert_gt(pushed, 0.0, "La flecha empuja la aguja hacia +")
	game.steer(Vector2(0, 1))
	assert_eq(game.tick(0.05), StealMinigame.Result.CANCELLED, "Arriba o abajo cancela")


func test_bridge_press_while_lit_fails() -> void:
	var game: StealMinigame = _game(StealMinigame.Kind.BRIDGE)
	game.hits = 2
	game.lit = true
	game.press()
	assert_eq(game.fails, 1)
	assert_eq(game.hits, 0, "Un fallo vuelve a 0")


func test_bridge_press_while_off_counts_once_per_off() -> void:
	var game: StealMinigame = _game(StealMinigame.Kind.BRIDGE)
	game.lit = false
	game.press()
	assert_eq(game.hits, 1, "Piloto apagado: acierto")
	game.press()
	assert_eq(game.hits, 1, "Un segundo E en el mismo apagado no cuenta")
	assert_eq(game.fails, 0)


func test_bridge_completes_with_enough_hits() -> void:
	var game: StealMinigame = _game(StealMinigame.Kind.BRIDGE)
	for i: int in range(RULES.bridge_hits):
		game.lit = false
		game._pressed_this_off = false
		game.press()
	assert_true(game.is_done())


func test_bridge_any_movement_cancels() -> void:
	for move: Vector2 in [Vector2(1, 0), Vector2(0, -1), Vector2(0.5, 0.0)]:
		var game: StealMinigame = _game(StealMinigame.Kind.BRIDGE)
		game.steer(move)
		assert_eq(game.tick(0.05), StealMinigame.Result.CANCELLED, str(move))


func test_moving_away_cancels() -> void:
	var game: StealMinigame = _game(StealMinigame.Kind.SWAP)
	_actor.global_position += Vector3(HEIST.task_leash + 0.5, 0.0, 0.0)
	assert_eq(game.tick(0.05), StealMinigame.Result.CANCELLED, "Alejarse lo cancela")


# --- En la pieza -----------------------------------------------------------


func test_pressure_piece_opens_swap_and_completing_it_steals_silently() -> void:
	var setup: Array = await _setup(&"pressure")
	var map: HeistMap3D = setup[0]
	var piece: TargetPiece3D = setup[1]
	var alert: AlertDirector = AlertDirector.of(get_tree())
	piece.interact(map.thief)
	assert_true(piece.is_playing(), "E abre la balanza")
	assert_eq(piece.game.kind, StealMinigame.Kind.SWAP)
	assert_false(piece.stolen, "Abrirla no roba")
	_play(piece, RULES.swap_time + 1.0)
	assert_true(piece.stolen, "Completada, se roba")
	assert_true(piece.is_faked(), "Deja una falsificación")
	assert_false(piece.is_playing())
	assert_eq(alert.level, AlertDirector.Level.CALM, "En silencio")


func test_fake_must_be_inspected_and_authentic_gets_marked() -> void:
	var setup: Array = await _setup(&"pressure")
	var map: HeistMap3D = setup[0]
	var piece: TargetPiece3D = setup[1]
	var guard: GuardController3D = map.guards[0]
	guard.global_position = piece.global_position + Vector3(1.0, 0.05, 0.0)
	piece.interact(guard)
	for i: int in range(roundi((HEIST.inspect_time + 0.5) / 0.1)):
		piece._physics_process(0.1)
	assert_true(piece.inspected, "Examinar una auténtica la marca")
	assert_false(piece.discovered)
	assert_false(piece.can_inspect(guard), "No hace falta volver a mirarla")
	var other: TargetPiece3D = _piece(&"sensor")
	other.steal(false, TargetPieceLook.Flaw.TINT)
	assert_false(other.discovered, "Mirarla no basta")
	guard.global_position = other.global_position + Vector3(1.0, 0.05, 0.0)
	other.interact(guard)
	for i: int in range(roundi((HEIST.inspect_time + 0.5) / 0.1)):
		other._physics_process(0.1)
	assert_true(other.discovered, "Examinada: ¡falsificación!")


func test_sensor_piece_opens_bridge_and_steals_without_fake() -> void:
	var setup: Array = await _setup(&"sensor")
	var map: HeistMap3D = setup[0]
	var piece: TargetPiece3D = setup[1]
	piece.interact(map.thief)
	assert_eq(piece.game.kind, StealMinigame.Kind.BRIDGE, "E abre el puente")
	piece.game.hits = RULES.bridge_hits
	piece._physics_process(0.05)
	assert_true(piece.stolen)
	assert_false(piece.is_faked(), "Sin falsificación")
	assert_eq(TargetPiece3D.steal_method(false, TargetPieceLook.Flaw.NONE, &"sensor"), &"bridge")


func test_force_in_the_middle_abandons_and_steals_brute() -> void:
	var setup: Array = await _setup(&"pressure")
	var map: HeistMap3D = setup[0]
	var piece: TargetPiece3D = setup[1]
	piece.interact(map.thief)
	assert_true(piece.force(map.thief))
	assert_null(piece.game, "Q abandona el minijuego")
	assert_true(piece.stolen, "Y la roba a lo bruto")
	assert_eq(AlertDirector.of(get_tree()).level, AlertDirector.Level.ALARM, "Salta la alarma")


func test_dial_cancel_closes_the_minigame() -> void:
	var setup: Array = await _setup(&"sensor")
	var map: HeistMap3D = setup[0]
	var piece: TargetPiece3D = setup[1]
	piece.interact(map.thief)
	piece.minigame_action(map.thief, &"dial_cancel")
	assert_false(piece.is_playing())
	assert_false(piece.stolen)


func test_interaction_text_for_thief() -> void:
	var setup: Array = await _setup(&"pressure")
	var map: HeistMap3D = setup[0]
	var piece: TargetPiece3D = setup[1]
	assert_eq(
		piece.get_interaction_text(map.thief),
		"Dar el cambiazo [E]\nA lo bruto [Q]: salta la alarma"
	)
	var sensor: TargetPiece3D = _piece(&"sensor")
	assert_eq(
		sensor.get_interaction_text(map.thief),
		"Puentear el sensor [E]\nA lo bruto [Q]: salta la alarma"
	)
	piece.interact(map.thief)
	assert_eq(piece.get_interaction_text(map.thief), "", "Durante el minijuego, nada")


func test_private_net_state_and_client_view() -> void:
	var setup: Array = await _setup(&"pressure")
	var map: HeistMap3D = setup[0]
	var piece: TargetPiece3D = setup[1]
	assert_eq(piece.get_net_state_private(), {"game": 0})
	piece.interact(map.thief)
	var state: Dictionary = piece.get_net_state_private()
	assert_eq(int(state["game"]), int(StealMinigame.Kind.SWAP))
	var copy: TargetPiece3D = TargetPiece3D.create(&"T9", "Copia", &"pressure", null)
	add_child_autofree(copy)
	assert_false(copy.is_playing())
	var remote: Dictionary = {"game": 1, "needle": 0.2, "progress": 0.5, "holding": true}
	copy.apply_net_state(remote)
	assert_true(copy.is_playing(), "El cliente ve el minijuego")
	assert_eq(copy.minigame_view(), remote)
	copy.apply_net_state({"game": 0})
	assert_false(copy.is_playing())


func test_safe_box_texts() -> void:
	var piece: TargetPiece3D = TargetPiece3D.create(&"T8", "Joya", &"combination", null)
	add_child_autofree(piece)
	var box: SafeBox3D = SafeBox3D.new()
	add_child_autofree(box)
	box.contained_target = piece
	box.breakable = true
	box.lock_name = "vitrina"
	assert_eq(box.get_interaction_text(), "Abrir la vitrina [E]\nA lo bruto [Q]: salta la alarma")
	box.breakable = false
	box.lock_name = "caja fuerte"
	assert_eq(
		box.get_interaction_text(), "Abrir la caja fuerte [E]\nLa caja fuerte no se puede forzar"
	)


func test_thief_does_not_walk_while_playing() -> void:
	var setup: Array = await _setup(&"sensor")
	var map: HeistMap3D = setup[0]
	var piece: TargetPiece3D = setup[1]
	piece.interact(map.thief)
	map.thief.apply_input({"movement_vector": Vector2(0.5, 0.0)})
	map.thief.simulate_movement(0.1)
	var flat := Vector2(map.thief.velocity.x, map.thief.velocity.z)
	assert_almost_eq(flat.length(), 0.0, 0.001, "Quieto mientras juega")
