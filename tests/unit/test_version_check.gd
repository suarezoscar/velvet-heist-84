## @file test_version_check.gd
## Comprobación de versión al conectar (FEAT-025): qué versiones son compatibles, el texto del
## aviso, la decisión del servidor y lo que enseña el lobby.
extends GutTest


func after_each() -> void:
	NetManager.disconnect_network()
	NetVersion.rejection = ""


func test_only_same_version_is_compatible() -> void:
	assert_true(NetVersionNode.compatible("0.1.2", "0.1.2"))
	assert_false(NetVersionNode.compatible("0.1.1", "0.1.2"))
	assert_false(NetVersionNode.compatible("0.1.2-dev+abc", "0.1.2"), "Una local no es la release")


func test_mismatch_text_names_both_versions_and_download() -> void:
	var text: String = NetVersionNode.mismatch_text("0.1.3", "0.1.2")
	assert_string_contains(text, "versión 0.1.3")
	assert_string_contains(text, "de la 0.1.2")
	assert_string_contains(text, NetVersionNode.DOWNLOAD_URL)


func test_side_only_after_version_is_accepted() -> void:
	NetManager.start_dedicated_server(7787)
	for peer: int in [42, 43]:
		NetManager.connected_players[peer] = {"peer_id": peer, "role": &"", "name": "x"}
	assert_false(NetVersion.is_verified(42), "Recién llegado: sin verificar")
	assert_true(NetVersion.check_peer(42, GameVersion.current()), "Misma versión")
	assert_true(NetVersion.is_verified(42))
	assert_eq(NetManager.get_role_for_peer(42), &"thief", "Al aceptarlo recibe el primer bando")
	assert_false(NetVersion.check_peer(43, "9.9.9"), "Otra versión")
	assert_false(NetVersion.is_verified(43))
	assert_eq(NetManager.get_role_for_peer(43), &"", "El rechazado no recibe bando")
	assert_false(NetRoleRegistry.can_start(NetManager.get_connected_players()))


func test_silent_peer_times_out() -> void:
	NetManager.start_dedicated_server(7787)
	NetVersion.call("_on_peer_connected", 44)
	NetVersion._process(NetVersionNode.HELLO_TIMEOUT - 1.0)
	assert_true((NetVersion.get("_pending") as Dictionary).has(44), "Aún tiene tiempo")
	NetVersion._process(1.5)
	assert_false((NetVersion.get("_pending") as Dictionary).has(44), "Fuera al acabar el plazo")


func test_lobby_shows_rejection_and_keeps_it_on_disconnect() -> void:
	var menu: MainMenu = (
		(load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate() as MainMenu
	)
	add_child_autofree(menu)
	NetVersion.rejection = "0.1.3"
	NetVersion.rejected.emit("0.1.3", "0.1.2")
	assert_string_contains(menu.lobby_view.conn_log_lbl.text, "versión 0.1.3")
	NetManager.server_disconnected.emit()
	assert_string_contains(
		menu.lobby_view.conn_log_lbl.text,
		"La partida es de la versión",
		"La desconexión no tapa el motivo"
	)
