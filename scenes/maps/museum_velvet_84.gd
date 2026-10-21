## @file museum_velvet_84.gd
## Controlador del mapa principal "Museo Metropolitano 1984" (Velvet Heist 84).
## Coordina la cámara isométrica suave, la vinculación en tiempo real del sistema CCTV,
## la gestión de percepción de guardias, ondas acústicas analógicas y
## la replicación multijugador con servidor autoritativo (FEAT-003).
extends Node3D

const SoundWave3DType = preload("res://src/vfx/sound_wave_3d.gd")

## Frecuencias de replicación de red
const POS_SYNC_INTERVAL: float = 1.0 / 20.0   ## 20 Hz = 0.05s
const LOOK_SYNC_INTERVAL: float = 1.0 / 15.0  ## 15 Hz = ~0.067s

@onready var camera: Camera3D = $IsometricCamera3D
@onready var thief: CharacterBody3D = $ThiefPlayer
@onready var guard_1: CharacterBody3D = $GuardPlayer1
@onready var guard_2: CharacterBody3D = $GuardPlayer2
@onready var hud: CanvasLayer = $HUD84 if has_node("HUD84") else null

var local_player: CharacterBody3D = null
var _camera_target_pos: Vector3 = Vector3.ZERO
var _camera_offset: Vector3 = Vector3(10.0, 11.5, 10.0)

var _pos_sync_timer: float = 0.0
var _look_sync_timer: float = 0.0

func _ready() -> void:
	_hide_collision_helpers(self)
	_subscribe_acoustic_events()
	_setup_network_or_local()
	_bind_cctv_monitors()
	_start_match()

func _setup_network_or_local() -> void:
	if multiplayer.multiplayer_peer != null:
		_setup_multiplayer_network()
	else:
		_setup_local_offline()

func _setup_local_offline() -> void:
	local_player = thief
	_bind_player_cameras()
	_bind_hud()
	if thief != null:
		_camera_target_pos = thief.global_position + _camera_offset
		if camera != null:
			camera.global_position = _camera_target_pos

func _setup_multiplayer_network() -> void:
	var net_mgr: Node = get_node_or_null("/root/NetManager")
	var thief_peer: int = 1
	var guard1_peer: int = 1
	var guard2_peer: int = 1
	var local_role: StringName = &"thief"

	if net_mgr != null:
		if net_mgr.has_method("get_peer_id_for_role"):
			var tp: int = int(net_mgr.call("get_peer_id_for_role", &"thief"))
			if tp != 0:
				thief_peer = tp
			var g1p: int = int(net_mgr.call("get_peer_id_for_role", &"guard_1"))
			if g1p != 0:
				guard1_peer = g1p
			var g2p: int = int(net_mgr.call("get_peer_id_for_role", &"guard_2"))
			if g2p != 0:
				guard2_peer = g2p

		if net_mgr.has_method("get_local_role"):
			var lr: StringName = net_mgr.call("get_local_role")
			if lr != &"":
				local_role = lr

	# 1. Asignar autoridad multijugador a cada entidad según los roles de NetManager
	if thief != null:
		thief.set_multiplayer_authority(thief_peer)
	if guard_1 != null:
		guard_1.set_multiplayer_authority(guard1_peer)
		if guard1_peer != 0:
			guard_1.set("is_ai_controlled", false)
	if guard_2 != null:
		guard_2.set_multiplayer_authority(guard2_peer)
		var is_peer_human: bool = guard2_peer != 0 and guard2_peer != 1
		var is_host_guard2: bool = (
			guard2_peer == 1
			and net_mgr != null
			and not bool(net_mgr.get("is_dedicated_server"))
			and local_role == &"guard_2"
		)
		var is_g2_human: bool = is_peer_human or is_host_guard2
		guard_2.set("is_ai_controlled", not is_g2_human)

	# 2. Vincular personaje local según local_role
	match local_role:
		&"thief":
			local_player = thief
		&"guard_1":
			local_player = guard_1
		&"guard_2":
			local_player = guard_2
		_:
			local_player = thief

	_bind_player_cameras()
	_bind_hud()

	if local_player != null:
		_camera_target_pos = local_player.global_position + _camera_offset
		if camera != null:
			camera.global_position = _camera_target_pos

func _hide_collision_helpers(node: Node) -> void:
	if node is MeshInstance3D:
		if node.name.ends_with("-col") or node.name.ends_with("-colonly") or node.name == "Car" or node.name == "marble_bust":
			node.visible = false
	for child in node.get_children():
		_hide_collision_helpers(child)

func _subscribe_acoustic_events() -> void:
	var bus: Node = get_node_or_null("/root/SignalBus")
	if bus != null and bus.has_signal("noise_emitted_3d"):
		bus.connect("noise_emitted_3d", _on_noise_emitted)

func _bind_player_cameras() -> void:
	# El personaje del jugador local es el que proyecta el cursor en el plano del mapa
	if local_player != null and "camera" in local_player:
		local_player.set("camera", camera)
	elif thief != null and "camera" in thief:
		thief.set("camera", camera)

func _bind_cctv_monitors() -> void:
	var cam_1 = get_node_or_null("Props/SecurityCamera_01")
	var cam_2 = get_node_or_null("Props/SecurityCamera_02")
	var mon_1 = get_node_or_null("Props/CCTVMonitor_01")
	var mon_2 = get_node_or_null("Props/CCTVMonitor_02")
	if mon_1 != null and cam_1 != null and mon_1.has_method("bind_camera"):
		mon_1.call("bind_camera", cam_1)
	if mon_2 != null and cam_2 != null and mon_2.has_method("bind_camera"):
		mon_2.call("bind_camera", cam_2)

func _bind_hud() -> void:
	var target: Node3D = local_player if local_player != null else thief
	if hud != null and target != null:
		hud.set("target_player", target)
		var bp_overlay: Node = hud.get_node_or_null("BlueprintMapOverlay")
		if bp_overlay != null:
			bp_overlay.set("player_pawn", target)

func _start_match() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("start_match"):
		gm.call("start_match")

func _physics_process(delta: float) -> void:
	_process_camera_follow(delta)
	_process_guards_perception()
	_process_guard_melee_input()
	if multiplayer.multiplayer_peer != null:
		_process_network_sync(delta)

func _process_camera_follow(delta: float) -> void:
	var target: Node3D = local_player if local_player != null else thief
	if camera == null or target == null:
		return
	var desired_pos: Vector3 = target.global_position + _camera_offset
	camera.global_position = camera.global_position.lerp(desired_pos, 6.0 * delta)

## Evalúa detección de ambos guardias hacia el ladrón (autoritativo en servidor o local)
func _process_guards_perception() -> void:
	if thief == null:
		return

	# En partidas de red, la percepción es calculada de forma autoritativa exclusivamente por el servidor
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return

	var is_spotted: bool = false
	if guard_1 != null and guard_1.has_method("check_detection_on_thief"):
		is_spotted = is_spotted or bool(guard_1.call("check_detection_on_thief", thief))
	if guard_2 != null and guard_2.has_method("check_detection_on_thief"):
		is_spotted = is_spotted or bool(guard_2.call("check_detection_on_thief", thief))

	if thief.has_method("set_stealth_visibility"):
		thief.call("set_stealth_visibility", is_spotted)

	if is_spotted:
		var bus: Node = get_node_or_null("/root/SignalBus")
		if bus != null and bus.has_signal("thief_spotted"):
			bus.emit_signal("thief_spotted", thief.global_position)

func _process_guard_melee_input() -> void:
	var strike_pressed: bool = Input.is_action_just_pressed("strike") if InputMap.has_action("strike") else false
	if not strike_pressed:
		return

	if multiplayer.multiplayer_peer != null:
		# En multijugador, solo el guardia que tiene autoridad local puede golpear
		if local_player != null and local_player.has_method("swing_baton") and local_player.is_multiplayer_authority():
			if multiplayer.is_server():
				local_player.call("swing_baton", thief)
			else:
				var guard_role: StringName = &"guard_1" if local_player == guard_1 else &"guard_2"
				_request_baton_strike.rpc_id(1, guard_role)
	else:
		# Modo local / offline
		if guard_1 != null and guard_1.has_method("swing_baton") and thief is CharacterBody3D:
			guard_1.call("swing_baton", thief)

func _process_network_sync(delta: float) -> void:
	_pos_sync_timer += delta
	_look_sync_timer += delta

	# Replicación continua de posición y velocidad (20 Hz)
	if _pos_sync_timer >= POS_SYNC_INTERVAL:
		_pos_sync_timer = 0.0
		_broadcast_actor_pos_if_authority(&"thief", thief)
		_broadcast_actor_pos_if_authority(&"guard_1", guard_1)
		_broadcast_actor_pos_if_authority(&"guard_2", guard_2)

	# Replicación continua de dirección de mirada y cono (15 Hz)
	if _look_sync_timer >= LOOK_SYNC_INTERVAL:
		_look_sync_timer = 0.0
		_broadcast_actor_look_if_authority(&"thief", thief)
		_broadcast_actor_look_if_authority(&"guard_1", guard_1)
		_broadcast_actor_look_if_authority(&"guard_2", guard_2)

func _broadcast_actor_pos_if_authority(role: StringName, actor: CharacterBody3D) -> void:
	if actor == null or not actor.is_multiplayer_authority():
		return

	if multiplayer.is_server():
		var thief_spotted: bool = thief != null and bool(thief.get("is_detected_by_guard"))
		var net_mgr: Node = get_node_or_null("/root/NetManager")
		for peer_id: int in multiplayer.get_peers():
			# Filtrado autoritativo de visibilidad: si el ladrón no fue detectado,
			# no replicar su posición a clientes guardias
			if role == &"thief" and not thief_spotted:
				var peer_role: StringName = (
					net_mgr.call("get_role_for_peer", peer_id) if net_mgr != null else &""
				)
				if peer_role.begins_with("guard"):
					continue
			_net_sync_actor_pos.rpc_id(peer_id, role, actor.global_position, actor.velocity)
	else:
		_net_sync_actor_pos.rpc_id(1, role, actor.global_position, actor.velocity)

func _broadcast_actor_look_if_authority(role: StringName, actor: CharacterBody3D) -> void:
	if actor == null or not actor.is_multiplayer_authority():
		return

	if multiplayer.is_server():
		for peer_id: int in multiplayer.get_peers():
			_net_sync_actor_look.rpc_id(peer_id, role, actor.look_target_position, actor.rotation.y)
	else:
		_net_sync_actor_look.rpc_id(1, role, actor.look_target_position, actor.rotation.y)

@rpc("any_peer", "call_remote", "unreliable")
func _net_sync_actor_pos(role: StringName, pos: Vector3, vel: Vector3) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	var actor: CharacterBody3D = _get_actor_by_role(role)
	if actor == null:
		return

	# Validar que el remitente tiene autoridad sobre la entidad o es el servidor
	if sender_id != actor.get_multiplayer_authority() and sender_id != 1:
		print("[MuseumMap] Pos RPC rechazado: remitente %d no es autoridad" % sender_id)
		return

	if actor.has_method("set_net_transform"):
		actor.call("set_net_transform", pos, vel)
	elif "net_target_position" in actor:
		actor.set("net_target_position", pos)
		actor.set("net_target_velocity", vel)
		actor.set("is_net_interpolating", true)

	# Si es el servidor, retransmite a otros clientes respetando filtros de visibilidad
	if multiplayer.is_server():
		var thief_spotted: bool = thief != null and bool(thief.get("is_detected_by_guard"))
		var net_mgr: Node = get_node_or_null("/root/NetManager")
		for peer_id: int in multiplayer.get_peers():
			if peer_id == sender_id:
				continue
			if role == &"thief" and not thief_spotted:
				var peer_role: StringName = (
					net_mgr.call("get_role_for_peer", peer_id) if net_mgr != null else &""
				)
				if peer_role.begins_with("guard"):
					continue
			_net_sync_actor_pos.rpc_id(peer_id, role, pos, vel)

@rpc("any_peer", "call_remote", "unreliable")
func _net_sync_actor_look(role: StringName, look_target: Vector3, rot_y: float) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	var actor: CharacterBody3D = _get_actor_by_role(role)
	if actor == null:
		return

	if sender_id != actor.get_multiplayer_authority() and sender_id != 1:
		return

	actor.look_target_position = look_target
	if actor.has_method("update_presentation"):
		actor.update_presentation(0.0)

	if multiplayer.is_server():
		for peer_id: int in multiplayer.get_peers():
			if peer_id != sender_id:
				_net_sync_actor_look.rpc_id(peer_id, role, look_target, rot_y)

@rpc("any_peer", "call_remote", "reliable")
func _request_baton_strike(guard_role: StringName) -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	var guard_actor: CharacterBody3D = _get_actor_by_role(guard_role)
	if guard_actor == null:
		return
	if guard_actor.get_multiplayer_authority() != sender_id:
		print("[MuseumMap] Strike rechazado: sender %d sin autoridad" % sender_id)
		return
	if guard_actor.has_method("swing_baton") and thief != null:
		guard_actor.call("swing_baton", thief)

func _get_actor_by_role(role: StringName) -> CharacterBody3D:
	match role:
		&"thief":
			return thief
		&"guard_1":
			return guard_1
		&"guard_2":
			return guard_2
	return null

func _on_noise_emitted(pos: Vector3, radius: float, team: StringName) -> void:
	var wave: Node3D = SoundWave3DType.new()
	wave.set("max_radius", radius)
	wave.set("pulse_speed", 9.0)
	wave.set("wave_color", Color(0.3, 0.7, 1.0, 0.75) if team == &"thief" else Color(1.0, 0.4, 0.2, 0.75))
	add_child(wave)
	wave.global_position = pos + Vector3(0.0, 0.05, 0.0)
