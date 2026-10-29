## @file net_rematch.gd
## Revancha en red (FEAT-024). Hija de NetSession con el nombre fijo «Rematch», para que su
## ruta coincida en el servidor y en los clientes. Con la partida terminada, cada jugador con
## bando que está en el mapa vota (o retira su voto); el servidor reparte el recuento y, cuando
## han votado todos y sigue habiendo ladrón y al menos un guardia, vuelve a lanzar el mapa con
## los mismos bandos. Es el único camino para relanzar con el mapa cargado: NetManager rechaza
## las peticiones de «empezar» que llegan entonces desde el lobby. También lleva a todos de
## vuelta a la sala de espera (FEAT-041) sin desconectar a nadie.
class_name NetRematch
extends Node

## Cambió el recuento (lo escucha el menú de fin de partida)
signal votes_changed(votes: int, needed: int)

## Peers que han pedido la revancha (en el servidor; en los clientes, el último recuento)
var voters: Array[int] = []
## Jugadores con bando que tienen que votar
var needed: int = 0
## Peers que han cargado el mapa (los da NetSession); null: todos los conectados (tests)
var in_map: Callable = Callable()
## Cómo se va a la sala: MenuReturn.to_lobby (los tests lo cambian para no salir del árbol)
var leave: Callable = Callable()


func _ready() -> void:
	name = "Rematch"
	if multiplayer.is_server() and not multiplayer.peer_disconnected.is_connected(_on_left):
		multiplayer.peer_disconnected.connect(_on_left)


## Vota la revancha (on) o retira el voto, desde este cliente
func vote(on: bool) -> void:
	_server_vote.rpc_id(1, on)


## true si este cliente ha votado según el último recuento
func has_voted() -> bool:
	return voters.has(multiplayer.get_unique_id())


## Peers que cuentan para la revancha: los que tienen bando y, si se da present, están en él
static func voters_expected(players: Dictionary, present: Array[int] = []) -> Array[int]:
	var peers: Array[int] = []
	for peer_id: int in players:
		var has_side: bool = StringName(players[peer_id].get("role", &"")) != &""
		if has_side and (present.is_empty() or present.has(peer_id)):
			peers.append(peer_id)
	return peers


## Cuántos peers tienen que votar
static func players_needed(players: Dictionary, present: Array[int] = []) -> int:
	return voters_expected(players, present).size()


## Lógica del servidor: registra el voto y lanza la revancha si están todos (true si la lanza)
func register_vote(peer: int, on: bool) -> bool:
	if not GameManager.is_match_over():
		return false
	var players: Dictionary = NetManager.get_connected_players()
	if not voters_expected(players, _present()).has(peer):
		return false
	voters.erase(peer)
	if on:
		voters.append(peer)
	return _check(players)


func _check(players: Dictionary) -> bool:
	var expected: Array[int] = voters_expected(players, _present())
	needed = expected.size()
	for peer: int in voters.duplicate():
		if not expected.has(peer):
			voters.erase(peer)
	_broadcast(expected)
	if needed == 0 or voters.size() < needed or not NetRoleRegistry.can_start(players):
		return false
	voters.clear()
	NetManager.request_start()
	return true


## Solo a quien está en el mapa: los del lobby no tienen este nodo
func _broadcast(expected: Array[int]) -> void:
	votes_changed.emit(voters.size(), needed)
	var connected: PackedInt32Array = multiplayer.get_peers()
	for peer: int in expected:
		if connected.has(peer):
			_client_votes.rpc_id(peer, voters, needed)


func _present() -> Array[int]:
	return in_map.call() if in_map.is_valid() else ([] as Array[int])


func _on_left(_peer: int) -> void:
	if GameManager.is_match_over():
		_check.call_deferred(NetManager.get_connected_players())


## Lleva a todos a la sala de espera para cambiar de bandos (FEAT-041), desde este cliente
func back_to_lobby() -> void:
	_server_lobby.rpc_id(1)


## Lógica del servidor: con la partida acabada, cualquiera con bando que esté en el mapa lleva
## a todos a la sala sin desconectar a nadie; el servidor vuelve a su menú para poder empezar
## otra. true si lo hace
func return_to_lobby(peer: int) -> bool:
	if not GameManager.is_match_over():
		return false
	var players: Dictionary = NetManager.get_connected_players()
	if not voters_expected(players, _present()).has(peer):
		return false
	var who: String = String(players[peer].get("name", ""))
	voters.clear()
	_client_lobby.rpc(who if not who.is_empty() else "Alguien")
	_leave("")
	return true


## Aviso de la sala al volver
static func lobby_notice(who: String) -> String:
	return "%s ha vuelto a la sala para cambiar de bandos." % who


@rpc("any_peer", "call_remote", "reliable")
func _server_lobby() -> void:
	if multiplayer.is_server():
		return_to_lobby(multiplayer.get_remote_sender_id())


@rpc("authority", "call_remote", "reliable")
func _client_lobby(who: String) -> void:
	_leave(lobby_notice(who))


func _leave(message: String) -> void:
	if leave.is_valid():
		leave.call(message)
	else:
		MenuReturn.to_lobby(get_tree(), message)


@rpc("any_peer", "call_remote", "reliable")
func _server_vote(on: bool) -> void:
	if multiplayer.is_server():
		register_vote(multiplayer.get_remote_sender_id(), on)


@rpc("authority", "call_remote", "reliable")
func _client_votes(new_voters: Array, new_needed: int) -> void:
	voters.assign(new_voters)
	needed = new_needed
	votes_changed.emit(voters.size(), needed)
