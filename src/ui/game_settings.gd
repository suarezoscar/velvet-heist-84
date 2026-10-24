## @file game_settings.gd
## Ajustes del jugador (pantalla completa, sincronía vertical y volumen general), guardados en
## user://settings.cfg. El menú principal los carga y aplica al arrancar.
class_name GameSettings
extends RefCounted

const DEFAULT_PATH: String = "user://settings.cfg"
const SECTION: String = "ajustes"

var fullscreen: bool = false
var vsync: bool = true
## Volumen general lineal, de 0 a 1
var master_volume: float = 0.8


## Lee los ajustes guardados; los que falten (o el archivo entero) quedan por defecto
static func load_saved(path: String = DEFAULT_PATH) -> GameSettings:
	var settings: GameSettings = GameSettings.new()
	var config: ConfigFile = ConfigFile.new()
	if config.load(path) != OK:
		return settings
	settings.fullscreen = bool(config.get_value(SECTION, "fullscreen", settings.fullscreen))
	settings.vsync = bool(config.get_value(SECTION, "vsync", settings.vsync))
	settings.master_volume = clampf(
		float(config.get_value(SECTION, "master_volume", settings.master_volume)), 0.0, 1.0
	)
	return settings


## Guarda los ajustes
func save(path: String = DEFAULT_PATH) -> Error:
	var config: ConfigFile = ConfigFile.new()
	config.set_value(SECTION, "fullscreen", fullscreen)
	config.set_value(SECTION, "vsync", vsync)
	config.set_value(SECTION, "master_volume", master_volume)
	return config.save(path)


## Aplica el volumen siempre y la ventana solo si hay pantalla (no en el servidor dedicado)
func apply() -> void:
	var master: int = AudioServer.get_bus_index(&"Master")
	AudioServer.set_bus_mute(master, master_volume <= 0.0)
	AudioServer.set_bus_volume_db(master, linear_to_db(maxf(master_volume, 0.0001)))
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)
