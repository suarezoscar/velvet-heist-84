## @file net_peer_events.gd
## Conexión y desconexión de peers en NetManager (FEAT-014, #165).
class_name NetPeerEvents
extends RefCounted


## Un peer se conecta: en el servidor entra en la lista, sin bando hasta que NetVersion
## acepte su versión (FEAT-025)
static func on_connected(manager: Node, id: int) -> void:
	print("[NetManager] Peer conectado: ", id)
	if manager.multiplayer.is_server():
		manager.connected_players[id] = {
			"peer_id": id, "role": &"", "ready": false, "name": "Jugador %d" % id
		}
		manager._sync_player_list.rpc(manager.connected_players)
		manager.player_connected.emit(id, manager.connected_players[id])
		manager.player_list_updated.emit()


## Un peer se va: sale de la lista y el servidor reparte la nueva
static func on_disconnected(manager: Node, id: int) -> void:
	print("[NetManager] Peer desconectado: ", id)
	if manager.connected_players.has(id):
		manager.connected_players.erase(id)
		NetLobbyReady.clear(manager.connected_players)  # #165: cambia el equipo, todos a confirmar
		manager.player_disconnected.emit(id)
		manager.player_list_updated.emit()
		if manager.multiplayer.is_server() and manager.multiplayer.get_peers().size() > 0:
			manager._sync_player_list.rpc(manager.connected_players)
