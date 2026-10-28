## @file menu_return.gd
## Vuelta al menú principal desde una partida (FEAT-026): quita la pausa y el bloqueo de la
## entrada, sale de la red si la hay y cambia de escena. Un aviso opcional (por ejemplo, que se
## cayó el servidor) se queda en notice para que el menú lo enseñe en el lobby.
class_name MenuReturn
extends RefCounted

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"

## Aviso pendiente para el menú principal ("" si no hay)
static var notice: String = ""


static func to_main_menu(tree: SceneTree, message: String = "") -> void:
	notice = message
	tree.paused = false
	LocalInput3D.blocked = false
	if NetManager.is_online():
		NetManager.disconnect_network()
	tree.change_scene_to_file(MAIN_MENU_SCENE)


## Devuelve el aviso pendiente y lo borra
static func take_notice() -> String:
	var message: String = notice
	notice = ""
	return message
