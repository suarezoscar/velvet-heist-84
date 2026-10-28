## @file test_pause_menu.gd
## Pausa y vuelta al menú (FEAT-026): el menú de pausa bloquea la entrada del jugador local, no
## se abre con la partida terminada ni con el dial abierto, «Menú principal» pide confirmación,
## y el aviso de una partida cortada llega al lobby. (La pausa del árbol sin red se comprueba
## fuera de GUT, porque pausaría al propio runner.)
extends GutTest

const MAP_SCENE: PackedScene = preload("res://scenes/maps/museum_v2.tscn")

var _saved_state: GameManager.MatchState


func before_each() -> void:
	_saved_state = GameManager.current_state


func after_each() -> void:
	GameManager.current_state = _saved_state
	LocalInput3D.blocked = false
	NetManager.disconnect_network()


func _map() -> HeistMap3D:
	var map: HeistMap3D = MAP_SCENE.instantiate() as HeistMap3D
	add_child_autofree(map)
	return map


func test_blocked_input_is_neutral() -> void:
	var thief: ThiefController3D = (
		load("res://scenes/entities/thief_player.tscn").instantiate() as ThiefController3D
	)
	add_child_autofree(thief)
	thief.look_target_position = Vector3(1.0, 0.0, 2.0)
	LocalInput3D.blocked = true
	var data: Dictionary = LocalInput3D.read(thief, null)
	assert_eq(data["movement_vector"], Vector2.ZERO)
	assert_false(data["is_sprinting"])
	assert_eq(data["look_target"], Vector3(1.0, 0.0, 2.0), "Sigue mirando donde miraba")


func test_pause_menu_online_blocks_input_without_pausing() -> void:
	NetManager.start_dedicated_server(7797)
	var map: HeistMap3D = _map()
	var pause: PauseMenu84 = PauseMenu84.new()
	pause.setup(map)
	pause.open()
	assert_true(pause.visible)
	assert_true(LocalInput3D.blocked, "El personaje se queda quieto")
	assert_false(get_tree().paused, "Con red la partida sigue")
	assert_string_contains(pause.note_label.text, "sigue en marcha")
	pause.show_controls()
	assert_true(pause.controls.visible)
	pause.show_list()
	pause.close()
	assert_false(LocalInput3D.blocked)


func test_pause_closes_when_match_ends() -> void:
	NetManager.start_dedicated_server(7797)
	var pause: PauseMenu84 = PauseMenu84.new()
	pause.setup(_map())
	pause.open()
	GameManager.end_match(GameManager.MatchState.THIEF_CAPTURED)
	await wait_process_frames(1)
	assert_false(pause.visible, "Deja paso al menú de fin de partida")
	assert_false(LocalInput3D.blocked)


func test_pause_not_available_when_over_or_dial_open() -> void:
	var map: HeistMap3D = _map()
	var pause: PauseMenu84 = map.get_node("PauseMenu") as PauseMenu84
	assert_true(pause.can_open(), "En juego se puede pausar")
	map.hud.safe_dial.visible = true
	assert_false(pause.can_open(), "Con el dial abierto, Esc es para el dial")
	map.hud.safe_dial.visible = false
	GameManager.end_match(GameManager.MatchState.THIEF_CAPTURED)
	assert_false(pause.can_open(), "Al acabar manda el menú de fin de partida")


func test_menu_button_asks_for_confirmation() -> void:
	NetManager.start_dedicated_server(7797)
	var pause: PauseMenu84 = PauseMenu84.new()
	pause.setup(_map())
	pause.open()
	pause.menu_button.pressed.emit()
	assert_string_contains(pause.menu_button.text, "PULSA OTRA VEZ", "Primera pulsación")
	pause.close()


func test_lost_match_notice_reaches_lobby() -> void:
	MenuReturn.notice = "Se perdió la conexión con el servidor durante la partida."
	var menu: MainMenu = (
		(load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate() as MainMenu
	)
	add_child_autofree(menu)
	assert_true(menu.lobby_view.visible, "Se abre el lobby")
	assert_string_contains(menu.lobby_view.conn_log_lbl.text, "Se perdió la conexión")
	assert_eq(MenuReturn.notice, "", "El aviso se enseña una vez")
