## @file game_settings.gd
## Ajustes del jugador (pantalla completa, sincronía vertical, volúmenes general, de música y
## de efectos, datos de la conexión y nombre), guardados en user://settings.cfg. El menú principal
## los carga y aplica al arrancar. La música y los efectos van a sus buses (default_bus_layout).
class_name GameSettings
extends RefCounted

const DEFAULT_PATH: String = "user://settings.cfg"
const SECTION: String = "ajustes"

var fullscreen: bool = false
var vsync: bool = true
## Volumen general lineal, de 0 a 1
var master_volume: float = 0.8
## Música de fondo, bajita por defecto (FEAT-030)
var music_volume: float = 0.4
## Efectos: ruidos, pasos, interfaz
var sfx_volume: float = 0.8
## Datos de la conexión (FEAT-021), también con F9
var show_perf: bool = false
## Nombre del jugador (FEAT-035; PlayerName); "" = sin nombre, firma «—V.»
var player_name: String = ""
## Ya se le preguntó el nombre al abrir el juego por primera vez
var name_asked: bool = false


## Lee los ajustes guardados; los que falten (o el archivo entero) quedan por defecto
static func load_saved(path: String = DEFAULT_PATH) -> GameSettings:
	var settings: GameSettings = GameSettings.new()
	var config: ConfigFile = ConfigFile.new()
	if config.load(path) != OK:
		return settings
	settings.fullscreen = bool(config.get_value(SECTION, "fullscreen", settings.fullscreen))
	settings.vsync = bool(config.get_value(SECTION, "vsync", settings.vsync))
	settings.show_perf = bool(config.get_value(SECTION, "show_perf", settings.show_perf))
	settings.player_name = PlayerName.clean(String(config.get_value(SECTION, "player_name", "")))
	settings.name_asked = bool(config.get_value(SECTION, "name_asked", settings.name_asked))
	for field: String in ["master_volume", "music_volume", "sfx_volume"]:
		settings.set(
			field, clampf(float(config.get_value(SECTION, field, settings.get(field))), 0.0, 1.0)
		)
	return settings


## Guarda los ajustes
func save(path: String = DEFAULT_PATH) -> Error:
	var config: ConfigFile = ConfigFile.new()
	config.set_value(SECTION, "fullscreen", fullscreen)
	config.set_value(SECTION, "vsync", vsync)
	config.set_value(SECTION, "master_volume", master_volume)
	config.set_value(SECTION, "music_volume", music_volume)
	config.set_value(SECTION, "sfx_volume", sfx_volume)
	config.set_value(SECTION, "show_perf", show_perf)
	config.set_value(SECTION, "player_name", player_name)
	config.set_value(SECTION, "name_asked", name_asked)
	return config.save(path)


## Aplica el volumen siempre y la ventana solo si hay pantalla (no en el servidor dedicado)
func apply() -> void:
	set_bus_volume(&"Master", master_volume)
	set_bus_volume(&"Music", music_volume)
	set_bus_volume(&"SFX", sfx_volume)
	if DisplayServer.get_name() == "headless":
		return
	PerfOverlay.set_shown(show_perf)
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)


## Volumen lineal (0..1) de un bus; 0 lo silencia. Si el bus no existe, no hace nada
static func set_bus_volume(bus_name: StringName, volume: float) -> void:
	var bus: int = AudioServer.get_bus_index(bus_name)
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, volume <= 0.0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.0001)))
