## @file museum_velvet_84.gd
## Controlador del mapa principal "Museo Metropolitano 1984" (Velvet Heist 84).
## Añade a HeistMap3D la vinculación del sistema CCTV y la replicación multijugador
## (FEAT-003): asignación de autoridad por rol y sincronización de posición y mirada.
## Nota: hoy cada cliente simula su propio personaje y el servidor retransmite; pasar a
## servidor autoritativo real (regla 03) requiere una FEAT de red dedicada.
extends HeistMap3D

## Frecuencias de replicación de red
const POS_SYNC_INTERVAL: float = 1.0 / 20.0  ## 20 Hz = 0.05s
const LOOK_SYNC_INTERVAL: float = 1.0 / 15.0  ## 15 Hz = ~0.067s

var guard_1: GuardController3D = null
var guard_2: GuardController3D = null

var _pos_sync_timer: float = 0.0
var _look_sync_timer: float = 0.0


func _on_map_ready() -> void:
	guard_1 = get_node_or_null("GuardPlayer1") as GuardController3D
	guard_2 = get_node_or_null("GuardPlayer2") as GuardController3D
	_bind_cctv_monitors()


func _extra_hidden_mesh_names() -> Array[String]:
	return ["Car", "marble_bust"]


func _setup_online_control() -> void:
	var thief_peer: int = _peer_or_host(NetManagerNode.ROLE_THIEF)
	var guard1_peer: int = _peer_or_host(NetManagerNode.ROLE_GUARD_1)
	var guard2_peer: int = _peer_or_host(NetManagerNode.ROLE_GUARD_2)
	var local_role: StringName = NetManager.get_local_role()

	# 1. Autoridad multijugador de cada entidad según los roles de NetManager
	if thief != null:
		thief.set_multiplayer_authority(thief_peer)
	if guard_1 != null:
		guard_1.set_multiplayer_authority(guard1_peer)
		guard_1.is_ai_controlled = false
	if guard_2 != null:
		guard_2.set_multiplayer_authority(guard2_peer)
		var is_remote_human: bool = guard2_peer != 1
		var is_host_human: bool = (
			guard2_peer == 1
			and not NetManager.is_dedicated_server
			and local_role == NetManagerNode.ROLE_GUARD_2
		)
		guard_2.is_ai_controlled = not (is_remote_human or is_host_human)

	# 2. Personaje local según el rol (un servidor dedicado no controla ninguno)
	if NetManager.is_dedicated_server:
		set_local_player(null)
		return
	match local_role:
		NetManagerNode.ROLE_GUARD_1:
			set_local_player(guard_1)
		NetManagerNode.ROLE_GUARD_2:
			set_local_player(guard_2)
		_:
			set_local_player(thief)


## Peer que ocupa el rol o, si está libre, el servidor (peer 1)
func _peer_or_host(role: StringName) -> int:
	var peer: int = NetManager.get_peer_id_for_role(role)
	return peer if peer != 0 else 1


func _bind_cctv_monitors() -> void:
	var pairs: Array[Array] = [
		["Props/SecurityCamera_01", "Props/CCTVMonitor_01"],
		["Props/SecurityCamera_02", "Props/CCTVMonitor_02"],
	]
	for pair: Array in pairs:
		var cam: SecurityCamera3D = get_node_or_null(pair[0]) as SecurityCamera3D
		var monitor: CCTVMonitor3D = get_node_or_null(pair[1]) as CCTVMonitor3D
		if cam != null and monitor != null:
			monitor.bind_camera(cam)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if NetManager.is_online():
		_process_network_sync(delta)


func _perform_strike(guard: GuardController3D) -> void:
	if not NetManager.is_online() or multiplayer.is_server():
		guard.swing_baton(thief)
		return
	if guard.is_multiplayer_authority():
		_request_baton_strike.rpc_id(1, _role_of(guard))


func _role_of(actor: PlayerBase3D) -> StringName:
	if actor == guard_1:
		return NetManagerNode.ROLE_GUARD_1
	if actor == guard_2:
		return NetManagerNode.ROLE_GUARD_2
	return NetManagerNode.ROLE_THIEF


func _process_network_sync(delta: float) -> void:
	_pos_sync_timer += delta
	_look_sync_timer += delta

	# Replicación continua de posición y velocidad (20 Hz)
	if _pos_sync_timer >= POS_SYNC_INTERVAL:
		_pos_sync_timer = 0.0
		for actor: PlayerBase3D in get_actors():
			_broadcast_actor_pos_if_authority(_role_of(actor), actor)

	# Replicación continua de dirección de mirada y cono (15 Hz)
	if _look_sync_timer >= LOOK_SYNC_INTERVAL:
		_look_sync_timer = 0.0
		for actor: PlayerBase3D in get_actors():
			_broadcast_actor_look_if_authority(_role_of(actor), actor)


## Filtro de visibilidad: si el ladrón no ha sido detectado, su posición no llega a los guardias
func _should_hide_thief_from(peer_id: int) -> bool:
	if thief == null or thief.is_detected_by_guard:
		return false
	return NetManager.get_role_for_peer(peer_id).begins_with("guard")


func _broadcast_actor_pos_if_authority(role: StringName, actor: PlayerBase3D) -> void:
	if actor == null or not actor.is_multiplayer_authority():
		return
	if not multiplayer.is_server():
		_net_sync_actor_pos.rpc_id(1, role, actor.global_position, actor.velocity)
		return
	for peer_id: int in multiplayer.get_peers():
		if role == NetManagerNode.ROLE_THIEF and _should_hide_thief_from(peer_id):
			continue
		_net_sync_actor_pos.rpc_id(peer_id, role, actor.global_position, actor.velocity)


func _broadcast_actor_look_if_authority(role: StringName, actor: PlayerBase3D) -> void:
	if actor == null or not actor.is_multiplayer_authority():
		return
	if not multiplayer.is_server():
		_net_sync_actor_look.rpc_id(1, role, actor.look_target_position, actor.rotation.y)
		return
	for peer_id: int in multiplayer.get_peers():
		_net_sync_actor_look.rpc_id(peer_id, role, actor.look_target_position, actor.rotation.y)


@rpc("any_peer", "call_remote", "unreliable")
func _net_sync_actor_pos(role: StringName, pos: Vector3, vel: Vector3) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	var actor: PlayerBase3D = _get_actor_by_role(role)
	if actor == null:
		return

	# Validar que el remitente tiene autoridad sobre la entidad o es el servidor
	if sender_id != actor.get_multiplayer_authority() and sender_id != 1:
		print("[MuseumMap] Pos RPC rechazado: remitente %d no es autoridad" % sender_id)
		return

	actor.set_net_transform(pos, vel)

	# Si es el servidor, retransmite a otros clientes respetando filtros de visibilidad
	if multiplayer.is_server():
		for peer_id: int in multiplayer.get_peers():
			if peer_id == sender_id:
				continue
			if role == NetManagerNode.ROLE_THIEF and _should_hide_thief_from(peer_id):
				continue
			_net_sync_actor_pos.rpc_id(peer_id, role, pos, vel)


@rpc("any_peer", "call_remote", "unreliable")
func _net_sync_actor_look(role: StringName, look_target: Vector3, _rot_y: float) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	var actor: PlayerBase3D = _get_actor_by_role(role)
	if actor == null:
		return
	if sender_id != actor.get_multiplayer_authority() and sender_id != 1:
		return

	actor.look_target_position = look_target

	if multiplayer.is_server():
		for peer_id: int in multiplayer.get_peers():
			if peer_id != sender_id:
				_net_sync_actor_look.rpc_id(peer_id, role, look_target, _rot_y)


@rpc("any_peer", "call_remote", "reliable")
func _request_baton_strike(guard_role: StringName) -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	var guard_actor: GuardController3D = _get_actor_by_role(guard_role) as GuardController3D
	if guard_actor == null:
		return
	if guard_actor.get_multiplayer_authority() != sender_id:
		print("[MuseumMap] Strike rechazado: sender %d sin autoridad" % sender_id)
		return
	if thief != null:
		guard_actor.swing_baton(thief)


func _get_actor_by_role(role: StringName) -> PlayerBase3D:
	match role:
		NetManagerNode.ROLE_THIEF:
			return thief
		NetManagerNode.ROLE_GUARD_1:
			return guard_1
		NetManagerNode.ROLE_GUARD_2:
			return guard_2
	return null
