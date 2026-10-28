## @file test_gameplay_loop_late.gd
## Suite global de integración de Velvet Heist '84 (2/2): alarma del reloj de fichar, derrota por
## tiempo, red autoritativa en el mapa, fugas de memoria y benchmark headless.
extends GutTest

## Espejo tipado de GameManager.MatchState para verificaciones asertivas
enum GameState {LOBBY = 0, IN_PROGRESS = 1, THIEF_ESCAPED = 2, THIEF_CAPTURED = 3, TIME_EXPIRED = 4}

const MAP_SCENE_PATH: String = "res://scenes/maps/museum_velvet_84.tscn"


func before_each() -> void:
	var net_mgr: NetManagerNode = NetManager
	if net_mgr != null and multiplayer.multiplayer_peer != null:
		net_mgr.disconnect_network()
	var gm: Node = GameManager
	if gm != null:
		gm.set("current_state", GameState.LOBBY)
		gm.set("current_loot_value", 0)
		gm.set("has_masterpiece", false)
		gm.set("match_timer", 600.0)


func after_each() -> void:
	var net_mgr: NetManagerNode = NetManager
	if net_mgr != null and multiplayer.multiplayer_peer != null:
		net_mgr.disconnect_network()
	var gm: Node = GameManager
	if gm != null:
		gm.set("current_state", GameState.LOBBY)
		gm.set("current_loot_value", 0)
		gm.set("has_masterpiece", false)
		gm.set("match_timer", 600.0)


# ------------------------------------------------------------------------------
# Test 4: Ciclo de Alarma por Reloj de Fichar de 90s
# ------------------------------------------------------------------------------


func test_04_alarm_cycle_time_clock_90s() -> void:
	var gm: Node = GameManager
	var map: Node3D = load("res://scenes/maps/museum_v2.tscn").instantiate() as Node3D
	add_child_autofree(map)
	await wait_physics_frames(2)
	gm.call("start_match")
	await wait_physics_frames(2)

	# FEAT-034: cada guardia recibe su ruta al empezar
	var guard: GuardController3D = map.get("guards")[0]
	var round_node: GuardRound = GuardRound.of(guard)
	assert_eq(round_node.route.size(), 4, "Ruta de 4 relojes")
	assert_gt(round_node.time_left, 15.0, "El primer tramo da tiempo a llegar")
	var clock: TimeClock3D = null
	for node: Node in map.get_tree().get_nodes_in_group(&"time_clock"):
		if (node as TimeClock3D).clock_id == round_node.next_clock():
			clock = node as TimeClock3D
	assert_not_null(clock, "Su siguiente reloj está en el mapa")

	# 1. Se le acaba el tramo: llega tarde y baja la banderola de ese reloj
	round_node.step(round_node.time_left + 0.1)
	assert_true(round_node.late, "Llega tarde")
	await wait_physics_frames(2)
	assert_true(clock.is_expired, "Banderola en su reloj")

	# 2. Ficha en su reloj: tramo nuevo y banderola recogida
	clock.interact(guard)
	assert_false(round_node.late, "Al día tras fichar")
	await wait_physics_frames(2)
	assert_false(clock.is_expired, "Banderola recogida")


# ------------------------------------------------------------------------------
# Test 5: Ciclo de Derrota por Expiración de Tiempo Global (600s)
# ------------------------------------------------------------------------------


func test_05_defeat_cycle_by_time_expiration() -> void:
	var gm: Node = GameManager
	var map_scene: PackedScene = load(MAP_SCENE_PATH)
	var map: Node3D = autofree(map_scene.instantiate())
	add_child_autofree(map)
	await wait_physics_frames(2)

	gm.set("match_duration_seconds", 600.0)
	gm.call("start_match")
	assert_eq(gm.get("current_state"), GameState.IN_PROGRESS)
	assert_almost_eq(gm.get("match_timer"), 600.0, 0.001)

	# Simular el agotamiento completo del reloj de 600 segundos
	gm._physics_process(600.1)

	assert_almost_eq(gm.get("match_timer"), 0.0, 0.001, "Temporizador global clampado a 0")
	assert_eq(
		gm.get("current_state"), GameState.TIME_EXPIRED, "Transición autoritativa a TIME_EXPIRED"
	)

	map.hud._process(0.016)
	assert_true(map.hud.game_over_panel.visible, "HUD muestra panel de derrota por tiempo")
	assert_true(map.hud.game_over_title.text.contains("TIEMPO AGOTADO"))


# ------------------------------------------------------------------------------
# Test 6: Integración Multijugador en el Mapa (servidor autoritativo)
# ------------------------------------------------------------------------------


func test_06_multiplayer_integration_on_map() -> void:
	var net_mgr: NetManagerNode = NetManager
	assert_not_null(net_mgr, "NetManager presente")

	var err: Error = net_mgr.start_dedicated_server(7777)
	assert_eq(err, OK, "Servidor dedicado iniciado")
	net_mgr.register_player(4, "Ladron", NetManagerNode.ROLE_THIEF)
	net_mgr.register_player(2, "Guardia1", NetManagerNode.ROLE_GUARD_1)
	net_mgr.register_player(3, "Guardia2", NetManagerNode.ROLE_GUARD_2)

	var map_scene: PackedScene = load(MAP_SCENE_PATH)
	var map: Node3D = autofree(map_scene.instantiate())
	add_child_autofree(map)
	await wait_physics_frames(2)

	# Todos los actores pertenecen al servidor (peer 1) y este los simula
	assert_eq(map.thief.get_multiplayer_authority(), 1, "Thief con autoridad del servidor")
	assert_eq(map.guard_1.get_multiplayer_authority(), 1, "Guard 1 con autoridad del servidor")
	assert_eq(map.guard_2.get_multiplayer_authority(), 1, "Guard 2 con autoridad del servidor")

	assert_true(map.thief.is_multiplayer_authority(), "El servidor simula al Thief")
	assert_true(map.guard_1.is_multiplayer_authority(), "El servidor simula al Guard 1")
	assert_true(map.guard_2.is_multiplayer_authority(), "El servidor simula al Guard 2")

	assert_false(map.guard_1.is_ai_controlled, "Guard 1 ocupado por humano: sin IA")
	assert_false(map.guard_2.is_ai_controlled, "Guard 2 ocupado por humano: sin IA")
	assert_null(map.local_player, "El servidor dedicado no controla a ningún actor")

	net_mgr.disconnect_network()


# ------------------------------------------------------------------------------
# Test 7: Auditoría de Nodos Huérfanos y Fugas de Memoria
# ------------------------------------------------------------------------------


func test_07_orphan_nodes_and_memory_leak_audit() -> void:
	var map_scene: PackedScene = load(MAP_SCENE_PATH)
	assert_not_null(map_scene)

	# Estabilizar árbol antes de la medición
	await wait_physics_frames(2)
	var orphans_baseline: int = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)

	for cycle: int in range(3):
		var map: Node3D = map_scene.instantiate()
		add_child(map)
		await wait_physics_frames(2)
		remove_child(map)
		map.queue_free()
		await wait_physics_frames(2)

	await wait_physics_frames(3)
	var orphans_after: int = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var delta_orphans: int = orphans_after - orphans_baseline

	print(
		(
			"[MemoryAudit] Nodos huérfanos antes=%d, después=%d, delta=%d"
			% [orphans_baseline, orphans_after, delta_orphans]
		)
	)
	assert_lte(
		delta_orphans,
		0,
		"Sin fugas de nodos persistentes tras liberar el mapa (delta=%d)" % delta_orphans
	)


# ------------------------------------------------------------------------------
# Test 8: Benchmark de Rendimiento Headless (120 ticks físicos)
# ------------------------------------------------------------------------------


func test_08_headless_performance_benchmark() -> void:
	var map_scene: PackedScene = load(MAP_SCENE_PATH)
	var map: Node3D = autofree(map_scene.instantiate())
	add_child_autofree(map)
	await wait_physics_frames(5)

	var frame_times: Array[float] = []
	var total_time_ms: float = 0.0
	var max_frame_time_ms: float = 0.0

	for i in range(120):
		var t_start: int = Time.get_ticks_usec()
		map._physics_process(1.0 / 60.0)
		if map.thief != null:
			map.thief._physics_process(1.0 / 60.0)
		if map.guard_1 != null:
			map.guard_1._physics_process(1.0 / 60.0)
		if map.guard_2 != null:
			map.guard_2._physics_process(1.0 / 60.0)
		var t_elapsed_ms: float = (Time.get_ticks_usec() - t_start) / 1000.0

		frame_times.append(t_elapsed_ms)
		total_time_ms += t_elapsed_ms
		if t_elapsed_ms > max_frame_time_ms:
			max_frame_time_ms = t_elapsed_ms

		await wait_physics_frames(1)

	var avg_frame_time_ms: float = total_time_ms / float(frame_times.size())
	print(
		(
			"[Benchmark] 120 ticks: Media=%.3fms | Pico Max=%.3fms"
			% [avg_frame_time_ms, max_frame_time_ms]
		)
	)

	# Presupuesto para 60 FPS = 16.66ms. En headless debe ser holgadamente inferior
	assert_lt(
		avg_frame_time_ms, 16.66, "Tiempo medio por frame debe ser inferior a 16.66ms (60 FPS)"
	)
	assert_lt(max_frame_time_ms, 50.0, "Ningún frame debe superar el umbral de pico de 50ms")
