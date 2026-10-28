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
	assert_string_contains(text, "v0.1.3")
	assert_string_contains(text, "v0.1.2")
	assert_string_contains(text, NetVersionNode.DOWNLOAD_URL)


func test_server_accepts_same_and_rejects_other() -> void:
	NetManager.start_dedicated_server(7777)
	assert_true(NetVersion.check_peer(42, GameVersion.current()), "Misma versión")
	assert_false(NetVersion.check_peer(43, "9.9.9"), "Otra versión")


func test_lobby_shows_rejection_and_keeps_it_on_disconnect() -> void:
	var menu: MainMenu = (
		(load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate() as MainMenu
	)
	add_child_autofree(menu)
	NetVersion.rejection = "0.1.3"
	NetVersion.rejected.emit("0.1.3", "0.1.2")
	assert_string_contains(menu.lobby_view.conn_log_lbl.text, "v0.1.3")
	NetManager.server_disconnected.emit()
	assert_string_contains(
		menu.lobby_view.conn_log_lbl.text, "Versión distinta", "La desconexión no tapa el motivo"
	)
