## @file net_names.gd
## Nombres de los jugadores en red (FEAT-035). Hijo «NetNames» de NetManager, así que tiene la
## misma ruta en el servidor y en los clientes. Al conectar, cada cliente manda el nombre de sus
## ajustes; el servidor lo limpia (PlayerName.clean), le pone un número si ya lo usa otro
## («Diego 2») y lo guarda en la lista de jugadores: «name» para mostrar y «chosen_name» para
## la firma del ladrón ("" si el jugador no eligió nombre).
class_name NetNames
extends Node


func _ready() -> void:
	name = "NetNames"
	NetManager.connection_succeeded.connect(_send_own_name)


func _send_own_name() -> void:
	_set_name_server.rpc_id(1, GameSettings.load_saved().player_name)


## Servidor: el jugador que manda el mensaje quiere llamarse raw
@rpc("any_peer", "call_remote", "reliable")
func _set_name_server(raw: String) -> void:
	if not multiplayer.is_server():
		return
	var peer: int = multiplayer.get_remote_sender_id()
	var players: Dictionary = NetManager.connected_players
	if not players.has(peer):
		return
	apply_name(players, peer, raw)
	NetManager._broadcast_players()
	NetManager.player_list_updated.emit()


## Pone el nombre de peer en players (lo usan los tests)
static func apply_name(players: Dictionary, peer: int, raw: String) -> void:
	var chosen: String = PlayerName.clean(raw)
	var taken: Array = []
	for other: int in players:
		if other != peer:
			taken.append(String((players[other] as Dictionary).get("name", "")))
	var shown: String = chosen if not chosen.is_empty() else "Jugador %d" % peer
	players[peer]["name"] = PlayerName.unique(shown, taken)
	players[peer]["chosen_name"] = chosen
