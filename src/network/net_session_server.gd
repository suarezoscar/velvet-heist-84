## Lado servidor de NetSession (FEAT-014): valida input y acciones, simula la autoridad
## del mundo y replica estado propio, snapshots filtrados, mundo, partida y ruido.
## Lo usa NetSession cuando multiplayer.is_server() es verdadero.
class_name NetSessionServer
extends RefCounted

var _session: NetSession = null
var _hooks: NetTestHooks = null
var _ready_peers: Dictionary = {}
var _last_tick: Dictionary = {}
var _peer_roles: Dictionary = {}
var _snapshot_timer: float = 0.0
var _world_timer: float = 0.0
var _game_timer: float = 0.0
var _world_nodes: Dictionary = {}
var _node_paths: Dictionary = {}
var _world_states: Dictionary = {}
var _private: NetPrivateStates = NetPrivateStates.new()
var _removed_paths: Dictionary = {}
var _announced_removals: Dictionary = {}
var _last_game_state: Dictionary = {}


## Prepara actores, IA y suscripción de ruido; monta el escenario de prueba si toca
func setup(session: NetSession) -> void:
	_session = session
	var map: HeistMap3D = session.map
	for actor: PlayerBase3D in map.get_actors():
		actor.set_multiplayer_authority(1)
		actor.is_locally_controlled = false
	for index: int in range(map.guards.size()):
		var role: StringName = _guard_role(index)
		map.guards[index].is_ai_controlled = (
			role == &"" or NetManager.get_peer_id_for_role(role) == 0
		)
	if not SignalBus.noise_event_3d.is_connected(_on_noise_event):
		SignalBus.noise_event_3d.connect(_on_noise_event)
	if not SignalBus.coin_thrown.is_connected(_on_coin_thrown):
		SignalBus.coin_thrown.connect(_on_coin_thrown)
	if not _session.multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		_session.multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	for role: StringName in NetConfig.ROLES:
		var peer_id: int = NetManager.get_peer_id_for_role(role)
		if peer_id != 0:
			_peer_roles[peer_id] = role
	_hooks = NetTestHooks.create(map)


## Peers que han cargado el mapa y reciben sus estados
func ready_peers() -> Array[int]:
	var peers: Array[int] = []
	peers.assign(_ready_peers.keys())
	return peers


## Tick autoritativo: se ejecuta después de que los actores hayan simulado
func tick(delta: float) -> void:
	_send_own_states()
	_snapshot_timer += delta
	if _snapshot_timer >= 1.0 / NetConfig.REMOTE_SNAPSHOT_HZ:
		_snapshot_timer = 0.0
		_send_snapshots()
	_world_timer += delta
	if _world_timer >= 1.0 / NetConfig.WORLD_STATE_HZ:
		_world_timer = 0.0
		_send_world_states()
	_game_timer += delta
	_send_game_state()


## Aplica el input validado de un peer a su propio actor
func on_input(
	peer: int, tick: int, move: Vector2, sprint: bool, sneak: bool, look: Vector3
) -> void:
	var actor: PlayerBase3D = _actor_for_peer(peer)
	if actor == null or tick <= int(_last_tick.get(peer, -1)):
		return
	_last_tick[peer] = tick
	actor.apply_input(NetInputRules.sanitize(actor, move, sprint, sneak, look))


## Ejecuta una acción discreta validada del peer sobre su propio actor
func on_action(peer: int, action: StringName, interaction_cursor: Vector3 = Vector3.INF) -> void:
	if not NetInputRules.is_valid_action(action) or MatchCountdown.frozen(_session.get_tree()):
		return  # #165: en la carga y el 3-2-1 no se hace nada
	var actor: PlayerBase3D = _actor_for_peer(peer)
	if actor == null:
		return
	if action == &"interact":
		actor.interaction_cursor_position = NetInputRules.sanitize_interaction_cursor(
			actor, interaction_cursor
		)
	if not HeistActions.handle(actor, action):  # moneda, walkie, luces de alarma
		actor.perform_action(action)
	if action == &"interact":
		actor.interaction_cursor_position = Vector3.INF


## Un cliente ha cargado el mapa: recibe el estado completo y empieza a recibir ticks
func on_client_ready(peer: int) -> void:
	if _ready_peers.has(peer):
		return
	_ready_peers[peer] = true
	_last_tick[peer] = -1
	_peer_roles[peer] = NetManager.get_role_for_peer(peer)  # para soltar su actor al desconectar
	_scan_world_nodes()
	var full: Dictionary = {}
	for path: String in _world_nodes:
		if is_instance_valid(_world_nodes[path]):
			full[path] = _world_nodes[path].get_net_state()
	for path: String in _removed_paths:
		full[path] = {"removed": true}
	if not full.is_empty():
		_session.send_world_state(peer, full)
		_log_world(peer, full)
	var priv: Dictionary = NetPrivateStates.for_role(
		_private.collect(_world_nodes, true), _peer_roles[peer]
	)
	if not priv.is_empty():
		_session.send_world_state(peer, priv)
		_log_world(peer, priv)
	var game_state: Dictionary = GameManager.get_net_state()
	_last_game_state = game_state
	_game_timer = 0.0
	_session.send_game_state(peer, game_state)
	NetTestHooks.log_event({"event": "game", "peer": peer, "state": game_state})


func _actor_for_peer(peer: int) -> PlayerBase3D:
	if _session == null or not _ready_peers.has(peer):
		return null
	var role: StringName = NetManager.get_role_for_peer(peer)
	return _session.actor_for_role(role) if role != &"" else null


## Un peer se va: deja de recibir y su actor se queda quieto (sin sprint ni sigilo); un guardia
## deja de contar en el informe y en los puntos (#158, heist.md casos límite de #123)
func _on_peer_disconnected(peer: int) -> void:
	_ready_peers.erase(peer)
	_last_tick.erase(peer)
	var role: StringName = _peer_roles.get(peer, &"")
	_peer_roles.erase(peer)
	NetSessionEvents.release_actor(_session, role)


func _guard_role(index: int) -> StringName:
	var role_index: int = index + 1
	return NetConfig.ROLES[role_index] if role_index < NetConfig.ROLES.size() else &""


func _send_own_states() -> void:
	for peer: int in _ready_peers:
		var actor: PlayerBase3D = _actor_for_peer(peer)
		if actor != null:
			var state: Dictionary = actor.get_net_actor_state()
			_session.send_own_state(peer, state)
			var pos: Vector3 = state["pos"]
			NetTestHooks.log_event(
				{"event": "own_state", "peer": peer, "pos": [pos.x, pos.y, pos.z]}
			)


func _send_snapshots() -> void:
	var views: Dictionary = NetSnapshots.compute_views(_session.map)
	var open: bool = GameManager.is_match_over()
	for peer: int in _ready_peers:
		var role: StringName = NetManager.get_role_for_peer(peer)
		if role != &"":
			var states: Dictionary = NetSnapshots.build(_session, role, views, open)
			_session.send_snapshot(peer, Time.get_ticks_msec() / 1000.0, states)
			NetTestHooks.log_event(
				{"event": "sent_snapshot", "peer": peer, "roles": NetSnapshots.log_roles(states)}
			)


func _send_world_states() -> void:
	_scan_world_nodes()
	var changes: Dictionary = {}
	for path: String in _world_nodes:
		var node: Node = _world_nodes[path]
		if not is_instance_valid(node):
			continue
		var state: Dictionary = node.get_net_state()
		if _world_states.get(path) != state:
			changes[path] = state
			_world_states[path] = state
	for path: String in _removed_paths:
		if not _announced_removals.has(path):
			changes[path] = {"removed": true}
			_announced_removals[path] = true
	if not changes.is_empty():
		for peer: int in _ready_peers:
			_session.send_world_state(peer, changes)
			_log_world(peer, changes)
	var private_changes: Dictionary = _private.collect(_world_nodes, false)
	if private_changes.is_empty():
		return
	for peer: int in _ready_peers:
		var mine: Dictionary = NetPrivateStates.for_role(
			private_changes, NetManager.get_role_for_peer(peer)
		)
		if not mine.is_empty():
			_session.send_world_state(peer, mine)
			_log_world(peer, mine)


func _send_game_state() -> void:
	var state: Dictionary = GameManager.get_net_state()
	var changed: bool = (
		state.get("state") != _last_game_state.get("state")
		or state.get("loot") != _last_game_state.get("loot")
		or state.get("masterpiece") != _last_game_state.get("masterpiece")
	)
	if not changed and _game_timer < 1.0 / NetConfig.GAME_TIMER_HZ:
		return
	_game_timer = 0.0
	_last_game_state = state
	for peer: int in _ready_peers:
		_session.send_game_state(peer, state)
		NetTestHooks.log_event({"event": "game", "peer": peer, "state": state})


func _scan_world_nodes() -> void:
	for node: Node in _session.map.get_tree().get_nodes_in_group(&"net_state"):
		if _node_paths.has(node):
			continue
		var path: String = _path_of(node)
		if not path.is_empty() and not _world_nodes.has(path):
			_world_nodes[path] = node
			_node_paths[node] = path
			node.tree_exiting.connect(_on_node_exiting.bind(node, path))


func _path_of(node: Node) -> String:
	var scene: Node = _session.map.get_tree().current_scene
	return "" if scene == null or node == null else String(scene.get_path_to(node))


## Un nodo sale del árbol: solo es una eliminación si de verdad se va a liberar.
## Un reparent() también emite tree_exiting y no debe borrar su ruta original.
func _on_node_exiting(node: Node, path: String) -> void:
	if not node.is_queued_for_deletion():
		return
	_world_nodes.erase(path)
	_node_paths.erase(node)
	_world_states.erase(path)
	_private.forget(path)
	_removed_paths[path] = true


func _on_noise_event(
	pos: Vector3, radius: float, team: StringName, category: StringName, emitter: Node
) -> void:
	NetSessionEvents.send_noise(_session, _ready_peers, pos, radius, team, category, emitter)


func _on_coin_thrown(from: Vector3, landing: Vector3, flight_time: float) -> void:
	NetSessionEvents.send_coin(_session, _ready_peers, from, landing, flight_time)


func _log_world(peer: int, changes: Dictionary) -> void:
	NetSessionEvents.log_world(peer, changes)
