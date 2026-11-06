## @file map_debug_switch.gd
## Cambio de personaje con F1-F5 en builds de depuración sin red (HeistMap3D).
class_name MapDebugSwitch
extends RefCounted


static func handle(map: HeistMap3D, event: InputEvent) -> void:
	if NetManager.is_online() or not OS.is_debug_build():
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	var index: int = HeistMap3D.DEBUG_SWITCH_KEYS.find(key_event.keycode)
	var actors: Array[PlayerBase3D] = map.get_actors()
	if index >= 0 and index < actors.size():
		if map.local_player != null and map.local_player.has_method(&"stop_watching"):
			map.local_player.call(&"stop_watching")
		var previous: GuardController3D = map.local_player as GuardController3D
		if previous != null:
			previous.is_ai_controlled = map._ai_defaults.get(previous, false)
		map.set_local_player(actors[index])
		map._update_thief_local_visibility()
		print("[HeistMap3D] Control de depuración -> %s" % actors[index].name)
		map.get_viewport().set_input_as_handled()
