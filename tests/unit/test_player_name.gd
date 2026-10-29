## @file test_player_name.gd
## Nombre del jugador y firma del ladrón (FEAT-035, estilo-de-textos.md §7): limpieza, inicial,
## «—V.» de reserva, nombres repetidos en red, la carta, el resumen final y la pantalla del
## primer arranque.
extends GutTest

const TMP_SETTINGS: String = "user://test_name_settings.cfg"


func after_each() -> void:
	if FileAccess.file_exists(TMP_SETTINGS):
		DirAccess.remove_absolute(TMP_SETTINGS)


func test_clean_keeps_letters_numbers_and_trims() -> void:
	assert_eq(PlayerName.clean("  Íñigo_84 "), "Íñigo_84")
	assert_eq(PlayerName.clean("Ana<script>"), "Anascript", "Sin símbolos raros")
	assert_eq(PlayerName.clean("x"), "", "Una letra no basta")
	assert_eq(PlayerName.clean("abcdefghijklmnopqrstu").length(), PlayerName.MAX_LENGTH)


func test_signature_uses_the_first_letter() -> void:
	assert_eq(PlayerName.signature("diego"), "—D.")
	assert_eq(PlayerName.signature("84 Ñandú"), "—Ñ.", "La primera letra, no un número")
	assert_eq(PlayerName.signature("1984"), "—V.", "Sin letras, —V.")
	assert_eq(PlayerName.signature(""), PlayerName.FALLBACK_SIGNATURE)


func test_repeated_names_get_a_number() -> void:
	var players: Dictionary = {
		2: {"name": "Diego", "chosen_name": "Diego"}, 3: {"name": "Jugador 3"}, 4: {"name": "x"}
	}
	NetNames.apply_name(players, 3, "Diego")
	assert_eq(players[3]["name"], "Diego 2")
	assert_eq(players[3]["chosen_name"], "Diego", "La firma sale del nombre elegido")
	NetNames.apply_name(players, 4, "!!")
	assert_eq(players[4]["name"], "x", "Sin nombre válido, se queda el que tenía")
	assert_eq(players[4]["chosen_name"], "")


func test_huge_names_are_cheap() -> void:
	var huge: String = "a".repeat(1000000)
	var start: int = Time.get_ticks_msec()
	var cleaned: String = PlayerName.clean(huge)
	assert_lt(Time.get_ticks_msec() - start, 50, "Un nombre enorme no congela a nadie")
	assert_eq(cleaned.length(), PlayerName.MAX_LENGTH)


func test_letter_and_summary_use_the_names() -> void:
	var lines: Array[String] = RoleBriefing84.heist_objectives(
		false, [] as Array[String], 3, 12, 8, "—D."
	)
	assert_string_contains(lines[0], "Con mis respetos, —D.»")
	var players: Dictionary = {
		2: {"name": "Diego", "role": NetManagerNode.ROLE_THIEF},
		3: {"name": "Ana", "role": NetManagerNode.ROLE_GUARD_1},
	}
	assert_eq(MatchSummary.players_line(players, ""), "Ladrón: Diego · Guardias: Ana")
	assert_eq(MatchSummary.players_line({}, ""), "Ladrón: tú · Guardias: el ordenador", "Sin red")


func test_first_run_panel_saves_the_name() -> void:
	var settings: GameSettings = GameSettings.new()
	var panel: NamePanel = NamePanel.new()
	add_child_autofree(panel)
	panel.setup(settings, TMP_SETTINGS)
	panel.field.text = "  Diego "
	assert_string_contains(NamePanel.preview_text(panel.field.text), "—D.")
	panel.save_button.pressed.emit()
	assert_eq(settings.player_name, "Diego")
	assert_true(settings.name_asked, "No se vuelve a preguntar")
	var saved: GameSettings = GameSettings.load_saved(TMP_SETTINGS)
	assert_eq(saved.player_name, "Diego", "Se guarda")
	panel.skip_button.pressed.emit()
	assert_eq(settings.player_name, "", "Sin nombre: firma —V.")
