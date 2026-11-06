## @file match_names.gd
## Nombres de los jugadores en el informe de la partida (MatchRecorder).
class_name MatchNames
extends RefCounted


## own_name: caché del nombre guardado en disco que lleva el recorder (null = aún sin leer)
static func thief_name(recorder: MatchRecorder) -> String:
	if NetManager.is_online():
		return player_name(NetManagerNode.ROLE_THIEF, "Ladrón")
	if recorder._own_name == null:  # se lee del disco una vez, no en cada puntuación en vivo
		recorder._own_name = GameSettings.load_saved().player_name
	var own: String = recorder._own_name
	return own if not own.is_empty() else "Tú"


static func guard_name(guard: GuardController3D) -> String:
	if not NetManager.is_online():
		return MatchRecorder.AI_NAME
	# su rol, aunque falte uno antes
	return player_name(LiveScore.guard_role(guard), MatchRecorder.AI_NAME)


static func player_name(role: StringName, fallback: String) -> String:
	var peer: int = NetManager.get_peer_id_for_role(role)
	if peer == 0:
		return fallback
	var info: Dictionary = NetManager.get_connected_players().get(peer, {})
	var found: String = String(info.get("name", ""))
	return found if not found.is_empty() else fallback
