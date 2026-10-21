## @file net_manager.gd
## Gestor central de red y multijugador para 'Velvet Heist 84'.
## Maneja ENetMultiplayerPeer, modos Servidor Dedicado / Host / Cliente,
## asignación de roles asimétricos (Ladrón vs Guardias) y RPCs autoritativos.
class_name NetManagerNode
extends Node

## Puerto por defecto para conexiones ENet
const DEFAULT_PORT: int = 7777

## Número máximo de jugadores (1 ladrón + 3 guardias)
const MAX_PLAYERS: int = 4

## Señales de ciclo de vida de red
signal server_started()
signal connection_succeeded()
signal connection_failed()
signal server_disconnected()
signal player_connected(peer_id: int, player_info: Dictionary)
signal player_disconnected(peer_id: int)
signal player_list_updated()
signal match_started()

## Información de jugadores conectados { peer_id: int -> player_info: Dictionary }
var connected_players: Dictionary = {}

## Rol asignado al jugador local (&"thief", &"guard_1", &"guard_2", &"guard_3")
var local_role: StringName = &""

## Indica si esta instancia actúa como servidor dedicado headless
var is_dedicated_server: bool = false

func _ready() -> void:
	_check_cli_arguments()

## Evalúa si se pasaron argumentos de CLI para iniciar servidor dedicado headless
func _check_cli_arguments() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		args = OS.get_cmdline_args()

	var start_server: bool = false
	var port: int = DEFAULT_PORT

	for i: int in range(args.size()):
		var arg: String = args[i]
		if arg == "--server" or arg == "--dedicated":
			start_server = true
		elif arg == "--port" and i + 1 < args.size():
			port = args[i + 1].to_int()

	if start_server:
		print("[NetManager] Modo Servidor Dedicado detectado por CLI en puerto %d" % port)
		is_dedicated_server = true
		call_deferred(&"start_dedicated_server", port)

## Inicia el servidor dedicado headless
func start_dedicated_server(port: int = DEFAULT_PORT) -> Error:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		push_error("[NetManager] Error al crear servidor dedicado en puerto %d: %s" % [port, error_string(err)])
		return err

	multiplayer.multiplayer_peer = peer
	_setup_network_signals()
	print("[NetManager] Servidor dedicado iniciado con exito en puerto %d" % port)
	server_started.emit()
	return OK

## Inicia una partida como Host local
func start_host(port: int = DEFAULT_PORT, max_players: int = MAX_PLAYERS) -> Error:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, max_players)
	if err != OK:
		push_error("[NetManager] Error al crear host en puerto %d: %s" % [port, error_string(err)])
		return err

	multiplayer.multiplayer_peer = peer
	_setup_network_signals()
	
	# El host (peer 1) se registra a si mismo
	connected_players[1] = {
		"peer_id": 1,
		"role": &"thief",
		"ready": true,
		"name": "Host (Operador)"
	}
	local_role = &"thief"
	server_started.emit()
	player_list_updated.emit()
	return OK

## Se conecta a un servidor remoto
func join_server(ip: String = "127.0.0.1", port: int = DEFAULT_PORT) -> Error:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(ip, port)
	if err != OK:
		push_error("[NetManager] Error al conectar a %s:%d: %s" % [ip, port, error_string(err)])
		return err

	multiplayer.multiplayer_peer = peer
	_setup_network_signals()
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
		# Asignar siguiente rol disponible si no tiene uno
		var assigned_role: StringName = _get_next_available_role()
		connected_players[id] = {
			"peer_id": id,
			"role": assigned_role,
			"ready": false,
			"name": "Agente_%d" % id
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
		if multiplayer.is_server():
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

func _get_next_available_role() -> StringName:
	var roles_taken: Array[StringName] = []
	for p_info: Dictionary in connected_players.values():
		roles_taken.append(p_info.get("role", &""))

	if not roles_taken.has(&"thief"):
		return &"thief"
	if not roles_taken.has(&"guard_1"):
		return &"guard_1"
	if not roles_taken.has(&"guard_2"):
		return &"guard_2"
	return &"guard_3"

@rpc("authority", "call_remote", "reliable")
func _sync_player_list(players: Dictionary) -> void:
	connected_players = players
	var my_id: int = multiplayer.get_unique_id()
	if connected_players.has(my_id):
		local_role = connected_players[my_id].get("role", &"")
	player_list_updated.emit()

## Solicita un cambio de rol al servidor
func request_role(new_role: StringName) -> bool:
	if multiplayer.multiplayer_peer == null:
		return false
	if multiplayer.is_server():
		return _assign_role_internal(multiplayer.get_unique_id(), new_role)
	else:
		_request_role_server.rpc_id(1, new_role)
		return true

@rpc("any_peer", "call_remote", "reliable")
func _request_role_server(desired_role: StringName) -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	_assign_role_internal(sender_id, desired_role)

func _assign_role_internal(peer_id: int, desired_role: StringName) -> bool:
	for id: int in connected_players:
		if id != peer_id and connected_players[id].get("role") == desired_role:
			print("[NetManager] Rol %s ya ocupado por peer %d" % [desired_role, id])
			return false

	if connected_players.has(peer_id):
		connected_players[peer_id]["role"] = desired_role
		_sync_player_list.rpc(connected_players)
		player_list_updated.emit()
		return true
	return false

## Inicia la operacion (solo invocable por el servidor)
func launch_match() -> void:
	if not multiplayer.is_server():
		return
	_start_match_rpc.rpc()

@rpc("authority", "call_local", "reliable")
func _start_match_rpc() -> void:
	match_started.emit()
	get_tree().change_scene_to_file("res://scenes/maps/museum_velvet_84.tscn")

func is_server_authoritative() -> bool:
	return multiplayer.multiplayer_peer != null and multiplayer.is_server()

func get_local_role() -> StringName:
	return local_role

func get_connected_players() -> Dictionary:
	return connected_players
