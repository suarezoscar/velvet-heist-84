## Lado cliente de NetSession (FEAT-014): manda solo input y acciones al servidor,
## aplica el estado propio, interpola actores remotos y aplica mundo y partida.
## No simula nada: sin predicción en el PoC.
class_name NetSessionClient
extends RefCounted

const RESEND_READY: float = 0.5

var _session: NetSession = null
var _tick: int = 0
var _buffers: Dictionary = {}
var _latest: Dictionary = {}
var _world_states: Dictionary = {}
var _server_time: float = 0.0
var _server_time_local: float = 0.0
var _has_server_time: bool = false
var _nodes: Dictionary = {}
var _server_acked: bool = false
var _ready_timer: float = 0.0


## Deja el mapa en modo vista: sin IA, sin física de sistemas y listo para recibir
func setup(session: NetSession) -> void:
	_session = session
	var map: HeistMap3D = session.map
	for actor: PlayerBase3D in map.get_actors():
		if actor is GuardController3D:
			(actor as GuardController3D).is_ai_controlled = false
	_disable_guard_ai(map)
	for node: Node in map.get_tree().get_nodes_in_group(&"net_state"):
		node.set_physics_process(false)
	session.send_ready()


## Tick de física del cliente: envía input y acciones discretas del jugador local
func tick(delta: float) -> void:
	_resend_ready(delta)
	var local: PlayerBase3D = _session.map.local_player
	if local == null:
		return
	_tick += 1
	var input_data: Dictionary = local.gather_input(_session.map.camera)
	var move: Vector2 = input_data.get("movement_vector", Vector2.ZERO) as Vector2
	var look: Vector3 = input_data.get("look_target", local.look_target_position) as Vector3
	local.look_target_position = look
	var sprint: bool = bool(input_data.get("is_sprinting", false))
	var sneak: bool = bool(input_data.get("is_sneaking", false))
	_session.send_input(_tick, move, sprint, sneak, look)
	for action: StringName in _polled_actions():
		_session.send_action(action)


## Interpola los actores remotos en el instante servidor retrasado
func present(_delta: float) -> void:
	if not _has_server_time or _buffers.is_empty():
		return
	var target: float = _now_server() - NetConfig.INTERP_DELAY
	var local_role: StringName = NetManager.get_local_role()
	for role_key: StringName in _buffers:
		if role_key == local_role:
			continue
		var actor: PlayerBase3D = _session.actor_for_role(role_key)
		if actor == null:
			continue
		var state: Dictionary = _sample(role_key, target)
		if state.is_empty():
			continue
		_apply_latest_flags(role_key, state)
		actor.apply_net_actor_state(state)


## Estado propio del jugador local; la mirada se queda en la del cliente salvo sentado ante
## los monitores, donde el servidor la fija en la mesa
func on_own_state(state: Dictionary) -> void:
	_server_acked = true
	var local: PlayerBase3D = _session.map.local_player
	if local == null:
		return
	var own_state: Dictionary = state.duplicate()
	if int(own_state.get("watch", 0)) == 0:
		own_state.erase("look")
	local.apply_net_actor_state(own_state)


## Snapshot del servidor: alimenta el búfer de interpolación y el filtro del ladrón
func on_snapshot(server_time: float, states: Dictionary) -> void:
	_server_time = server_time
	_server_time_local = _now()
	_has_server_time = true
	var has_thief: bool = false
	var thief_cctv_only: bool = false
	for key in states:
		var role: StringName = StringName(key)
		if role == &"thief":
			has_thief = true
			thief_cctv_only = bool((states[key] as Dictionary).get("cctv_only", false))
		var buffer: Array = _buffers.get(role, [])
		buffer.append({"t": server_time, "s": states[key]})
		while buffer.size() > NetConfig.INTERP_BUFFER:
			buffer.pop_front()
		_buffers[role] = buffer
		_latest[role] = states[key]
	if not has_thief:
		# Sin ladrón en el snapshot: al volver a percibirlo no debe deslizarse desde la posición vieja
		_buffers.erase(&"thief")
		_latest.erase(&"thief")
	if _is_local_guard() and _session.map.thief != null:
		var mode: ThiefController3D.ViewMode = ThiefController3D.ViewMode.HIDDEN
		if has_thief:
			mode = (
				ThiefController3D.ViewMode.CCTV
				if thief_cctv_only
				else ThiefController3D.ViewMode.WORLD
			)
		_session.map.thief.set_view_mode(mode)


## Cambios del estado del mundo: aplica el nodo o lo elimina si el servidor lo quitó
func on_world_state(changes: Dictionary) -> void:
	for key in changes:
		var path: String = String(key)
		var value: Dictionary = changes[key] as Dictionary
		if path.ends_with(NetPrivateStates.SUFFIX):
			var base_path: String = path.trim_suffix(NetPrivateStates.SUFFIX)
			_merge_world_state(base_path, value)
			var private_node: Node = _resolve(base_path)
			if private_node != null:
				private_node.apply_net_state(value)
			continue
		_merge_world_state(path, value)
		var node: Node = _resolve(path)
		if node == null:
			continue
		if bool(value.get("removed", false)):
			_nodes.erase(path)
			if node is LootItem3D and (node as LootItem3D).holder_thief is ThiefController3D:
				((node as LootItem3D).holder_thief as ThiefController3D).drop_heavy_loot()
			node.queue_free()
			continue
		node.apply_net_state(value)


## Estado de la partida decidido por el servidor
func on_game_state(state: Dictionary) -> void:
	_server_acked = true
	GameManager.apply_net_state(state)


## Ruido filtrado por el servidor para el actor de este peer
func on_noise(
	pos: Vector3,
	radius: float,
	team: StringName,
	category: StringName,
	emitter_role: StringName,
	surface_mult: float
) -> void:
	if _session.audio == null:
		return
	_session.audio.handle_noise(
		pos, radius, team, category, _session.actor_for_role(emitter_role), surface_mult
	)


func _polled_actions() -> Array[StringName]:
	var actions: Array[StringName] = []
	if _just_pressed(&"interact"):
		actions.append(&"interact")
	if _just_pressed(&"toggle_flashlight"):
		actions.append(&"toggle_flashlight")
	if _just_pressed(&"strike"):
		actions.append(&"strike")
	if _just_pressed(&"crouch"):
		actions.append(&"crouch_toggle")
	var cracking: bool = _any_safe_cracking()
	if cracking and (_just_pressed(&"move_left") or _just_pressed(&"ui_left")):
		actions.append(&"dial_left")
	if cracking and (_just_pressed(&"move_right") or _just_pressed(&"ui_right")):
		actions.append(&"dial_right")
	if cracking and _just_pressed(&"ui_cancel"):
		actions.append(&"dial_cancel")
	return actions


func _just_pressed(action: StringName) -> bool:
	return InputMap.has_action(action) and Input.is_action_just_pressed(action)


func _any_safe_cracking() -> bool:
	for path: String in _world_states:
		var state: Dictionary = _world_states[path]
		if bool(state.get("cracking", false)):
			return true
	return false


func _sample(role: StringName, target: float) -> Dictionary:
	var buffer: Array = _buffers.get(role, [])
	if buffer.is_empty():
		return {}
	var older: Dictionary = buffer[0]
	var newer: Dictionary = buffer[buffer.size() - 1]
	for entry: Dictionary in buffer:
		if float(entry["t"]) <= target:
			older = entry
		if float(entry["t"]) >= target:
			newer = entry
			break
	var older_state: Dictionary = older["s"]
	var newer_state: Dictionary = newer["s"]
	var span: float = float(newer["t"]) - float(older["t"])
	var weight: float = 0.0
	if span > 0.0:
		weight = clampf((target - float(older["t"])) / span, 0.0, 1.0)
	var state: Dictionary = newer_state.duplicate()
	state["pos"] = (older_state["pos"] as Vector3).lerp(newer_state["pos"] as Vector3, weight)
	state["rot_y"] = lerp_angle(float(older_state["rot_y"]), float(newer_state["rot_y"]), weight)
	state["look"] = (older_state["look"] as Vector3).lerp(newer_state["look"] as Vector3, weight)
	return state


func _apply_latest_flags(role: StringName, state: Dictionary) -> void:
	var latest: Dictionary = _latest.get(role, {})
	for key: String in ["crouching", "flashlight"]:
		if latest.has(key):
			state[key] = latest[key]


func _merge_world_state(path: String, value: Dictionary) -> void:
	if bool(value.get("removed", false)):
		_world_states.erase(path)
		return
	var current: Dictionary = _world_states.get(path, {})
	current.merge(value, true)
	_world_states[path] = current


## Nodo de una ruta del servidor. Se guarda la primera resolución porque un reparent()
## local (el botín pesado en brazos del ladrón) cambia la ruta pero no la clave.
func _resolve(path: String) -> Node:
	var cached: Variant = _nodes.get(path)
	if is_instance_valid(cached):
		return cached as Node
	var tree: SceneTree = _session.map.get_tree()
	if tree == null or tree.current_scene == null:
		return null
	var node: Node = tree.current_scene.get_node_or_null(NodePath(path))
	if node != null:
		_nodes[path] = node
	return node


## Reenvía "listo" cada RESEND_READY s hasta que el servidor conteste (puede perderse
## si el cliente carga el mapa antes que el servidor)
func _resend_ready(delta: float) -> void:
	if _server_acked:
		return
	_ready_timer += delta
	if _ready_timer >= RESEND_READY:
		_ready_timer = 0.0
		_session.send_ready()


func _disable_guard_ai(node: Node) -> void:
	if node is GuardAI3D:
		node.process_mode = Node.PROCESS_MODE_DISABLED
	for child: Node in node.get_children():
		_disable_guard_ai(child)


func _is_local_guard() -> bool:
	return String(NetManager.get_local_role()).begins_with("guard")


func _now_server() -> float:
	return _server_time + (_now() - _server_time_local)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
