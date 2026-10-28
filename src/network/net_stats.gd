## @file net_stats.gd
## Estadísticas de red para el panel de rendimiento (FEAT-021). Autoload NetStats.
## El servidor mide cada segundo el ping y la pérdida de paquetes de cada peer con ENet y se
## los reparte a todos (RPC no fiable); cada máquina mide además su propio tráfico y los
## snapshots que recibe. Sin red no mide nada. El servidor dedicado lo escribe en su consola
## cada LOG_INTERVAL segundos mientras haya jugadores.
class_name NetStatsNode
extends Node

const SAMPLE_INTERVAL: float = 1.0
const LOG_INTERVAL: float = 10.0

## peer_id → {"rtt": ms, "loss": %}, medido por el servidor (el ping de cada jugador)
var peers: Dictionary = {}
## Tráfico de esta máquina en el último segundo (kB/s)
var sent_kbps: float = 0.0
var received_kbps: float = 0.0
## Snapshots de actores recibidos en el último segundo
var snapshots_per_second: int = 0

var _timer: float = 0.0
var _log_timer: float = 0.0
var _snapshots: int = 0


func _process(delta: float) -> void:
	_timer += delta
	if _timer < SAMPLE_INTERVAL:
		return
	var elapsed: float = _timer
	_timer = 0.0
	var enet: ENetMultiplayerPeer = _enet()
	if enet == null:
		_clear()
		return
	snapshots_per_second = roundi(_snapshots / elapsed)
	_snapshots = 0
	sent_kbps = _pop(enet, ENetConnection.HOST_TOTAL_SENT_DATA) / 1024.0 / elapsed
	received_kbps = _pop(enet, ENetConnection.HOST_TOTAL_RECEIVED_DATA) / 1024.0 / elapsed
	if multiplayer.is_server():
		peers = measure(enet)
		if not peers.is_empty():
			_receive_peers.rpc(peers)
		_log_timer += elapsed
		if _log_timer >= LOG_INTERVAL and not peers.is_empty():
			_log_timer = 0.0
			print("[NetStats] %s" % "  ".join(PackedStringArray(log_lines())))


## Lo llama el cliente al recibir un snapshot de actores
func count_snapshot() -> void:
	_snapshots += 1


## Ping y pérdida de cada peer conectado al servidor
func measure(enet: ENetMultiplayerPeer) -> Dictionary:
	var result: Dictionary = {}
	for peer_id: int in multiplayer.get_peers():
		var packet_peer: ENetPacketPeer = enet.get_peer(peer_id)
		if packet_peer == null:
			continue
		result[peer_id] = {
			"rtt": roundi(packet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)),
			"loss":
			(
				packet_peer.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS)
				/ ENetPacketPeer.PACKET_LOSS_SCALE
				* 100.0
			),
		}
	return result


## Ping (ms) de esta máquina al servidor; -1 si no hay red o es el servidor
func local_rtt() -> int:
	var enet: ENetMultiplayerPeer = _enet()
	if enet == null or multiplayer.is_server():
		return -1
	var own: Dictionary = peers.get(multiplayer.get_unique_id(), {})
	if own.has("rtt"):
		return int(own["rtt"])
	var server: ENetPacketPeer = enet.get_peer(1)
	return roundi(server.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)) if server else -1


## Una línea por jugador, en el orden de los roles: «LADRÓN Agente_5 42 ms 0 %»
func log_lines() -> Array[String]:
	var lines: Array[String] = []
	var players: Dictionary = NetManager.get_connected_players()
	for peer_id: int in sorted_peers():
		var info: Dictionary = players.get(peer_id, {})
		var stats: Dictionary = peers[peer_id]
		(
			lines
			. append(
				(
					"%s %s %d ms %d %%"
					% [
						role_label(info.get("role", &"")),
						info.get("name", "peer %d" % peer_id),
						int(stats["rtt"]),
						roundi(float(stats["loss"])),
					]
				)
			)
		)
	return lines


## Peers medidos que siguen conectados, ordenados por rol (ladrón, guardias y sin bando)
func sorted_peers() -> Array[int]:
	var players: Dictionary = NetManager.get_connected_players()
	var ids: Array[int] = []
	for peer_id: int in peers:
		if players.has(peer_id):
			ids.append(peer_id)
	ids.sort_custom(
		func(a: int, b: int) -> bool: return _role_rank(players, a) < _role_rank(players, b)
	)
	return ids


## Nombre corto de un rol para el panel y la consola
static func role_label(role: StringName) -> String:
	if role == &"thief":
		return "LADRÓN"
	if String(role).begins_with("guard_"):
		return "GUARDIA " + String(role).trim_prefix("guard_")
	return "SIN BANDO"


@rpc("authority", "call_remote", "unreliable")
func _receive_peers(measured: Dictionary) -> void:
	peers = measured


static func _role_rank(players: Dictionary, peer_id: int) -> int:
	var role: StringName = (players.get(peer_id, {}) as Dictionary).get("role", &"")
	var index: int = NetConfig.ROLES.find(role)
	return index if index >= 0 else NetConfig.ROLES.size() + peer_id


func _enet() -> ENetMultiplayerPeer:
	if not NetManager.is_online():
		return null
	return multiplayer.multiplayer_peer as ENetMultiplayerPeer


func _pop(enet: ENetMultiplayerPeer, statistic: ENetConnection.HostStatistic) -> float:
	if enet.host == null:
		return 0.0
	return float(enet.host.pop_statistic(statistic))


func _clear() -> void:
	peers.clear()
	sent_kbps = 0.0
	received_kbps = 0.0
	snapshots_per_second = 0
	_snapshots = 0
