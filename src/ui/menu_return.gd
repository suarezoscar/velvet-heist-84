## @file menu_return.gd
## Vuelta al menú principal desde una partida (FEAT-026): quita la pausa y el bloqueo de la
## entrada, sale de la red si la hay y cambia de escena. Un aviso opcional (por ejemplo, que se
## cayó el servidor) se queda en notice para que el menú lo enseñe en el lobby.
class_name MenuReturn
extends RefCounted

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"

## Aviso pendiente para el menú principal ("" si no hay)
static var notice: String = ""
## El menú tiene que abrir la sala de espera al cargarse (vuelta desde una partida en red)
static var lobby: bool = false


static func to_main_menu(tree: SceneTree, message: String = "") -> void:
	notice = message
	tree.paused = false
	LocalInput3D.blocked = false
	if NetManager.is_online():
		NetManager.disconnect_network()
	HostPanel84.close_hosted(tree)  # la partida creada en este equipo se cierra (FEAT-040)
	tree.change_scene_to_file(MAIN_MENU_SCENE)


## Vuelta a la sala de espera tras una partida en red (FEAT-041): sin desconectar ni cerrar la
## partida creada; el menú abre la sala y enseña el aviso (en el servidor no hay aviso)
static func to_lobby(tree: SceneTree, message: String = "") -> void:
	notice = message
	lobby = true
	tree.paused = false
	LocalInput3D.blocked = false
	tree.change_scene_to_file(MAIN_MENU_SCENE)


## Devuelve el aviso pendiente y lo borra
static func take_notice() -> String:
	var message: String = notice
	notice = ""
	return message


## true si el menú tiene que abrir la sala (y lo olvida)
static func take_lobby() -> bool:
	var open: bool = lobby
	lobby = false
	return open
