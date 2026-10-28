## @file test_audio.gd
## Audio (FEAT-030): buses Música y Efectos con sus volúmenes en Opciones, música de fondo
## según la escena y sonidos de cafetera y bostezo.
extends GutTest

const SETTINGS_PATH: String = "user://test_audio_settings.cfg"


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	GameSettings.load_saved().apply()


func test_buses_exist() -> void:
	assert_gt(AudioServer.get_bus_index(&"Music"), 0, "Bus de música")
	assert_gt(AudioServer.get_bus_index(&"SFX"), 0, "Bus de efectos")


func test_music_and_sfx_volumes_are_saved_and_applied() -> void:
	var settings: GameSettings = GameSettings.new()
	assert_almost_eq(settings.music_volume, 0.4, 0.001, "Música bajita por defecto")
	settings.music_volume = 0.25
	settings.sfx_volume = 0.0
	settings.save(SETTINGS_PATH)
	var loaded: GameSettings = GameSettings.load_saved(SETTINGS_PATH)
	assert_almost_eq(loaded.music_volume, 0.25, 0.001)
	assert_eq(loaded.sfx_volume, 0.0)
	loaded.apply()
	var music: int = AudioServer.get_bus_index(&"Music")
	assert_almost_eq(AudioServer.get_bus_volume_db(music), linear_to_db(0.25), 0.01)
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")), "Efectos a 0: silencio")


func test_options_panel_has_three_sliders() -> void:
	var panel: OptionsPanel = OptionsPanel.new()
	add_child_autofree(panel)
	panel.setup(GameSettings.new(), SETTINGS_PATH)
	panel.music_slider.value = 10.0
	panel.sfx_slider.value = 55.0
	var saved: GameSettings = GameSettings.load_saved(SETTINGS_PATH)
	assert_almost_eq(saved.music_volume, 0.1, 0.001, "La música se guarda al moverla")
	assert_almost_eq(saved.sfx_volume, 0.55, 0.001, "Los efectos también")


func test_track_per_scene() -> void:
	var menu: Node = Node.new()
	autofree(menu)
	assert_eq(MusicPlayer84.track_for(menu)[0], MusicPlayer84.MENU_TRACK)
	var map: HeistMap3D = HeistMap3D.new()
	autofree(map)
	assert_eq(MusicPlayer84.track_for(map)[0], MusicPlayer84.HEIST_TRACK)
	assert_lt(
		float(MusicPlayer84.track_for(map)[1]),
		float(MusicPlayer84.track_for(menu)[1]),
		"En partida, más baja"
	)


func test_coffee_and_yawn_have_sound() -> void:
	var mix: NoiseMix = load("res://assets/audio/noise_mix.tres") as NoiseMix
	assert_false(mix.streams_for(&"coffee", 1.0).is_empty(), "Cafetera")
	assert_false(mix.streams_for(&"voice", 1.0).is_empty(), "Bostezo")
