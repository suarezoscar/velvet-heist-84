## @file test_multiplayer_lobby.gd
## Tests unitarios del lobby y la sesión de red (FEAT-003 y FEAT-014).
## Cubre el servidor dedicado, el rechazo del host, los roles limitados a ladrón y dos
## guardias, la asignación de autoridad del servidor y el handshake por loopback.
extends GutTest

const MAP_SCENE_PATH: String = "res://scenes/maps/museum_velvet_84.tscn"


func before_each() -> void:
	var net_mgr: NetManagerNode = NetManager
	if net_mgr != null and multiplayer.multiplayer_peer != null:
		net_mgr.disconnect_network()


func after_each() -> void:
	var net_mgr: NetManagerNode = NetManager
	if net_mgr != null and multiplayer.multiplayer_peer != null:
		net_mgr.disconnect_network()


# ------------------------------------------------------------------------------
# 1. El host que juega queda fuera del PoC (FEAT-014)
# ------------------------------------------------------------------------------


func test_start_host_is_unavailable() -> void:
	var net_mgr: NetManagerNode = NetManager
	assert_not_null(net_mgr, "NetManager Autoload debe existir en la escena raíz")

	var err: Error = net_mgr.start_host(7777, 4)
	assert_eq(err, ERR_UNAVAILABLE, "start_host debe devolver ERR_UNAVAILABLE")
	assert_null(multiplayer.multiplayer_peer, "start_host no crea ningún peer")
	assert_eq(net_mgr.get_local_role(), &"", "start_host no ocupa ningún rol")
	assert_true(net_mgr.get_connected_players().is_empty(), "start_host no registra jugadores")
	assert_false(net_mgr.is_server_authoritative(), "start_host no crea autoridad")


# ------------------------------------------------------------------------------
# 2. Servidor Dedicado Headless
# ------------------------------------------------------------------------------


func test_start_dedicated_server() -> void:
	var net_mgr: NetManagerNode = NetManager
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
# 3. Asignación y exclusión mutua de roles, limitados al PoC
# ------------------------------------------------------------------------------


func test_role_assignment_and_mutual_exclusion() -> void:
	var net_mgr: NetManagerNode = NetManager
	net_mgr.start_dedicated_server(7777)

	var reg2: bool = net_mgr.register_player(2, "Infiltrado")
	assert_true(reg2, "Peer 2 registrado")
	assert_eq(net_mgr.get_role_for_peer(2), NetManagerNode.ROLE_THIEF, "Peer 2 recibe thief")
	assert_eq(net_mgr.get_peer_id_for_role(NetManagerNode.ROLE_THIEF), 2)

	var reg3: bool = net_mgr.register_player(3, "GuardiaBeta")
	assert_true(reg3, "Peer 3 registrado")
	assert_eq(net_mgr.get_role_for_peer(3), NetManagerNode.ROLE_GUARD_1, "Peer 3 recibe guard_1")

	# Hasta tres guardias (FEAT-022)
	assert_true(net_mgr.is_role_available(NetManagerNode.ROLE_GUARD_3), "guard_3 está disponible")

	# Exclusión mutua: un rol ocupado no se puede asignar a otro peer
	assert_false(
		net_mgr.assign_role(2, NetManagerNode.ROLE_GUARD_1), "guard_1 ocupado no se reasigna"
	)
	var change_p2: bool = net_mgr.assign_role(2, NetManagerNode.ROLE_GUARD_2)
	assert_true(change_p2, "Peer 2 cambia a guard_2")
	assert_eq(net_mgr.get_role_for_peer(2), NetManagerNode.ROLE_GUARD_2)

	# El ladrón queda libre y lo puede tomar otro peer
	var change_p3: bool = net_mgr.assign_role(3, NetManagerNode.ROLE_THIEF)
	assert_true(change_p3, "Peer 3 adquiere el rol de ladrón")
	assert_eq(net_mgr.get_peer_id_for_role(NetManagerNode.ROLE_THIEF), 3)

	# Intentar asignar un rol inexistente
	var invalid_role: bool = net_mgr.assign_role(2, &"detective")
	assert_false(invalid_role, "Rechaza roles fuera del catálogo asimétrico")

	net_mgr.disconnect_network()


# ------------------------------------------------------------------------------
# 4. Autoridad del servidor; en red solo hay guardias humanos (FEAT-022)
# ------------------------------------------------------------------------------


func test_server_authority_and_human_guards_only() -> void:
	var net_mgr: NetManagerNode = NetManager
	net_mgr.start_dedicated_server(7777)
	net_mgr.register_player(2, "Guardia1", NetManagerNode.ROLE_GUARD_1)

	var map_scene: PackedScene = load(MAP_SCENE_PATH)
	var map: Node3D = autofree(map_scene.instantiate())
	add_child_autofree(map)
	await wait_physics_frames(1)

	assert_eq(map.thief.get_multiplayer_authority(), 1, "Thief tiene autoridad del servidor")
	assert_eq(map.guards[0].get_multiplayer_authority(), 1, "Guard 1 tiene autoridad del servidor")
	assert_eq(map.guards.size(), 1, "Un jugador guardia: un guardia en el mapa")
	assert_null(map.get_node_or_null("GuardPlayer2"), "Los guardias sin jugador se quitan")

	assert_false(map.thief.is_locally_controlled, "El servidor no controla al ladrón")
	assert_false(map.guards[0].is_locally_controlled, "El servidor no controla al Guard 1")
	assert_null(map.local_player, "El servidor dedicado no tiene jugador local")

	assert_false(map.guards[0].is_ai_controlled, "Guard 1 ocupado por un humano: sin IA")

	# Los roles guard_N mapean a guards[N-1] en orden de escena
	var session: NetSession = map.get_node("NetSession") as NetSession
	assert_not_null(session, "El mapa con red crea NetSession")
	assert_eq(session.actor_for_role(NetManagerNode.ROLE_THIEF), map.thief, "thief → map.thief")
	assert_eq(
		session.actor_for_role(NetManagerNode.ROLE_GUARD_1), map.guards[0], "guard_1 → guards[0]"
	)
	assert_null(session.actor_for_role(NetManagerNode.ROLE_GUARD_2), "guard_2 sin actor")

	net_mgr.disconnect_network()


# ------------------------------------------------------------------------------
# 5. El servidor dedicado no sigue a ningún jugador local
# ------------------------------------------------------------------------------


func test_dedicated_server_has_no_local_player() -> void:
	var net_mgr: NetManagerNode = NetManager
	net_mgr.start_dedicated_server(7777)
	net_mgr.register_player(2, "Guardia1", NetManagerNode.ROLE_GUARD_1)

	var map_scene: PackedScene = load(MAP_SCENE_PATH)
	var map: Node3D = autofree(map_scene.instantiate())
	add_child_autofree(map)
	await wait_physics_frames(1)

	assert_null(map.local_player, "local_player nulo en servidor dedicado")

	var hud_node: CanvasLayer = map.get_node("HUD84")
	assert_eq(hud_node.target_player, map.thief, "HUD sigue al ladrón en servidor dedicado")

	net_mgr.disconnect_network()


# ------------------------------------------------------------------------------
# 6. Modo local / offline mantiene comportamiento original
# ------------------------------------------------------------------------------


func test_offline_mode_retains_singleplayer_behavior() -> void:
	var net_mgr: NetManagerNode = NetManager
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
# 7. Handshake de conexión por Loopback 127.0.0.1
# ------------------------------------------------------------------------------


func test_loopback_connection_handshake() -> void:
	var net_mgr: NetManagerNode = NetManager
	var server_err: Error = net_mgr.start_dedicated_server(7789)
	assert_eq(server_err, OK, "Servidor dedicado iniciado en puerto 7789")

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

	assert_true(is_connected, "Handshake exitoso entre servidor dedicado y cliente por loopback")

	client_peer.close()
	net_mgr.disconnect_network()
