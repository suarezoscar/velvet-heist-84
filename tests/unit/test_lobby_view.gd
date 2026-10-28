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
	assert_false(_menu.lobby_view.host_btn.visible, "Host oculto")


func test_iniciar_partida_exige_ladron_y_guardia() -> void:
	NetManager.connected_players = {}
	NetManager.player_list_updated.emit()
	assert_true(_menu.lobby_view.start_match_btn.disabled, "deshabilitado sin ladrón")
	NetManager.connected_players = {
		2: {"peer_id": 2, "role": &"thief", "ready": false, "name": "x"}
	}
	NetManager.player_list_updated.emit()
	assert_true(_menu.lobby_view.start_match_btn.disabled, "deshabilitado sin guardias")
	NetManager.connected_players[3] = {"peer_id": 3, "role": &"guard_3", "ready": false}
	NetManager.player_list_updated.emit()
	assert_false(_menu.lobby_view.start_match_btn.disabled, "habilitado con ladrón y guardia")
