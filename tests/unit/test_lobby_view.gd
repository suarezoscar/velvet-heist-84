extends GutTest
## Lobby mínimo para servidor dedicado (FEAT-014 PKG-4).

var _menu: MainMenu = null
var _saved_players: Dictionary = {}


func before_each() -> void:
	_saved_players = NetManager.connected_players
	_menu = (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate() as MainMenu
	add_child_autofree(_menu)


func after_each() -> void:
	NetManager.connected_players = _saved_players


func test_hay_boton_de_guardia_3() -> void:
	assert_not_null(_menu.find_child("RoleGuard3Button", true, false), "botón de guard_3")
	assert_true(_menu.lobby_view.host_btn.visible, "Se puede crear partida (FEAT-040)")
	assert_eq(_menu.lobby_view.host_btn.text, "CREAR PARTIDA")


func test_preparado_hace_falta_todos_y_bandos() -> void:
	NetManager.connected_players = {}
	NetManager.player_list_updated.emit()
	assert_true(_menu.lobby_view.start_match_btn.disabled, "Sin conexión no se puede")
	assert_eq(_menu.lobby_view.start_match_btn.text, "PREPARADO")
	var players: Dictionary = {
		2: {"peer_id": 2, "role": &"thief", "ready": true, "name": "x"},
	}
	assert_false(NetLobbyReady.all_ready(players), "Sin guardias no empieza")
	players[3] = {"peer_id": 3, "role": &"guard_1", "ready": false}
	assert_false(NetLobbyReady.all_ready(players), "Falta que el guardia esté preparado")
	players[3]["ready"] = true
	assert_true(NetLobbyReady.all_ready(players), "Todos preparados: empieza")
	players[4] = {"peer_id": 4, "role": &"", "ready": true}
	assert_false(NetLobbyReady.all_ready(players), "Alguien sin bando: no")
	NetLobbyReady.clear(players)
	for peer: int in players:
		assert_false(players[peer]["ready"], "Cambia el equipo: todos a confirmar")
