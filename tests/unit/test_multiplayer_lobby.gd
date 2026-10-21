## @file test_multiplayer_lobby.gd
## Tests unitarios del Lobby Multijugador, Servidor Dedicado y Replicación (FEAT-003).
## Cubre la inicialización de Host y Servidor Dedicado, handshake de conexión,
## asignación y exclusión mutua de roles asimétricos, autoridad sobre entidades
## en mapa y sincronización continua desacoplada.
extends GutTest

const MAP_SCENE_PATH: String = "res://scenes/maps/museum_velvet_84.tscn"

func before_each() -> void:
	var net_mgr: NetManagerNode = get_node_or_null("/root/NetManager")
	if net_mgr != null and multiplayer.multiplayer_peer != null:
		net_mgr.disconnect_network()

func after_each() -> void:
	var net_mgr: NetManagerNode = get_node_or_null("/root/NetManager")
	if net_mgr != null and multiplayer.multiplayer_peer != null:
		net_mgr.disconnect_network()

# ------------------------------------------------------------------------------
# 1. Creación de Host y registro de peer 1
# ------------------------------------------------------------------------------

func test_start_host_registers_peer_1_as_thief() -> void:
	var net_mgr: NetManagerNode = get_node_or_null("/root/NetManager")
	assert_not_null(net_mgr, "NetManager Autoload debe existir en la escena raíz")

	var err: Error = net_mgr.start_host(7777, 4)
	assert_eq(err, OK, "start_host debe retornar OK")
	assert_not_null(multiplayer.multiplayer_peer, "multiplayer_peer asignado en multiplayer")
	assert_true(multiplayer.is_server(), "Host debe identificarse como servidor")
	assert_false(net_mgr.is_dedicated_server, "is_dedicated_server debe ser falso")
	assert_eq(net_mgr.get_local_role(), NetManagerNode.ROLE_THIEF, "Host toma rol Ladrón")
	assert_eq(net_mgr.get_peer_id_for_role(NetManagerNode.ROLE_THIEF), 1, "Peer 1 es ladrón")
	assert_true(net_mgr.is_server_authoritative(), "Host es autoritativo")

	var players: Dictionary = net_mgr.get_connected_players()
	assert_true(players.has(1), "Lista de jugadores contiene al peer 1")
	assert_eq(players[1]["role"], NetManagerNode.ROLE_THIEF, "Rol en player_info es thief")

	net_mgr.disconnect_network()
	assert_null(multiplayer.multiplayer_peer, "multiplayer_peer reseteado a null tras desconectar")
	assert_eq(net_mgr.get_local_role(), &"", "local_role limpiado")
	assert_true(net_mgr.get_connected_players().is_empty(), "connected_players vaciado")

# ------------------------------------------------------------------------------
# 2. Servidor Dedicado Headless
# ------------------------------------------------------------------------------

func test_start_dedicated_server() -> void:
	var net_mgr: NetManagerNode = get_node_or_null("/root/NetManager")
	var err: Error = net_mgr.start_dedicated_server(7778)
	assert_eq(err, OK, "start_dedicated_server debe retornar OK")
	assert_not_null(multiplayer.multiplayer_peer, "multiplayer_peer activo en servidor")
	assert_true(multiplayer.is_server(), "Servidor dedicado es servidor")
	assert_true(net_mgr.is_dedicated_server, "is_dedicated_server marcado como true")
	assert_eq(net_mgr.get_local_role(), &"", "Servidor dedicado no ocupa un rol")
	assert_true(net_mgr.get_connected_players().is_empty(), "Servidor no se auto-registra")
	assert_true(net_mgr.is_server_authoritative(), "Servidor dedicado es autoritativo")

	net_mgr.disconnect_network()
	assert_null(multiplayer.multiplayer_peer, "Red desconectada")

# ------------------------------------------------------------------------------
# 3. Asignación y exclusión mutua de roles
# ------------------------------------------------------------------------------

func test_role_assignment_and_mutual_exclusion() -> void:
	var net_mgr: NetManagerNode = get_node_or_null("/root/NetManager")
	net_mgr.start_host(7777, 4)

	# Peer 1 (Host) es ladrón
	assert_eq(net_mgr.get_peer_id_for_role(NetManagerNode.ROLE_THIEF), 1, "Peer 1 es Ladrón")

	# Registrar Peer 2
	var reg2: bool = net_mgr.register_player(2, "GuardiaBeta")
	assert_true(reg2, "Peer 2 registrado")
	# Debe haber obtenido guard_1 como primer rol disponible
	assert_eq(net_mgr.get_role_for_peer(2), NetManagerNode.ROLE_GUARD_1, "Peer 2 recibe guard_1")
	assert_eq(net_mgr.get_peer_id_for_role(NetManagerNode.ROLE_GUARD_1), 2)

	# Exclusión mutua: Peer 2 intenta solicitar rol ladrón (&"thief")
	var try_thief: bool = net_mgr.assign_role(2, NetManagerNode.ROLE_THIEF)
	assert_false(try_thief, "assign_role debe rechazar rol si ya está ocupado")
	assert_eq(net_mgr.get_role_for_peer(2), NetManagerNode.ROLE_GUARD_1, "Peer 2 conserva guard_1")
	assert_eq(net_mgr.get_peer_id_for_role(NetManagerNode.ROLE_THIEF), 1, "Peer 1 sigue ladrón")

	# Peer 1 cambia voluntariamente a guard_2
	var change_p1: bool = net_mgr.assign_role(1, NetManagerNode.ROLE_GUARD_2)
	assert_true(change_p1, "Peer 1 cambia a guard_2 exitosamente")
	assert_eq(net_mgr.get_local_role(), NetManagerNode.ROLE_GUARD_2, "local_role en peer 1")
	assert_eq(net_mgr.get_peer_id_for_role(NetManagerNode.ROLE_GUARD_2), 1)

	# Ahora que thief está desocupado, Peer 2 puede tomarlo
	var change_p2: bool = net_mgr.assign_role(2, NetManagerNode.ROLE_THIEF)
	assert_true(change_p2, "Peer 2 adquiere el rol de ladrón ahora disponible")
	assert_eq(net_mgr.get_peer_id_for_role(NetManagerNode.ROLE_THIEF), 2, "Peer 2 nuevo ladrón")

	# Intentar asignar rol inexistente
	var invalid_role: bool = net_mgr.assign_role(2, &"detective")
	assert_false(invalid_role, "Rechaza roles fuera del catálogo asimétrico")

	net_mgr.disconnect_network()

# ------------------------------------------------------------------------------
# 4. Asignación de autoridad multijugador sobre mapa
# ------------------------------------------------------------------------------

func test_multiplayer_authority_assignment_on_map() -> void:
	var net_mgr: NetManagerNode = get_node_or_null("/root/NetManager")
	net_mgr.start_host(7777, 4)
	net_mgr.register_player(2, "Guardia1", NetManagerNode.ROLE_GUARD_1)
	net_mgr.register_player(3, "Guardia2", NetManagerNode.ROLE_GUARD_2)

	var map_scene: PackedScene = load(MAP_SCENE_PATH)
	var map: Node3D = autofree(map_scene.instantiate())
	add_child_autofree(map)
	await wait_physics_frames(1)

	var thief_node: CharacterBody3D = map.get_node("ThiefPlayer")
	var guard1_node: CharacterBody3D = map.get_node("GuardPlayer1")
	var guard2_node: CharacterBody3D = map.get_node("GuardPlayer2")

	assert_eq(thief_node.get_multiplayer_authority(), 1, "Thief asignado a peer 1")
	assert_eq(guard1_node.get_multiplayer_authority(), 2, "Guard 1 asignado a peer 2")
	assert_eq(guard2_node.get_multiplayer_authority(), 3, "Guard 2 asignado a peer 3")

	assert_true(thief_node.is_multiplayer_authority(), "Host posee autoridad de Thief")
	assert_false(guard1_node.is_multiplayer_authority(), "Host NO tiene autoridad Guard 1")
	assert_false(guard2_node.is_multiplayer_authority(), "Host NO tiene autoridad Guard 2")

	assert_false(guard1_node.is_ai_controlled, "Guard 1 es controlado por humano")
	assert_false(guard2_node.is_ai_controlled, "Guard 2 es controlado por humano")

	net_mgr.disconnect_network()

# ------------------------------------------------------------------------------
# 5. Restricción de captura de input solo a la entidad autorizada
# ------------------------------------------------------------------------------

func test_local_input_processing_restricted_to_authority() -> void:
	var net_mgr: NetManagerNode = get_node_or_null("/root/NetManager")
	net_mgr.start_host(7777, 4)

	var guard: GuardController3D = autofree(GuardController3D.new())
	guard.name = "GuardRemote"
	guard.set_multiplayer_authority(2) # Remoto, no local (local es 1)
	guard.is_ai_controlled = false
	add_child_autofree(guard)

	var thief: ThiefController3D = autofree(ThiefController3D.new())
	thief.name = "ThiefLocal"
	thief.set_multiplayer_authority(1) # Local
	add_child_autofree(thief)

	await wait_physics_frames(1)

	assert_false(guard.is_multiplayer_authority(), "Guard es remoto")
	assert_true(thief.is_multiplayer_authority(), "Thief es local")

	var initial_input: Vector2 = guard.current_input_dir
	guard._physics_process(0.016)
	assert_eq(guard.current_input_dir, initial_input, "Guard remoto no procesa input local")

	net_mgr.disconnect_network()

# ------------------------------------------------------------------------------
# 6. Vinculación de cámara y HUD según local_role
# ------------------------------------------------------------------------------

func test_camera_and_hud_binding_to_local_role() -> void:
	var net_mgr: NetManagerNode = get_node_or_null("/root/NetManager")
	net_mgr.start_host(7777, 4)
	net_mgr.assign_role(1, NetManagerNode.ROLE_GUARD_1)

	var map_scene: PackedScene = load(MAP_SCENE_PATH)
	var map: Node3D = autofree(map_scene.instantiate())
	add_child_autofree(map)
	await wait_physics_frames(1)

	var guard1_node: CharacterBody3D = map.get_node("GuardPlayer1")
	assert_eq(map.local_player, guard1_node, "local_player configurado a Guard 1")

	var hud_node: CanvasLayer = map.get_node("HUD84")
	assert_eq(hud_node.target_player, guard1_node, "HUD target_player vinculado a Guard 1")

	net_mgr.disconnect_network()

# ------------------------------------------------------------------------------
# 7. Sincronización continua de red e interpolación
# ------------------------------------------------------------------------------

func test_continuous_replication_sync_and_interpolation() -> void:
	var player: PlayerBase3D = autofree(PlayerBase3D.new())
	add_child_autofree(player)
	await wait_physics_frames(1)

	player.global_position = Vector3.ZERO
	var target_pos: Vector3 = Vector3(8.0, 0.0, 4.0)
	var target_vel: Vector3 = Vector3(3.0, 0.0, 1.5)
	var target_look: Vector3 = Vector3(12.0, 0.0, 4.0)

	player.set_net_transform(target_pos, target_vel)
	player.look_target_position = target_look
	assert_true(player.is_net_interpolating, "Bandera de interpolación de red activada")

	for i in range(10):
		player.update_presentation(0.05)

	assert_gt(player.global_position.x, 0.0, "Interpolación avanza hacia objetivo X")
	assert_gt(player.global_position.z, 0.0, "Interpolación avanza hacia objetivo Z")
	assert_eq(player.velocity, target_vel, "Velocidad de replicación asignada")
	assert_ne(player.rotation.y, 0.0, "Rotación orientada al objetivo de mirada")

# ------------------------------------------------------------------------------
# 8. Modo local / offline mantiene comportamiento original
# ------------------------------------------------------------------------------

func test_offline_mode_retains_singleplayer_behavior() -> void:
	var net_mgr: NetManagerNode = get_node_or_null("/root/NetManager")
	if multiplayer.multiplayer_peer != null:
		net_mgr.disconnect_network()

	assert_null(multiplayer.multiplayer_peer, "Sin multiplayer_peer activo")

	var map_scene: PackedScene = load(MAP_SCENE_PATH)
	var map: Node3D = autofree(map_scene.instantiate())
	add_child_autofree(map)
	await wait_physics_frames(1)

	var thief_node: CharacterBody3D = map.get_node("ThiefPlayer")
	var guard2_node: CharacterBody3D = map.get_node("GuardPlayer2")

	assert_eq(map.local_player, thief_node, "Modo local asigna local_player a Thief")
	assert_true(guard2_node.is_ai_controlled, "Guard 2 conserva IA en modo local")

	var hud_node: CanvasLayer = map.get_node("HUD84")
	assert_eq(hud_node.target_player, thief_node, "HUD vinculado a Thief en offline")

# ------------------------------------------------------------------------------
# 9. Handshake de conexión por Loopback 127.0.0.1 (Criterio 8)
# ------------------------------------------------------------------------------

func test_loopback_connection_handshake() -> void:
	var net_mgr: NetManagerNode = get_node_or_null("/root/NetManager")
	var host_err: Error = net_mgr.start_host(7789, 4)
	assert_eq(host_err, OK, "Host iniciado en puerto 7789")

	var client_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var client_err: Error = client_peer.create_client("127.0.0.1", 7789)
	assert_eq(client_err, OK, "Cliente conectado a loopback")

	var is_connected: bool = false
	for i in range(25):
		client_peer.poll()
		if multiplayer.multiplayer_peer != null:
			multiplayer.multiplayer_peer.poll()
		if client_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			is_connected = true
			break
		await wait_physics_frames(2)

	assert_true(is_connected, "Handshake exitoso entre Host y Cliente por loopback")

	client_peer.close()
	net_mgr.disconnect_network()
