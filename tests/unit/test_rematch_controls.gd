## @file test_rematch_controls.gd
## Revancha y controles (FEAT-024): el catálogo lee las teclas del InputMap, Opciones abre el
## panel de controles, el menú de fin de partida aparece al acabar y la votación de revancha
## solo cuenta a jugadores con bando y con la partida terminada.
extends GutTest

var _saved_state: GameManager.MatchState


func before_each() -> void:
	_saved_state = GameManager.current_state


func after_each() -> void:
	GameManager.current_state = _saved_state
	NetManager.disconnect_network()


func test_catalog_reads_input_map() -> void:
	assert_eq(ControlsCatalog.keys(&"toggle_perf_overlay"), "F9")
	assert_eq(ControlsCatalog.keys(&"rematch"), "R")
	assert_eq(ControlsCatalog.keys(&"toggle_blueprint"), "M / Tab")
	assert_eq(ControlsCatalog.keys(&"sprint"), "Mayús")
	assert_eq(ControlsCatalog.keys(&"strike"), "Clic izquierdo")
	assert_eq(
		ControlsCatalog.combo([&"move_up", &"move_left", &"move_down", &"move_right"]),
		"W A S D / ↑ ← ↓ →"
	)
	assert_eq(ControlsCatalog.keys(&"no_existe"), "—")


func test_options_opens_controls_panel() -> void:
	var menu: MainMenu = (
		(load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate() as MainMenu
	)
	add_child_autofree(menu)
	menu.open_section(&"options")
	menu.options.controls_button.pressed.emit()
	assert_true(menu.controls.visible, "Ver controles abre el panel")
	assert_false(menu.options.visible)
	assert_string_contains(menu.controls.rows_text(), "Datos de la conexión: F9")
	menu.controls.back_button.pressed.emit()
	assert_true(menu.options.visible, "Volver regresa a Opciones")


func test_match_end_menu_shows_only_when_over() -> void:
	var map: HeistMap3D = (
		(load("res://scenes/maps/museum_v2.tscn") as PackedScene).instantiate() as HeistMap3D
	)
	add_child_autofree(map)
	await wait_process_frames(2)
	var end_menu: MatchEndMenu84 = map.find_child("MatchEndMenu", true, false) as MatchEndMenu84
	assert_not_null(end_menu, "El panel de fin de partida tiene sus acciones")
	assert_false(end_menu.visible, "En juego no se ve")
	GameManager.end_match(GameManager.MatchState.THIEF_CAPTURED)
	await wait_process_frames(1)
	assert_true(end_menu.visible, "Al acabar aparecen Revancha y Menú principal")
	assert_false(end_menu.status_label.visible, "Sin red no hay recuento")


func test_rematch_votes_count_only_players_with_side() -> void:
	var net_mgr: NetManagerNode = NetManager
	net_mgr.start_dedicated_server(7777)
	net_mgr.register_player(2, "L", &"thief")
	net_mgr.register_player(3, "G", &"guard_1")
	net_mgr.connected_players[4] = {"peer_id": 4, "role": &"", "name": "S"}
	var vote: NetRematch = NetRematch.new()
	add_child_autofree(vote)
	assert_eq(NetRematch.players_needed(net_mgr.get_connected_players()), 2, "Sin bando no cuenta")
	GameManager.current_state = GameManager.MatchState.IN_PROGRESS
	assert_false(vote.register_vote(2, true), "En juego no se vota")
	assert_eq(vote.voters.size(), 0)
	GameManager.current_state = GameManager.MatchState.THIEF_CAPTURED
	assert_false(vote.register_vote(4, true), "Sin bando no vota")
	assert_false(vote.register_vote(2, true), "Falta un voto")
	assert_eq(vote.voters, [2] as Array[int])
	assert_eq(vote.needed, 2)
	vote.register_vote(2, false)
	assert_eq(vote.voters.size(), 0, "Se puede retirar el voto")


func test_players_in_lobby_do_not_block_rematch() -> void:
	var players: Dictionary = {
		2: {"role": &"thief"}, 3: {"role": &"guard_1"}, 5: {"role": &"guard_2"}
	}
	var in_map: Array[int] = [2, 3]
	assert_eq(NetRematch.players_needed(players, in_map), 2, "El 5 está en el lobby")
	NetManager.start_dedicated_server(7777)
	NetManager.connected_players = players
	var vote: NetRematch = NetRematch.new()
	vote.in_map = func() -> Array[int]: return in_map
	add_child_autofree(vote)
	GameManager.current_state = GameManager.MatchState.THIEF_CAPTURED
	assert_false(vote.register_vote(5, true), "Desde el lobby no se vota")
	assert_eq(vote.voters.size(), 0)
