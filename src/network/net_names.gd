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
	NetManager.player_connected.connect(_on_player_connected)


## Servidor: quien entra se llama «Jugador N» (su número de llegada) hasta que mande su nombre
func _on_player_connected(peer: int, _info: Dictionary) -> void:
	var players: Dictionary = NetManager.connected_players
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and players.has(peer):
		var taken: Array = []
		for other: int in players:
			if other != peer:
				taken.append(String((players[other] as Dictionary).get("name", "")))
		if String(players[peer].get("name", "")).begins_with("Jugador "):
			players[peer]["name"] = PlayerName.unique("Jugador %d" % players.size(), taken)
			NetManager._broadcast_players()


func _send_own_name() -> void:
	_set_name_server.rpc_id(1, GameSettings.load_saved().player_name)


## Servidor: el jugador que manda el mensaje quiere llamarse raw
@rpc("any_peer", "call_remote", "reliable")
func _set_name_server(raw: String) -> void:
	if not multiplayer.is_server():
		return
	var peer: int = multiplayer.get_remote_sender_id()
	var players: Dictionary = NetManager.connected_players
	if raw.length() > PlayerName.MAX_INPUT or not players.has(peer):
		return
	if not NetVersion.is_verified(peer) or NetManager.match_in_progress():
		return  # solo en la sala de espera y con la versión comprobada
	var before: Dictionary = (players[peer] as Dictionary).duplicate()
	apply_name(players, peer, raw)
	if players[peer] == before:
		return  # el mismo nombre otra vez: nada que repartir
	NetManager._broadcast_players()
	NetManager.player_list_updated.emit()


## Pone el nombre de peer en players (lo usan los tests)
static func apply_name(players: Dictionary, peer: int, raw: String) -> void:
	var chosen: String = PlayerName.clean(raw)
	var taken: Array = []
	for other: int in players:
		if other != peer:
			taken.append(String((players[other] as Dictionary).get("name", "")))
	if chosen.is_empty():
		players[peer]["chosen_name"] = ""
		return  # sin nombre válido se queda con el «Jugador N» que le tocó al entrar
	players[peer]["name"] = PlayerName.unique(chosen, taken)
	players[peer]["chosen_name"] = chosen
