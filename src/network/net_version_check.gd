## @file net_version_check.gd
## Comprobación de versión al conectar (FEAT-025). Autoload NetVersion. El cliente manda su
## versión al servidor nada más conectar; si no coincide con la del servidor, este le contesta
## con su versión y lo desconecta medio segundo después, para que el aviso llegue antes que la
## desconexión. Un cliente que no manda su versión en HELLO_TIMEOUT (una versión anterior a esta
## comprobación) también se desconecta. El lobby enseña el motivo. Hasta que el servidor acepta
## su versión, un peer no tiene bando y NetManager ignora sus peticiones de bando y de empezar.
##
## CONTRATO CONGELADO: este nodo habla con versiones distintas, así que sus tres RPC
## (_server_hello, _client_accepted, _client_rejected), sus nombres y sus parámetros no cambian
## nunca, ni se añaden otros RPC aquí. Lo nuevo va en otro nodo.
class_name NetVersionNode
extends Node

## El servidor aceptó la versión de este cliente
signal accepted(server_version: String)
## El servidor rechazó la versión de este cliente
signal rejected(server_version: String, own_version: String)

const HELLO_TIMEOUT: float = 5.0
const KICK_DELAY: float = 0.5
const DOWNLOAD_URL: String = "github.com/suarezoscar/velvet-heist-84/releases/latest"

## Versión del servidor según su última respuesta ("" si aún no ha respondido)
var server_version: String = ""
## Versión del servidor que nos rechazó en la última conexión ("" si no nos rechazó)
var rejection: String = ""

## Peers que aún no han mandado su versión → segundos que les quedan (en el servidor)
var _pending: Dictionary = {}
## Peers cuya versión aceptó el servidor
var _verified: Dictionary = {}


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_forget)
	multiplayer.connected_to_server.connect(_on_connected_to_server)


func _process(delta: float) -> void:
	if _pending.is_empty() or not _is_server():
		return
	for peer: int in _pending.keys():
		_pending[peer] = float(_pending[peer]) - delta
		if float(_pending[peer]) <= 0.0:
			_pending.erase(peer)
			print("[NetVersion] Peer %d sin versión (anterior a la comprobación): fuera" % peer)
			_kick(peer)


## true si un cliente con esa versión puede jugar en este servidor: tienen que ser iguales
static func compatible(client_version: String, own_version: String) -> bool:
	return client_version == own_version


## Texto para el jugador rechazado
static func mismatch_text(server: String, own: String) -> String:
	return (
		"La partida es de la versión %s y tu juego, de la %s. Descargad todos la misma: %s"
		% [server, own, DOWNLOAD_URL]
	)


## true si el servidor aceptó la versión del peer (el propio servidor siempre)
func is_verified(peer: int) -> bool:
	return peer == 1 or _verified.has(peer)


## Lógica del servidor ante la versión de un peer; true si lo acepta y le da el primer bando
## libre si no hay partida
func check_peer(peer: int, version: String) -> bool:
	if not _check(peer, version):
		return false
	_verified[peer] = true
	var players: Dictionary = NetManager.get_connected_players()
	var has_side: bool = StringName((players.get(peer, {}) as Dictionary).get("role", &"")) != &""
	if players.has(peer) and not has_side and not NetManager.match_in_progress():
		NetManager.assign_role(peer, NetRoleRegistry.next_available_role(players))
	return true


## Decide sobre la versión y avisa al peer; true si es compatible
func _check(peer: int, version: String) -> bool:
	_pending.erase(peer)
	var own: String = GameVersion.current()
	var reachable: bool = multiplayer.get_peers().has(peer)
	if compatible(version, own):
		if reachable:
			_client_accepted.rpc_id(peer, own)
		return true
	print("[NetVersion] Peer %d con v%s rechazado (servidor v%s)" % [peer, version, own])
	if reachable:
		_client_rejected.rpc_id(peer, own)
		_kick.call_deferred(peer, KICK_DELAY)
	return false


func _on_peer_connected(peer: int) -> void:
	if _is_server():
		_pending[peer] = HELLO_TIMEOUT


func _forget(peer: int) -> void:
	_pending.erase(peer)
	_verified.erase(peer)


func _on_connected_to_server() -> void:
	server_version = ""
	rejection = ""
	_server_hello.rpc_id(1, GameVersion.current())


func _kick(peer: int, delay: float = 0.0) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().has(peer):
		multiplayer.multiplayer_peer.disconnect_peer(peer)


func _is_server() -> bool:
	return NetManager.is_online() and multiplayer.is_server()


@rpc("any_peer", "call_remote", "reliable")
func _server_hello(version: String) -> void:
	if _is_server():
		check_peer(multiplayer.get_remote_sender_id(), version)


@rpc("authority", "call_remote", "reliable")
func _client_accepted(version: String) -> void:
	server_version = version
	accepted.emit(version)


@rpc("authority", "call_remote", "reliable")
func _client_rejected(version: String) -> void:
	server_version = version
	rejection = version
	print("[NetVersion] Rechazado: servidor v%s, este juego v%s" % [version, GameVersion.current()])
	rejected.emit(version, GameVersion.current())
