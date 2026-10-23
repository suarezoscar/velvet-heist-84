## @file net_manager.gd
## Gestor de red: ENetMultiplayerPeer, servidor dedicado, clientes y roles (FEAT-014).
class_name NetManagerNode
extends Node

signal server_started
signal connection_succeeded
signal connection_failed
signal server_disconnected
signal player_connected(peer_id: int, player_info: Dictionary)
signal player_disconnected(peer_id: int)
signal player_list_updated
signal match_started

const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 4

## Roles del PoC (FEAT-014): ladrón y dos guardias; ROLE_GUARD_3 no es asignable.
const ROLE_THIEF: StringName = &"thief"
const ROLE_GUARD_1: StringName = &"guard_1"
const ROLE_GUARD_2: StringName = &"guard_2"
const ROLE_GUARD_3: StringName = &"guard_3"
const AVAILABLE_ROLES: Array[StringName] = NetConfig.ROLES

var connected_players: Dictionary = {}

## Rol asignado al jugador local (&"thief", &"guard_1", &"guard_2" o &"" si no tiene)
var local_role: StringName = &""

var is_dedicated_server: bool = false


func _ready() -> void:
	_check_cli_arguments()


func _check_cli_arguments() -> void:
	var args: PackedStringArray = OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	var port: int = DEFAULT_PORT
	for i: int in range(args.size()):
		if args[i] == "--port" and i + 1 < args.size():
			port = args[i + 1].to_int()
	if not (args.has("--server") or args.has("--dedicated")):
		return
	print("[NetManager] Modo Servidor Dedicado detectado por CLI en puerto %d" % port)
	is_dedicated_server = true
	call_deferred(&"start_dedicated_server", port)


## Inicia el servidor dedicado headless
func start_dedicated_server(port: int = DEFAULT_PORT) -> Error:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		var err_str: String = error_string(err)
		push_error("[NetManager] Error al crear servidor dedicado en %d: %s" % [port, err_str])
		return err

	multiplayer.multiplayer_peer = peer
	_setup_network_signals()
	is_dedicated_server = true
	local_role = &""
	connected_players.clear()
	print("[NetManager] Servidor dedicado iniciado con exito en puerto %d" % port)
	server_started.emit()
	return OK


## Host fuera del PoC: el servidor es siempre dedicado (FEAT-014). No crea nada.
func start_host(_port: int = DEFAULT_PORT, _max_players: int = MAX_PLAYERS) -> Error:
	push_warning("[NetManager] start_host fuera del PoC: usa un servidor dedicado")
	return ERR_UNAVAILABLE


## Se conecta a un servidor remoto
func join_server(ip: String = "127.0.0.1", port: int = DEFAULT_PORT) -> Error:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(ip, port)
	if err != OK:
		push_error("[NetManager] Error al conectar a %s:%d: %s" % [ip, port, error_string(err)])
		return err

	multiplayer.multiplayer_peer = peer
	_setup_network_signals()
	is_dedicated_server = false
	connected_players.clear()
	local_role = &""
	return OK


## Desconecta la sesion de red activa
func disconnect_network() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	connected_players.clear()
	local_role = &""
	is_dedicated_server = false
	print("[NetManager] Red desconectada.")


func _setup_network_signals() -> void:
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)


func _on_peer_connected(id: int) -> void:
	print("[NetManager] Peer conectado: ", id)
	if multiplayer.is_server():
		var assigned_role: StringName = NetRoleRegistry.next_available_role(connected_players)
		connected_players[id] = {
			"peer_id": id, "role": assigned_role, "ready": false, "name": "Agente_%d" % id
		}
		_sync_player_list.rpc(connected_players)
		player_connected.emit(id, connected_players[id])
		player_list_updated.emit()


func _on_peer_disconnected(id: int) -> void:
	print("[NetManager] Peer desconectado: ", id)
	if connected_players.has(id):
		connected_players.erase(id)
		player_disconnected.emit(id)
		player_list_updated.emit()
		if multiplayer.is_server() and multiplayer.get_peers().size() > 0:
			_sync_player_list.rpc(connected_players)


func _on_connected_to_server() -> void:
	print("[NetManager] Conectado exitosamente al servidor.")
	connection_succeeded.emit()


func _on_connection_failed() -> void:
	print("[NetManager] Fallo al conectar con el servidor.")
	disconnect_network()
	connection_failed.emit()


func _on_server_disconnected() -> void:
	print("[NetManager] Desconectado del servidor.")
	disconnect_network()
	server_disconnected.emit()


## Registra un jugador en la lista de conectados (utilizado al conectar o en tests unitarios)
func register_player(peer_id: int, player_name: String = "", role: StringName = &"") -> bool:
	var assigned_role: StringName = role
	if assigned_role == &"":
		assigned_role = NetRoleRegistry.next_available_role(connected_players)
	elif not is_role_available(assigned_role):
		print("[NetManager] Rol %s no disponible para peer %d" % [assigned_role, peer_id])
		return false

	var p_name: String = player_name if not player_name.is_empty() else "Agente_%d" % peer_id

	connected_players[peer_id] = {
		"peer_id": peer_id, "role": assigned_role, "ready": false, "name": p_name
	}

	if multiplayer.has_multiplayer_peer() and peer_id == multiplayer.get_unique_id():
		local_role = assigned_role

	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		if multiplayer.get_peers().size() > 0:
			_sync_player_list.rpc(connected_players)

	player_connected.emit(peer_id, connected_players[peer_id])
	player_list_updated.emit()
	return true


## Asigna un rol a un peer conectado respetando la exclusión mutua
func assign_role(peer_id: int, desired_role: StringName) -> bool:
	return _assign_role_internal(peer_id, desired_role)


func _assign_role_internal(peer_id: int, desired_role: StringName) -> bool:
	if not NetRoleRegistry.try_assign(connected_players, peer_id, desired_role):
		return false
	if multiplayer.has_multiplayer_peer() and peer_id == multiplayer.get_unique_id():
		local_role = desired_role
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		if multiplayer.get_peers().size() > 0:
			_sync_player_list.rpc(connected_players)
	player_list_updated.emit()
	return true


## Comprueba si un rol esta libre para ser elegido
func is_role_available(role: StringName) -> bool:
	return NetRoleRegistry.is_role_available(connected_players, role)


## Devuelve el peer_id asociado a un rol especifico (0 si nadie lo ocupa)
func get_peer_id_for_role(role: StringName) -> int:
	return NetRoleRegistry.peer_for_role(connected_players, role)


## Devuelve el rol asignado a un peer_id especifico (&"" si no existe)
func get_role_for_peer(peer_id: int) -> StringName:
	return NetRoleRegistry.role_for_peer(connected_players, peer_id)


## Alias de get_role_for_peer para llamadas por id
func get_role_for_peer_id(peer_id: int) -> StringName:
	return get_role_for_peer(peer_id)


@rpc("authority", "call_remote", "reliable")
func _sync_player_list(players: Dictionary) -> void:
	connected_players = players
	local_role = NetRoleRegistry.role_for_peer(players, multiplayer.get_unique_id())
	player_list_updated.emit()


## Solicita un cambio de rol al servidor
func request_role(new_role: StringName) -> bool:
	if multiplayer.multiplayer_peer == null:
		return false
	if multiplayer.is_server():
		return _assign_role_internal(multiplayer.get_unique_id(), new_role)

	_request_role_server.rpc_id(1, new_role)
	return true


@rpc("any_peer", "call_remote", "reliable")
func _request_role_server(desired_role: StringName) -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	_assign_role_internal(sender_id, desired_role)


## Inicia la operación (solo invocable por el servidor)
func launch_match() -> void:
	if not multiplayer.is_server():
		return
	_start_match_rpc.rpc()


## Pide el lanzamiento de la partida. En un cliente se lo pide al servidor;
## el servidor solo arranca si el rol de ladrón está ocupado (FEAT-014).
func request_start() -> void:
	if not is_online():
		return
	if multiplayer.is_server():
		_try_start_match()
		return
	_request_start_server.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _request_start_server() -> void:
	if not multiplayer.is_server():
		return
	_try_start_match()


func _try_start_match() -> void:
	if get_peer_id_for_role(ROLE_THIEF) == 0:
		print("[NetManager] Sin ladrón asignado: no se lanza la partida.")
		return
	launch_match()


@rpc("authority", "call_local", "reliable")
func _start_match_rpc() -> void:
	match_started.emit()
	get_tree().change_scene_to_file("res://scenes/maps/museum_velvet_84.tscn")


## Verdadero solo con una sesión ENet real (sin red Godot usa OfflineMultiplayerPeer).
func is_online() -> bool:
	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	return peer != null and not (peer is OfflineMultiplayerPeer)


func is_server_authoritative() -> bool:
	return multiplayer.multiplayer_peer != null and multiplayer.is_server()


func get_local_role() -> StringName:
	return local_role


func get_connected_players() -> Dictionary:
	return connected_players
