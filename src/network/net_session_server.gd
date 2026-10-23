## Lado servidor de NetSession (FEAT-014): valida input y acciones, simula la autoridad
## del mundo y replica estado propio, snapshots filtrados, mundo, partida y ruido.
## Lo usa NetSession cuando multiplayer.is_server() es verdadero.
class_name NetSessionServer
extends RefCounted

const NOISE_FEEDBACK: NoiseFeedbackProfile = preload("res://data/balance/noise_feedback.tres")
const PRIVATE_SUFFIX: String = "#private"

var _session: NetSession = null
var _ready_peers: Dictionary = {}
var _last_tick: Dictionary = {}
var _snapshot_timer: float = 0.0
var _world_timer: float = 0.0
var _game_timer: float = 0.0
var _world_nodes: Dictionary = {}
var _world_states: Dictionary = {}
var _private_states: Dictionary = {}
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
		var taken: bool = role != &"" and NetManager.get_peer_id_for_role(role) != 0
		map.guards[index].is_ai_controlled = not taken
	if not SignalBus.noise_event_3d.is_connected(_on_noise_event):
		SignalBus.noise_event_3d.connect(_on_noise_event)
	NetTestHooks.create(map)


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
	if actor == null:
		return
	if tick <= int(_last_tick.get(peer, -1)):
		return
	_last_tick[peer] = tick
	actor.apply_input(NetInputRules.sanitize(actor, move, sprint, sneak, look))


## Ejecuta una acción discreta validada del peer sobre su propio actor
func on_action(peer: int, action: StringName) -> void:
	if not NetInputRules.is_valid_action(action):
		return
	var actor: PlayerBase3D = _actor_for_peer(peer)
	if actor == null:
		return
	actor.perform_action(action)


## Un cliente ha cargado el mapa: recibe el estado completo y empieza a recibir ticks
func on_client_ready(peer: int) -> void:
	if _ready_peers.has(peer):
		return
	_ready_peers[peer] = true
	_last_tick[peer] = -1
	_scan_world_nodes()
	var full: Dictionary = {}
	for path: String in _world_nodes:
		var node: Node = _world_nodes[path]
		if is_instance_valid(node):
			full[path] = node.get_net_state()
	for path: String in _removed_paths:
		full[path] = {"removed": true}
	if not full.is_empty():
		_session.send_world_state(peer, full)
		_log_world(peer, full)
	var private_state: Dictionary = _collect_private_states(true)
	if not private_state.is_empty():
		_session.send_world_state(peer, private_state)
		_log_world(peer, private_state)
	var game_state: Dictionary = GameManager.get_net_state()
	_last_game_state = game_state
	_game_timer = 0.0
	_session.send_game_state(peer, game_state)
	NetTestHooks.log_event({"event": "game", "peer": peer, "state": game_state})


func _actor_for_peer(peer: int) -> PlayerBase3D:
	if _session == null or not _ready_peers.has(peer):
		return null
	var role: StringName = NetManager.get_role_for_peer(peer)
	if role == &"":
		return null
	return _session.actor_for_role(role)


func _guard_role(index: int) -> StringName:
	var role_index: int = index + 1
	if role_index >= NetConfig.ROLES.size():
		return &""
	return NetConfig.ROLES[role_index]


func _send_own_states() -> void:
	for peer: int in _ready_peers:
		var actor: PlayerBase3D = _actor_for_peer(peer)
		if actor == null:
			continue
		var state: Dictionary = actor.get_net_actor_state()
		_session.send_own_state(peer, state)
		NetTestHooks.log_event(
			{"event": "own_state", "peer": peer, "pos": _vec3_to_array(state["pos"])}
		)


func _send_snapshots() -> void:
	var perceiving: Dictionary = {}
	var map: HeistMap3D = _session.map
	for index: int in range(map.guards.size()):
		var guard_role: StringName = _guard_role(index)
		if guard_role != &"":
			perceiving[guard_role] = map.guards[index].is_perceiving_thief
	for peer: int in _ready_peers:
		var role: StringName = NetManager.get_role_for_peer(peer)
		if role == &"":
			continue
		var roles: Array[StringName] = NetVisibility.roles_visible_to(role, perceiving)
		var states: Dictionary = {}
		var sent_roles: Array[String] = []
		for visible_role: StringName in roles:
			var actor: PlayerBase3D = _session.actor_for_role(visible_role)
			if actor != null:
				states[visible_role] = actor.get_net_actor_state()
				sent_roles.append(String(visible_role))
		_session.send_snapshot(peer, _now(), states)
		NetTestHooks.log_event({"event": "sent_snapshot", "peer": peer, "roles": sent_roles})


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
	var private_changes: Dictionary = _collect_private_states(false)
	if private_changes.is_empty():
		return
	var thief_peer: int = NetManager.get_peer_id_for_role(&"thief")
	if thief_peer != 0 and _ready_peers.has(thief_peer):
		_session.send_world_state(thief_peer, private_changes)
		_log_world(thief_peer, private_changes)


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
	var map: HeistMap3D = _session.map
	for node: Node in map.get_tree().get_nodes_in_group(&"net_state"):
		var path: String = _path_of(node)
		if path.is_empty() or _world_nodes.has(path):
			continue
		_world_nodes[path] = node
		node.tree_exiting.connect(_on_node_exiting.bind(path), CONNECT_ONE_SHOT)


func _path_of(node: Node) -> String:
	var map: HeistMap3D = _session.map
	var scene: Node = map.get_tree().current_scene
	if scene == null or node == null:
		return ""
	return String(scene.get_path_to(node))


func _on_node_exiting(path: String) -> void:
	_world_nodes.erase(path)
	_world_states.erase(path)
	_private_states.erase(path)
	_removed_paths[path] = true


func _collect_private_states(full: bool) -> Dictionary:
	var result: Dictionary = {}
	for path: String in _world_nodes:
		var node: Node = _world_nodes[path]
		if not (node is SafeBox3D):
			continue
		var state: Dictionary = (node as SafeBox3D).get_net_state_private()
		if not full and _private_states.get(path) == state:
			continue
		_private_states[path] = state
		result["%s%s" % [path, PRIVATE_SUFFIX]] = state
	return result


func _on_noise_event(
	pos: Vector3, radius: float, team: StringName, category: StringName, emitter: Node
) -> void:
	if _ready_peers.is_empty():
		return
	var emitter_role: StringName = _session.role_for_actor(emitter)
	var surface_mult: float = 1.0
	if emitter is PlayerBase3D:
		var detector: SurfaceDetector3D = (emitter as PlayerBase3D).surface_detector
		if detector != null:
			surface_mult = detector.get_surface_noise_multiplier()
	for peer: int in _ready_peers:
		var listener: PlayerBase3D = _session.actor_for_role(NetManager.get_role_for_peer(peer))
		var reaches: bool = PerceptionRules.noise_reaches(
			listener, pos, radius, team, NOISE_FEEDBACK.thief_hearing_mult
		)
		if not reaches:
			continue
		_session.send_noise(peer, pos, radius, team, category, emitter_role, surface_mult)
		NetTestHooks.log_event({"event": "noise", "peer": peer})


func _log_world(peer: int, changes: Dictionary) -> void:
	NetTestHooks.log_event({"event": "world", "peer": peer, "paths": changes.keys()})


func _vec3_to_array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
