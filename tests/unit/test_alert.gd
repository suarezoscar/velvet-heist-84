## @file test_alert.gd
## Rastros, alerta, monedas y walkie (heist.md R6-R8, FEAT-031).
extends GutTest

const MAP_SCENE: PackedScene = preload("res://scenes/maps/museum_v2.tscn")
const RULES: HeistRules = preload("res://data/balance/heist_rules.tres")

var _saved_state: GameManager.MatchState
var _noises: Array = []


func before_each() -> void:
	_saved_state = GameManager.current_state
	_noises.clear()
	SignalBus.noise_event_3d.connect(_on_noise)


func after_each() -> void:
	GameManager.current_state = _saved_state
	SignalBus.noise_event_3d.disconnect(_on_noise)


func _on_noise(
	pos: Vector3, radius: float, team: StringName, category: StringName, _e: Node
) -> void:
	_noises.append({"pos": pos, "radius": radius, "team": team, "category": category})


func _map() -> HeistMap3D:
	var map: HeistMap3D = MAP_SCENE.instantiate() as HeistMap3D
	add_child_autofree(map)
	for guard: GuardController3D in map.guards:
		guard.set_physics_process(false)
	return map


func _piece(variant: StringName) -> TargetPiece3D:
	for node: Node in get_tree().get_nodes_in_group(&"heist_targets"):
		if (node as TargetPiece3D).variant == variant:
			return node as TargetPiece3D
	return null


func test_silent_theft_is_found_by_a_guard_and_raises_suspicion() -> void:
	var map: HeistMap3D = _map()
	await wait_physics_frames(2)
	var alert: AlertDirector = AlertDirector.of(get_tree())
	var safe: TargetPiece3D = _piece(&"safe")
	GameManager.heist.targets.assign([safe.piece_id])
	safe.lock.current_state = SafeBox3D.SafeState.OPENED
	safe.interact(map.thief)
	alert.scan()
	assert_eq(alert.level, AlertDirector.Level.CALM, "Nadie lo ha visto: calma")
	assert_false(safe.discovered)
	map.guards[0].global_position = safe.global_position + Vector3(-3.0, 0.05, 0.0)
	await wait_physics_frames(2)
	alert.scan()
	assert_true(safe.discovered, "El guardia ve el pedestal vacío")
	assert_eq(alert.level, AlertDirector.Level.SUSPICION)
	assert_has(alert.get_net_state_private()["found"], safe.piece_id, "Les llega a los guardias")


func test_brute_theft_or_sighting_means_alarm_and_it_never_drops() -> void:
	var map: HeistMap3D = _map()
	await wait_physics_frames(2)
	var alert: AlertDirector = AlertDirector.of(get_tree())
	var piece: TargetPiece3D = _piece(&"pedestal")
	GameManager.heist.targets.assign([piece.piece_id])
	piece.interact(map.thief)
	assert_eq(alert.level, AlertDirector.Level.ALARM, "A lo bruto salta la alarma")
	alert.raise(AlertDirector.Level.CALM)
	assert_eq(alert.level, AlertDirector.Level.ALARM, "Nunca baja")
	var fresh: AlertDirector = AlertDirector.new()
	autofree(fresh)
	assert_eq(fresh.level, AlertDirector.Level.CALM)


func test_guard_seeing_thief_raises_alarm() -> void:
	var map: HeistMap3D = _map()
	await wait_physics_frames(2)
	var alert: AlertDirector = AlertDirector.of(get_tree())
	map.guards[1].is_perceiving_thief = true
	alert.scan()
	assert_eq(alert.level, AlertDirector.Level.ALARM)
	map.guards[1].is_perceiving_thief = false


func test_coins_make_thief_noise_where_they_land() -> void:
	var map: HeistMap3D = _map()
	await wait_physics_frames(2)
	var thief: ThiefController3D = map.thief
	thief.look_target_position = thief.global_position + Vector3(40.0, 0.0, 0.0)
	for i: int in range(RULES.coins):
		assert_true(HeistActions.handle(thief, &"throw_coin"), "Moneda %d" % i)
	assert_false(HeistActions.handle(thief, &"throw_coin"), "Se acaban")
	assert_eq(GameManager.heist.coins_left, 0)
	assert_true(_noises.is_empty(), "Suena al caer, no al lanzar (FEAT-038)")
	assert_not_null(map.find_child("CoinFlight", true, false), "La moneda se ve volar")
	await wait_seconds(RULES.coin_flight_time + 0.2)
	assert_eq(_noises.size(), RULES.coins, "Una por moneda, al caer")
	var coin: Dictionary = _noises[0]
	assert_eq(coin["team"], &"thief", "Suena como el ladrón")
	assert_almost_eq(float(coin["radius"]), RULES.coin_radius, 0.01)
	var flat: Vector3 = (coin["pos"] as Vector3) - thief.global_position
	assert_lte(Vector2(flat.x, flat.z).length(), RULES.throw_range + 0.01, "Alcance limitado")
	assert_false(
		HeistActions.handle(map.guards[0], &"throw_coin"), "Los guardias no tienen monedas"
	)


func test_walkie_pings_team_and_clicks() -> void:
	var map: HeistMap3D = _map()
	await wait_physics_frames(2)
	var alert: AlertDirector = AlertDirector.of(get_tree())
	var guard: GuardController3D = map.guards[0]
	guard.look_target_position = guard.global_position + Vector3(3.0, 0.0, 0.0)
	assert_true(HeistActions.handle(guard, &"walkie"))
	assert_eq(alert.pings.size(), 1, "Marca en el plano")
	assert_false(HeistActions.handle(guard, &"walkie"), "Espera entre usos")
	assert_eq(_noises.back()["team"], &"guard", "El chasquido delata al guardia")
	assert_eq(alert.net_private_audience(), &"guard", "Las marcas, solo a los guardias")
	assert_false(HeistActions.handle(map.thief, &"walkie"), "El ladrón no tiene walkie")
	alert._age_pings(RULES.ping_time + 0.1)
	assert_eq(alert.pings.size(), 0, "La marca se borra")


func test_alarm_lights_only_in_alarm_and_restore() -> void:
	var map: HeistMap3D = _map()
	await wait_physics_frames(2)
	var alert: AlertDirector = AlertDirector.of(get_tree())
	var guard: GuardController3D = map.guards[0]
	assert_false(HeistActions.handle(guard, &"alarm_lights"), "Sin alarma, no")
	var dark: Lamp3D = null
	for node: Node in get_tree().get_nodes_in_group(&"lamps"):
		var lamp: Lamp3D = node as Lamp3D
		if lamp.global_position.distance_to(guard.global_position) < RULES.flood_radius:
			lamp.set_switched(false)
			dark = lamp
			break
	alert.raise(AlertDirector.Level.ALARM)
	assert_true(HeistActions.handle(guard, &"alarm_lights"))
	assert_true(dark.is_switched_on, "Se enciende")
	assert_false(HeistActions.handle(guard, &"alarm_lights"), "Espera del equipo")
	alert._tick_flood(RULES.flood_time + 0.1)
	assert_false(dark.is_switched_on, "Pasado el rato, vuelve a como estaba")
	assert_string_contains(
		AlertHud84.tools_text(false, alert, GameManager.heist), "LUCES DE ALARMA"
	)
	assert_string_contains(AlertHud84.tools_text(true, alert, GameManager.heist), "MONEDAS")


func test_watched_camera_finds_an_empty_pedestal() -> void:
	var map: HeistMap3D = _map()
	await wait_physics_frames(2)
	var alert: AlertDirector = AlertDirector.of(get_tree())
	var piece: TargetPiece3D = _piece(&"pedestal")
	GameManager.heist.targets.assign([piece.piece_id])
	piece.steal(false)
	var camera: SecurityCamera3D = (
		load("res://scenes/entities/security_camera.tscn").instantiate() as SecurityCamera3D
	)
	camera.sweep_enabled = false
	map.add_child(camera)
	camera.global_position = piece.global_position + Vector3(4.0, 2.9, 0.0)
	camera.look_at(piece.global_position + Vector3.UP * 1.1, Vector3.UP)
	await wait_physics_frames(2)
	assert_true(
		camera.sees_point(piece.global_position + Vector3.UP * 1.1), "El pedestal no la tapa"
	)
	alert.scan()
	assert_false(piece.discovered, "Sin nadie en los monitores no cuenta")
	var guard: GuardController3D = map.guards[0]
	guard.monitor_watch.state = GuardMonitorWatch.State.WATCHING
	alert.scan()
	assert_true(piece.discovered, "Con alguien mirando los monitores, sí")
	guard.monitor_watch.state = GuardMonitorWatch.State.NONE


func test_discovered_traces_only_reach_guards() -> void:
	var map: HeistMap3D = _map()
	await wait_physics_frames(2)
	var alert: AlertDirector = AlertDirector.of(get_tree())
	var piece: TargetPiece3D = _piece(&"pedestal")
	GameManager.heist.targets.assign([piece.piece_id])
	piece.interact(map.thief)
	assert_false(piece.get_net_state().has("discovered"), "No va en el estado público")
	assert_has(alert.get_net_state_private()["found"], piece.piece_id, "Va a los guardias")
	piece.discovered = false
	alert.apply_net_state({"found": [piece.piece_id]})
	assert_true(piece.discovered, "El cliente del guardia lo aplica")


func test_no_sleep_during_alarm() -> void:
	var map: HeistMap3D = _map()
	await wait_physics_frames(2)
	var guard: GuardController3D = map.guards[0]
	guard.is_ai_controlled = false
	AlertDirector.of(get_tree()).raise(AlertDirector.Level.ALARM)
	var sleep: GuardSleep = guard.get_node("Sleep") as GuardSleep
	for i: int in range(300):
		sleep.step(0.5)
	assert_eq(sleep.level, 0.0, "En alarma no entra sueño")
