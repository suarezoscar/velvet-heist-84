## @file test_guard_slots.gd
## Hasta tres guardias (FEAT-022): para empezar hacen falta ladrón y un guardia, los roles de
## guardia se renumeran sin huecos al empezar, y el mapa deja un guardia por jugador guardia
## con red y uno por patrulla sin red.
extends GutTest

const MAP_SCENE: PackedScene = preload("res://scenes/maps/museum_v2.tscn")


func _players(roles: Dictionary) -> Dictionary:
	var players: Dictionary = {}
	for peer_id: int in roles:
		players[peer_id] = {"peer_id": peer_id, "role": roles[peer_id]}
	return players


func test_can_start_needs_thief_and_a_guard() -> void:
	assert_false(NetRoleRegistry.can_start(_players({2: &"thief"})), "Solo ladrón")
	assert_false(NetRoleRegistry.can_start(_players({2: &"guard_1"})), "Solo guardia")
	assert_true(NetRoleRegistry.can_start(_players({2: &"thief", 3: &"guard_3"})))


func test_compact_guards_closes_gaps() -> void:
	var players: Dictionary = _players({2: &"thief", 5: &"guard_3", 7: &"guard_2", 9: &""})
	NetRoleRegistry.compact_guards(players)
	assert_eq(players[7]["role"], &"guard_1", "guard_2 pasa a guard_1")
	assert_eq(players[5]["role"], &"guard_2", "guard_3 pasa a guard_2")
	assert_eq(players[2]["role"], &"thief")
	assert_eq(players[9]["role"], &"", "Sin bando sigue sin bando")
	assert_eq(NetRoleRegistry.guard_count(players), 2)


func test_offline_keeps_one_guard_per_patrol() -> void:
	var map: HeistMap3D = MAP_SCENE.instantiate() as HeistMap3D
	add_child_autofree(map)
	await wait_physics_frames(1)
	assert_eq(map.guards.size(), 2, "Sin red, dos guardias de IA")
	assert_null(map.get_node_or_null("GuardPlayer3"), "El tercero se quita")
	for guard: GuardController3D in map.guards:
		assert_true(guard.is_ai_controlled, "Con patrulla")


func test_online_three_guards() -> void:
	var net_mgr: NetManagerNode = NetManager
	net_mgr.start_dedicated_server(7777)
	net_mgr.register_player(2, "L", &"thief")
	for i: int in range(3):
		net_mgr.register_player(3 + i, "G%d" % i, NetConfig.ROLES[i + 1])
	var map: HeistMap3D = MAP_SCENE.instantiate() as HeistMap3D
	add_child_autofree(map)
	await wait_physics_frames(1)
	assert_eq(map.guards.size(), 3, "Tres jugadores guardia, tres guardias")
	var session: NetSession = map.get_node("NetSession") as NetSession
	assert_eq(session.actor_for_role(&"guard_3"), map.guards[2])
	for guard: GuardController3D in map.guards:
		assert_false(guard.is_ai_controlled, "Todos humanos")
	net_mgr.disconnect_network()
