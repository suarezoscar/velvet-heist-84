## @file test_global_gameplay_loop.gd
## Suite de pruebas globales de integración y auditoría de Velvet Heist '84.
## Audita integridad de mapa (museum_velvet_84.tscn), ciclos de victoria y derrota,
## alarma de ronda (90s), red autoritativa, fugas de memoria y benchmark headless.
## La suite ya superaba las 300 líneas en master y PKG-3 solo adapta test_06.
# gdlint: disable=max-file-lines
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
# Test 1: Integridad del Mapa Principal (museum_velvet_84.tscn)
# ------------------------------------------------------------------------------


func test_01_map_integrity_and_actors_configuration() -> void:
	var map_scene: PackedScene = load(MAP_SCENE_PATH)
	assert_not_null(map_scene, "La escena del mapa museum_velvet_84.tscn debe cargar correctamente")

	var map: Node3D = autofree(map_scene.instantiate())
	assert_not_null(map, "El mapa debe instanciarse como Node3D")
	add_child_autofree(map)
	await wait_physics_frames(2)

	# 1. Comprobar actores jugables
	assert_not_null(map.thief, "ThiefPlayer debe estar presente en el mapa")
	assert_true(map.thief is ThiefController3D, "ThiefPlayer debe ser ThiefController3D")
	assert_not_null(map.guard_1, "GuardPlayer1 debe estar presente en el mapa")
	assert_true(map.guard_1 is GuardController3D, "GuardPlayer1 debe ser GuardController3D")
	assert_not_null(map.guard_2, "GuardPlayer2 debe estar presente en el mapa")
	assert_true(map.guard_2 is GuardController3D, "GuardPlayer2 debe ser GuardController3D")

	# 2. Comprobar props y elementos interactivos
	var car: EscapeCar3D = map.get_node_or_null("Props/EscapeCar3D") as EscapeCar3D
	assert_not_null(car, "EscapeCar3D debe existir bajo Props/")

	var safe_box: SafeBox3D = map.get_node_or_null("Props/SafeBox3D") as SafeBox3D
	assert_not_null(safe_box, "SafeBox3D debe existir bajo Props/")

	var clock_1: TimeClock3D = map.get_node_or_null("Props/TimeClock_01") as TimeClock3D
	var clock_2: TimeClock3D = map.get_node_or_null("Props/TimeClock_02") as TimeClock3D
	assert_not_null(clock_1, "TimeClock_01 debe existir bajo Props/")
	assert_not_null(clock_2, "TimeClock_02 debe existir bajo Props/")

	var cam_1: SecurityCamera3D = (
		map.get_node_or_null("Props/SecurityCamera_01") as SecurityCamera3D
	)
	var cam_2: SecurityCamera3D = (
		map.get_node_or_null("Props/SecurityCamera_02") as SecurityCamera3D
	)
	assert_not_null(cam_1, "SecurityCamera_01 debe existir bajo Props/")
	assert_not_null(cam_2, "SecurityCamera_02 debe existir bajo Props/")

	var mon_1: CCTVMonitor3D = map.get_node_or_null("Props/CCTVMonitor_01") as CCTVMonitor3D
	var mon_2: CCTVMonitor3D = map.get_node_or_null("Props/CCTVMonitor_02") as CCTVMonitor3D
	assert_not_null(mon_1, "CCTVMonitor_01 debe existir bajo Props/")
	assert_not_null(mon_2, "CCTVMonitor_02 debe existir bajo Props/")

	assert_not_null(map.hud, "HUD84 debe existir en la escena del mapa")
	assert_true(map.hud is HUD84, "HUD84 debe ser de tipo HUD84")
	assert_not_null(map.camera, "IsometricCamera3D debe existir en el mapa")

	# 3. Comprobar que no hay NodePaths rotos ni referencias nulas en propiedades críticas
	var has_visual_root: bool = map.thief.visual_root != null or map.thief.has_node("VisualRoot")
	assert_true(has_visual_root, "Thief debe tener nodo visual (VisualRoot)")
	assert_not_null(
		map.guard_1.maglite_light, "GuardPlayer1 maglite_light debe apuntar a SpotLight3D"
	)
	assert_not_null(
		map.guard_2.maglite_light, "GuardPlayer2 maglite_light debe apuntar a SpotLight3D"
	)

	assert_eq(mon_1.linked_camera, cam_1, "CCTVMonitor_01 debe estar vinculado a SecurityCamera_01")
	assert_eq(mon_2.linked_camera, cam_2, "CCTVMonitor_02 debe estar vinculado a SecurityCamera_02")
	assert_eq(map.hud.target_player, map.local_player, "HUD debe estar vinculado al local_player")


# ------------------------------------------------------------------------------
# Test 2: Ciclo de Victoria (Infiltración + Botín + Huida)
# ------------------------------------------------------------------------------


func test_02_victory_cycle_infiltration_loot_escape() -> void:
	var gm: Node = GameManager
	assert_not_null(gm, "GameManager debe existir")

	var map_scene: PackedScene = load(MAP_SCENE_PATH)
	var map: Node3D = autofree(map_scene.instantiate())
	add_child_autofree(map)
	await wait_physics_frames(2)

	# 1. Iniciar partida con cuota de $10.000 y 600 segundos
	gm.set("quota_target", 10000)
	gm.set("match_duration_seconds", 600.0)
	gm.call("start_match")

	assert_eq(gm.get("current_state"), GameState.IN_PROGRESS, "Partida en estado IN_PROGRESS")
	assert_eq(gm.get("current_loot_value"), 0, "Botín inicial es $0")
	assert_false(gm.get("has_masterpiece"), "Pieza maestra aún no obtenida")
	assert_false(gm.call("can_thief_escape"), "El ladrón no puede escapar sin cuota ni obra")

	# 2. Recolectar botín en efectivo del mapa ($5.000) y completar cuota
	var props: Node3D = map.get_node("Props")
	var cash_items_collected: int = 0
	var masterpiece: LootItem3D = null

	for child in props.get_children():
		if child is LootItem3D:
			if child.is_masterpiece:
				masterpiece = child
			else:
				child.interact(map.thief)
				cash_items_collected += 1

	assert_gt(cash_items_collected, 0, "Se recolectaron fajos de billetes en el mapa")
	assert_not_null(masterpiece, "Pieza Maestra encontrada en el mapa")

	# Sumar botín adicional para alcanzar los $10.000 requeridos junto a la obra
	var bus: Node = SignalBus
	bus.emit_signal("loot_stolen", 5000, false)
	assert_gte(gm.get("current_loot_value"), 10000, "Cuota monetaria alcanzada")
	assert_false(gm.call("can_thief_escape"), "Aún no puede escapar: falta Pieza Maestra asegurada")

	# 3. Sustraer la Pieza Maestra (botín pesado)
	masterpiece.interact(map.thief)
	assert_true(map.thief.is_carrying_heavy_loot, "Ladrón carga la Pieza Maestra en brazos")
	assert_eq(map.thief.carried_loot, masterpiece, "Objeto cargado es la obra maestra")
	assert_false(map.thief.can_use_gadgets(), "Gadgets bloqueados por botín pesado")
	assert_false(
		gm.call("can_thief_escape"), "Pieza Maestra aún no asegurada en maletero del coche"
	)

	# 4. Acudir al coche de fuga y depositar la obra
	var car: EscapeCar3D = props.get_node("EscapeCar3D") as EscapeCar3D
	assert_not_null(car, "EscapeCar3D presente")
	watch_signals(car)
	if gm.has_signal("match_ended"):
		watch_signals(gm)

	map.thief.global_position = car.global_position
	assert_eq(car.get_interaction_text(map.thief), EscapeCar3D.PROMPT_DEPOSIT)

	# Interacción 1: Depositar en maletero
	car.interact(map.thief)
	assert_false(map.thief.is_carrying_heavy_loot, "Ladrón libera sus manos")
	assert_true(map.thief.can_use_gadgets(), "Uso de gadgets restaurado")
	assert_true(gm.get("has_masterpiece"), "Pieza Maestra asegurada en GameManager")
	assert_true(gm.call("can_thief_escape"), "can_thief_escape es true tras asegurar obra y cuota")

	# Interacción 2: Arrancar motor y escapar
	assert_eq(car.get_interaction_text(map.thief), EscapeCar3D.PROMPT_ESCAPE)
	car.interact(map.thief)

	assert_signal_emitted(car, "escape_succeeded", "Señal escape_succeeded emitida")
	assert_eq(
		gm.get("current_state"),
		GameState.THIEF_ESCAPED,
		"Estado autoritativo cambia a THIEF_ESCAPED"
	)
	if gm.has_signal("match_ended"):
		assert_signal_emitted(gm, "match_ended", "GameManager emite match_ended")

	# 5. Comprobar que el HUD actualiza el panel de fin de partida
	map.hud._process(0.016)
	assert_true(map.hud.game_over_panel.visible, "Panel de fin de partida visible en HUD")
	assert_true(map.hud.game_over_title.text.contains("LADRÓN HA ESCAPADO"))


# ------------------------------------------------------------------------------
# Test 3: Ciclo de Derrota por Neutralización (2 impactos de porra)
# ------------------------------------------------------------------------------


func test_03_defeat_cycle_by_guard_neutralization() -> void:
	var gm: Node = GameManager
	var map_scene: PackedScene = load(MAP_SCENE_PATH)
	var map: Node3D = autofree(map_scene.instantiate())
	add_child_autofree(map)
	await wait_physics_frames(2)

	gm.call("start_match")
	assert_eq(gm.get("current_state"), GameState.IN_PROGRESS)

	var thief: ThiefController3D = map.thief
	var guard: GuardController3D = map.guard_1
	thief.reset_baton_hits()
	assert_eq(thief.baton_hits_taken, 0)

	# Posicionar al guardia adyacente al ladrón dentro del radio melee (1.0m < 1.6m)
	guard.global_position = thief.global_position + Vector3(1.0, 0.0, 0.0)
	guard.look_target_position = thief.global_position

	# Impacto 1
	guard.baton_cooldown = 0.0
	var hit1: bool = guard.swing_baton(thief)
	assert_true(hit1, "Primer impacto conecta con éxito")
	assert_eq(thief.baton_hits_taken, 1, "1 impacto registrado en el ladrón")
	assert_eq(gm.get("current_state"), GameState.IN_PROGRESS, "Partida sigue en curso")

	# Impacto 2
	guard.baton_cooldown = 0.0
	var hit2: bool = guard.swing_baton(thief)
	assert_true(hit2, "Segundo impacto conecta con éxito")
	assert_eq(thief.baton_hits_taken, 2, "2 impactos registrados: captura total")
	assert_eq(
		gm.get("current_state"),
		GameState.THIEF_CAPTURED,
		"Estado autoritativo cambia a THIEF_CAPTURED"
	)

	map.hud._process(0.016)
	assert_true(map.hud.game_over_panel.visible, "HUD muestra panel de derrota")
	assert_true(map.hud.game_over_title.text.contains("CAPTURADO"))


# ------------------------------------------------------------------------------
# Test 4: Ciclo de Alarma por Reloj de Fichar de 90s
# ------------------------------------------------------------------------------


func test_04_alarm_cycle_time_clock_90s() -> void:
	var gm: Node = GameManager
	var bus: Node = SignalBus
	var map_scene: PackedScene = load(MAP_SCENE_PATH)
	var map: Node3D = autofree(map_scene.instantiate())
	add_child_autofree(map)
	await wait_physics_frames(2)

	gm.call("start_match")

	var clock: TimeClock3D = map.get_node("Props/TimeClock_01") as TimeClock3D
	assert_not_null(clock, "TimeClock_01 presente en mapa")
	watch_signals(clock)
	watch_signals(bus)

	assert_almost_eq(clock.round_duration, 90.0, 0.001, "Duración configurada a 90s")
	assert_almost_eq(clock.time_left, 90.0, 0.5, "Reloj arranca con ~90 segundos")
	assert_false(clock.is_expired, "Reloj no vencido al inicio")

	# 1. Simular transcurso de los 90s sin fichaje de los guardias
	clock._update_countdown(90.1)
	assert_almost_eq(clock.time_left, 0.0, 0.001, "Tiempo de ronda agotado")
	assert_true(clock.is_expired, "Reloj entra en estado de alarma")
	assert_signal_emitted(clock, "clock_expired", "Señal clock_expired emitida")
	assert_true(clock.get_interaction_text().contains("ALARMA"), "Prompt refleja alarma activa")

	# 2. Verificar pulsos acústicos periódicos en SignalBus
	clock._update_countdown(3.0)
	assert_signal_emitted(bus, "noise_emitted_3d", "Alarma notificada en SignalBus")

	# 3. Guardia acude y ficha para cancelar la alarma
	clock.interact(map.guard_1)
	assert_false(clock.is_expired, "Alarma desactivada tras fichar el guardia")
	assert_almost_eq(clock.time_left, 90.0, 0.001, "Ciclo de ronda reiniciado a 90 segundos")


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
