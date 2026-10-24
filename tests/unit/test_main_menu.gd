## @file test_main_menu.gd
## Menú principal (FEAT-018): entradas, crédito del autor, paneles de Un jugador y Opciones,
## lobby, mapas existentes y ajustes guardados.
extends GutTest

const TEMP_SETTINGS: String = "user://test_settings.cfg"

var _menu: MainMenu = null


func before_each() -> void:
	_menu = (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate() as MainMenu
	add_child_autofree(_menu)


func after_all() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SETTINGS))


func test_entries_and_credit() -> void:
	for id: StringName in [&"single", &"multi", &"options", &"quit"]:
		assert_true(_menu.nav.buttons.has(id), "Entrada %s" % id)
	assert_eq(_menu.nav.buttons[&"single"].text, "UN JUGADOR")
	assert_eq(_menu.nav.buttons[&"multi"].text, "MULTIJUGADOR")
	assert_eq(_menu.nav.buttons[&"options"].text, "OPCIONES")
	assert_eq(_menu.credit_label.text, "Un juego de Óscar Suárez", "Crédito del autor")


func test_panels_open_and_close() -> void:
	_menu.open_section(&"single")
	assert_true(_menu.single_player.visible, "Panel Un jugador")
	_menu.open_section(&"options")
	assert_false(_menu.single_player.visible, "Un panel cada vez")
	assert_true(_menu.options.visible, "Panel Opciones")
	_menu.options.back_requested.emit()
	assert_false(_menu.options.visible, "Volver lo cierra")


func test_multiplayer_opens_lobby_and_back() -> void:
	_menu.open_section(&"multi")
	assert_true(_menu.lobby_view.visible, "Lobby visible")
	assert_false(_menu.home.visible, "El menú se oculta")
	_menu.lobby_view.back_requested.emit()
	assert_true(_menu.home.visible, "Volver al menú")
	assert_false(_menu.lobby_view.visible)


func test_single_player_maps_exist() -> void:
	assert_eq(
		SinglePlayerPanel.MAPS[0]["scene"], "res://scenes/maps/museum_v2.tscn", "Museo primero"
	)
	for data: Dictionary in SinglePlayerPanel.MAPS:
		assert_true(ResourceLoader.exists(data["scene"]), "Existe %s" % data["scene"])
		assert_true(ResourceLoader.exists(data["thumb"]), "Existe %s" % data["thumb"])


func test_lobby_texts_are_clear() -> void:
	assert_eq(_menu.lobby_view.lobby_title_lbl.text, "MULTIJUGADOR")
	assert_string_contains(_menu.lobby_view.role_thief_btn.text, "LADRÓN")
	assert_false(_menu.lobby_view.role_thief_btn.text.contains("INFILTRADO"))


func test_settings_roundtrip_and_options_save() -> void:
	var defaults: GameSettings = GameSettings.load_saved("user://no_existe.cfg")
	assert_false(defaults.fullscreen, "Por defecto, ventana")
	assert_almost_eq(defaults.master_volume, 0.8, 0.001)
	var panel: OptionsPanel = OptionsPanel.new()
	add_child_autofree(panel)
	panel.setup(GameSettings.new(), TEMP_SETTINGS)
	panel.volume_slider.value = 35.0
	panel.vsync_check.button_pressed = false
	var saved: GameSettings = GameSettings.load_saved(TEMP_SETTINGS)
	assert_almost_eq(saved.master_volume, 0.35, 0.001, "El volumen se guarda al moverlo")
	assert_false(saved.vsync, "VSync se guarda")
	var master: int = AudioServer.get_bus_index(&"Master")
	assert_almost_eq(AudioServer.get_bus_volume_db(master), linear_to_db(0.35), 0.01, "Y se aplica")
	GameSettings.new().apply()
