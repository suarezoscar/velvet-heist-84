## Sesión de red autoritativa del mapa (FEAT-014): superficie de RPCs y pegamento.
## La crea HeistMap3D en _ready con red, como hija del mapa y con el nombre fijo
## "NetSession", para que la ruta del nodo coincida en todos los procesos.
## Delega en NetSessionServer (proceso servidor) o NetSessionClient (proceso cliente).
class_name NetSession
extends Node

## Mapa al que sirve la sesión
var map: HeistMap3D = null

## Presentador de audio local, para reproducir los ruidos filtrados del servidor
var audio: NoiseAudioPresenter = null

## Votación de la revancha (FEAT-024)
var rematch: NetRematch = null

var _server: NetSessionServer = null
var _client: NetSessionClient = null


## Configura la sesión como servidor o como cliente según el peer local
func setup(map_ref: HeistMap3D, audio_ref: NoiseAudioPresenter) -> void:
	map = map_ref
	audio = audio_ref
	rematch = NetRematch.new()
	rematch.in_map = ready_peers
	add_child(rematch)
	if multiplayer.is_server():
		_server = NetSessionServer.new()
		_server.setup(self)
	else:
		_client = NetSessionClient.new()
		_client.setup(self)


## Peers que han cargado este mapa (en el servidor; vacío en un cliente)
func ready_peers() -> Array[int]:
	return _server.ready_peers() if _server != null else ([] as Array[int])


## Actor que ocupa un rol: thief → map.thief; guard_N → map.guards[N-1]
func actor_for_role(role: StringName) -> PlayerBase3D:
	if map == null:
		return null
	var index: int = NetConfig.ROLES.find(role)
	if index == 0:
		return map.thief
	if index > 0 and index - 1 < map.guards.size():
		return map.guards[index - 1]
	return null


## Rol que ocupa un actor (&"" si no es un actor de rol)
func role_for_actor(actor: Node) -> StringName:
	if map == null or actor == null:
		return &""
	if actor == map.thief:
		return &"thief"
	var index: int = map.guards.find(actor)
	if index >= 0 and index + 1 < NetConfig.ROLES.size():
		return NetConfig.ROLES[index + 1]
	return &""


## Envía el estado propio de un actor a su dueño
func send_own_state(peer: int, state: Dictionary) -> void:
	_client_own_state.rpc_id(peer, state)


## Envía un snapshot de actores remotos
func send_snapshot(peer: int, server_time: float, states: Dictionary) -> void:
	_client_snapshot.rpc_id(peer, server_time, states)


## Envía cambios del estado del mundo
func send_world_state(peer: int, changes: Dictionary) -> void:
	_client_world_state.rpc_id(peer, changes)


## Envía el estado de la partida
func send_game_state(peer: int, state: Dictionary) -> void:
	_client_game_state.rpc_id(peer, state)


## Envía un ruido que alcanza al actor de ese peer
func send_noise(
	peer: int,
	pos: Vector3,
	radius: float,
	team: StringName,
	category: StringName,
	emitter_role: StringName,
	surface_mult: float
) -> void:
	_client_noise.rpc_id(peer, pos, radius, team, category, emitter_role, surface_mult)


## Envía una moneda en vuelo que ve el actor de ese peer (FEAT-038)
func send_coin(peer: int, from: Vector3, landing: Vector3, flight_time: float) -> void:
	_client_coin.rpc_id(peer, from, landing, flight_time)


## Envía el input del cliente al servidor
func send_input(tick: int, move: Vector2, sprint: bool, sneak: bool, look: Vector3) -> void:
	_server_input.rpc_id(1, tick, move, sprint, sneak, look)


## Envía una acción discreta del cliente al servidor
func send_action(action: StringName) -> void:
	_server_action.rpc_id(1, action)


## Avisa al servidor de que el mapa ya está cargado en este cliente
func send_ready() -> void:
	_server_client_ready.rpc_id(1)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _server_input(tick: int, move: Vector2, sprint: bool, sneak: bool, look: Vector3) -> void:
	if _server == null or not is_inside_tree():  # mensajes que llegan al recargar el mapa
		return
	_server.on_input(multiplayer.get_remote_sender_id(), tick, move, sprint, sneak, look)


@rpc("any_peer", "call_remote", "reliable")
func _server_action(action: StringName) -> void:
	if _server == null or not is_inside_tree():  # mensajes que llegan al recargar el mapa
		return
	_server.on_action(multiplayer.get_remote_sender_id(), action)


@rpc("any_peer", "call_remote", "reliable")
func _server_client_ready() -> void:
	if _server == null or not is_inside_tree():  # mensajes que llegan al recargar el mapa
		return
	_server.on_client_ready(multiplayer.get_remote_sender_id())


@rpc("authority", "call_remote", "unreliable_ordered")
func _client_own_state(state: Dictionary) -> void:
	if _client != null:
		_client.on_own_state(state)


@rpc("authority", "call_remote", "unreliable_ordered")
func _client_snapshot(server_time: float, states: Dictionary) -> void:
	if _client != null:
		_client.on_snapshot(server_time, states)


@rpc("authority", "call_remote", "reliable")
func _client_world_state(changes: Dictionary) -> void:
	if _client != null:
		_client.on_world_state(changes)


@rpc("authority", "call_remote", "reliable")
func _client_game_state(state: Dictionary) -> void:
	if _client != null:
		_client.on_game_state(state)


@rpc("authority", "call_remote", "unreliable")
func _client_noise(
	pos: Vector3,
	radius: float,
	team: StringName,
	category: StringName,
	emitter_role: StringName,
	surface_mult: float
) -> void:
	if _client != null:
		_client.on_noise(pos, radius, team, category, emitter_role, surface_mult)


@rpc("authority", "call_remote", "unreliable")
func _client_coin(from: Vector3, landing: Vector3, flight_time: float) -> void:
	if _client != null:
		_client.on_coin(from, landing, flight_time)


func _physics_process(delta: float) -> void:
	if _server != null:
		_server.tick(delta)
	elif _client != null:
		_client.tick(delta)


func _process(delta: float) -> void:
	if _client != null:
		_client.present(delta)
