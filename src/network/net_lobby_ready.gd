## @file net_lobby_ready.gd
## «PREPARADO» en el lobby (#165). Hijo «NetLobbyReady» de NetManager (misma ruta en el
## servidor y en los clientes, como NetNames). Cada jugador marca o desmarca que está preparado;
## el servidor lo apunta en la lista de jugadores («ready») y, cuando hay un ladrón, al menos un
## guardia y todos los conectados tienen bando y están preparados, arranca la partida. Cambiar de
## bando o que entre alguien quita el «preparado» a todos (NetManager llama a clear).
class_name NetLobbyReady
extends Node


func _ready() -> void:
	name = "NetLobbyReady"


## true si se puede empezar: ladrón, algún guardia, y todos con bando y preparados
static func all_ready(players: Dictionary) -> bool:
	if not NetRoleRegistry.can_start(players):
		return false
	for peer: int in players:
		var info: Dictionary = players[peer]
		if StringName(info.get("role", &"")) == &"" or not bool(info.get("ready", false)):
			return false
	return true


## Quita el «preparado» a todos (cambio de bando o jugador nuevo)
static func clear(players: Dictionary) -> void:
	for peer: int in players:
		(players[peer] as Dictionary)["ready"] = false


## El jugador local marca (o desmarca) que está preparado
func request(is_ready: bool) -> void:
	if not NetManager.is_online():
		return
	if multiplayer.is_server():
		apply(multiplayer.get_unique_id(), is_ready)
		return
	_ready_server.rpc_id(1, is_ready)


@rpc("any_peer", "call_remote", "reliable")
func _ready_server(is_ready: bool) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and not NetManager.match_in_progress():
		if NetVersion.is_verified(sender):
			apply(sender, is_ready)


## Servidor: apunta el «preparado» de peer y arranca si ya están todos
func apply(peer: int, is_ready: bool) -> void:
	var players: Dictionary = NetManager.connected_players
	if not players.has(peer) or NetRoleRegistry.role_for_peer(players, peer) == &"":
		return
	(players[peer] as Dictionary)["ready"] = is_ready
	NetManager._broadcast_players()
	NetManager.player_list_updated.emit()
	if all_ready(players):
		NetManager._try_start_match()


## true si el jugador local está preparado
static func is_local_ready() -> bool:
	if not NetManager.multiplayer.has_multiplayer_peer() or not NetManager.is_online():
		return false
	var info: Dictionary = NetManager.get_connected_players().get(
		NetManager.multiplayer.get_unique_id(), {}
	)
	return bool(info.get("ready", false))
