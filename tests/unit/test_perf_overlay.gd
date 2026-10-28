## @file test_perf_overlay.gd
## Panel de rendimiento y red (FEAT-021): texto con y sin red, colores del ping, nombres de
## rol, orden de los jugadores y el ajuste show_perf guardado.
extends GutTest

const SETTINGS_PATH: String = "user://test_perf_settings.cfg"


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	NetStats.peers.clear()


func test_offline_text_has_frame_times_only() -> void:
	var text: String = PerfOverlay84.compose(
		{"fps": 60.0, "process_ms": 2.0, "physics_ms": 1.0, "online": false}, []
	)
	assert_string_contains(text, "FPS 60")
	assert_string_contains(text, "16.7 ms")
	assert_string_contains(text, "sin red")
	assert_false(text.contains("JUGADORES"))


func test_online_client_text_has_ping_traffic_and_players() -> void:
	var players: Array[String] = [PerfOverlay84.player_line("LADRÓN", "Agente_5", 42, 0.0)]
	var text: String = (
		PerfOverlay84
		. compose(
			{
				"fps": 144.0,
				"online": true,
				"server": false,
				"rtt": 42,
				"loss": 1.6,
				"sent": 3.25,
				"received": 12.5,
				"snapshots": 20,
			},
			players
		)
	)
	assert_string_contains(text, "42 ms")
	assert_string_contains(text, "pérdida 2 %")
	assert_string_contains(text, "↑ 3.2 kB/s")
	assert_string_contains(text, "20 snap/s")
	assert_string_contains(text, "JUGADORES")
	assert_string_contains(text, "Agente_5")


func test_ping_colors() -> void:
	assert_string_contains(PerfOverlay84.ping_text(30), PerfOverlay84.OK_HEX)
	assert_string_contains(PerfOverlay84.ping_text(PerfOverlay84.PING_WARN), PerfOverlay84.WARN_HEX)
	assert_string_contains(PerfOverlay84.ping_text(PerfOverlay84.PING_BAD), PerfOverlay84.BAD_HEX)
	assert_eq(PerfOverlay84.ping_text(-1), "—", "Sin medir")


func test_role_labels() -> void:
	assert_eq(NetStatsNode.role_label(&"thief"), "LADRÓN")
	assert_eq(NetStatsNode.role_label(&"guard_2"), "GUARDIA 2")
	assert_eq(NetStatsNode.role_label(&""), "SIN BANDO")


func test_players_sorted_by_role() -> void:
	var saved: Dictionary = NetManager.connected_players.duplicate(true)
	NetManager.connected_players = {
		7: {"role": &"guard_1", "name": "B"}, 9: {"role": &"thief", "name": "A"}, 3: {}
	}
	NetStats.peers = {
		3: {"rtt": 1, "loss": 0.0}, 7: {"rtt": 1, "loss": 0.0}, 9: {"rtt": 1, "loss": 0.0}
	}
	NetStats.peers[4] = {"rtt": 1, "loss": 0.0}
	assert_eq(NetStats.sorted_peers(), [9, 7, 3] as Array[int], "El 4 ya se fue")
	NetManager.connected_players = saved


func test_show_perf_is_saved() -> void:
	var settings: GameSettings = GameSettings.new()
	settings.show_perf = true
	settings.save(SETTINGS_PATH)
	assert_true(GameSettings.load_saved(SETTINGS_PATH).show_perf)


func test_options_panel_toggle_saves() -> void:
	var panel: OptionsPanel = OptionsPanel.new()
	add_child_autofree(panel)
	panel.setup(GameSettings.new(), SETTINGS_PATH)
	panel.perf_check.button_pressed = true
	assert_true(GameSettings.load_saved(SETTINGS_PATH).show_perf)
	panel.perf_check.button_pressed = false
	PerfOverlay.set_shown(false)
