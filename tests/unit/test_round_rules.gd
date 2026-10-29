## @file test_round_rules.gd
## Tests de la ronda de fichaje (FEAT-016; FEAT-034: una ruta por guardia): solo cuenta el
## siguiente reloj de la ruta, faltas por tramo con retraso, final por tiempo R4 con las faltas
## del equipo, reparto de rutas por zonas, tramos medidos por el grafo de salas, filtro de red,
## fichaje de la IA, campana y banderola, y tablilla del HUD.
extends GutTest

const RULES: TimeClockRules = preload("res://data/balance/time_clock_rules.tres")
const GUARD_SCENE: PackedScene = preload("res://scenes/entities/guard_player.tscn")
const THIEF_SCENE: PackedScene = preload("res://scenes/entities/thief_player.tscn")
const GUARD_AI_SCRIPT: Script = preload("res://src/entities/guard/guard_ai_3d.gd")
const LEVEL_PATH: String = "res://data/levels/museum_v2.json"

var _saved_state: GameManager.MatchState
var _saved_masterpiece: bool


func before_each() -> void:
	_saved_state = GameManager.current_state
	_saved_masterpiece = GameManager.has_masterpiece


func after_each() -> void:
	GameManager.current_state = _saved_state
	GameManager.has_masterpiece = _saved_masterpiece


func _clock(id: int = 1) -> TimeClock3D:
	var clock: TimeClock3D = TimeClock3D.new()
	clock.clock_id = id
	add_child_autofree(clock)
	return clock


## Guardia con su ronda: ruta route y tramos de leg segundos
func _guard(route: Array[int] = [1, 2], leg: float = 90.0) -> GuardController3D:
	var guard: GuardController3D = GUARD_SCENE.instantiate() as GuardController3D
	add_child_autofree(guard)
	var legs: Array[float] = []
	for _i: int in route:
		legs.append(leg)
	GuardRound.attach(guard).assign(route, legs)
	return guard


func test_faults_follow_formula_and_never_drop() -> void:
	var round_node: GuardRound = GuardRound.of(_guard())
	round_node.step(90.0)
	assert_true(round_node.late, "Se le acabó el tramo")
	round_node.step(40.0)
	assert_eq(round_node.faults, 1, "Retraso de 40 s en un tramo de 90 → 1 falta")
	assert_true(round_node.punch(1))
	assert_eq(round_node.faults, 1, "Fichar no borra faltas")
	round_node.step(90.0 + 180.0)
	assert_eq(round_node.faults, 4, "Segundo retraso de 180 s → 1 + 2 más")
	round_node.assign([3] as Array[int], [60.0] as Array[float])
	assert_eq(round_node.faults, 0, "Solo una ruta nueva (partida nueva) limpia la hoja")


func test_only_next_route_clock_counts() -> void:
	var guard: GuardController3D = _guard([2, 1])
	var round_node: GuardRound = GuardRound.of(guard)
	var clock_1: TimeClock3D = _clock(1)
	var clock_2: TimeClock3D = _clock(2)
	var thief: ThiefController3D = THIEF_SCENE.instantiate() as ThiefController3D
	add_child_autofree(thief)
	assert_false(clock_1.can_interact(thief), "El ladrón no ficha")
	assert_string_contains(clock_1.get_interaction_text(guard), "te toca el 2")
	round_node.step(30.0)
	clock_1.interact(guard)
	assert_eq(round_node.next_clock(), 2, "Fichar en otro reloj no cuenta")
	assert_almost_eq(round_node.time_left, 60.0, 0.001, "Ni reinicia el tramo")
	clock_2.interact(guard)
	assert_eq(round_node.next_clock(), 1, "El suyo, sí: pasa al siguiente")
	assert_almost_eq(round_node.time_left, 90.0, 0.001, "Tramo nuevo")
	clock_1.interact(guard)
	assert_eq(round_node.next_clock(), 2, "Al acabar la ruta vuelve a empezar")


func test_time_outcome_table() -> void:
	var round_a: GuardRound = GuardRound.of(_guard())
	var round_b: GuardRound = GuardRound.of(_guard())
	var allowed: int = RULES.allowed_misses * 2
	var cases: Array = [
		[0, false, true, GameManager.MatchState.TIME_EXPIRED],
		[allowed, false, true, GameManager.MatchState.TIME_EXPIRED],
		[allowed + 1, false, true, GameManager.MatchState.TIME_EXPIRED_BREACH],
		[allowed + 1, false, false, GameManager.MatchState.TIME_EXPIRED_DRAW],
		[1, true, true, GameManager.MatchState.TIME_EXPIRED_BREACH],
		[1, true, false, GameManager.MatchState.TIME_EXPIRED_DRAW],
	]
	for case: Array in cases:
		round_a.assign([1, 2] as Array[int], [90.0, 90.0] as Array[float])
		round_b.assign([2, 1] as Array[int], [90.0, 90.0] as Array[float])
		round_a.faults = int(case[0])
		round_b.late = bool(case[1])
		GameManager.has_masterpiece = bool(case[2])
		assert_eq(GameManager.time_expired_state(), case[3], "Casilla %s" % str(case))


func test_leg_at_zero_in_final_tick_counts_as_late() -> void:
	GuardRound.of(_guard()).time_left = 0.01
	GameManager.has_masterpiece = true
	assert_eq(
		GameManager.time_expired_state(),
		GameManager.MatchState.TIME_EXPIRED_BREACH,
		"Un tramo que llega a 0 en el último tick cuenta como retraso"
	)


func test_routes_spread_over_zones() -> void:
	var zones: Dictionary = {
		1: "centro",
		2: "oeste",
		3: "este",
		4: "oeste",
		5: "centro",
		6: "este",
		7: "este",
		8: "oeste"
	}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 84
	var routes: Array = RoundPlanner.pick_routes(zones, 3, RULES.route_length, rng)
	assert_eq(routes.size(), 3)
	var first_zones: Array = []
	for route: Array in routes:
		assert_eq(route.size(), RULES.route_length, "Una ruta de %d relojes" % RULES.route_length)
		for clock_id: int in route:
			assert_eq(route.count(clock_id), 1, "Sin repetir reloj")
		first_zones.append(zones[route[0]])
		assert_ne(zones[route[0]], zones[route[1]], "Alterna de zona")
	assert_eq(first_zones.size(), 3)
	assert_ne(first_zones[0], first_zones[1], "Cada guardia empieza en una zona distinta")
	assert_ne(first_zones[1], first_zones[2])


func test_legs_follow_the_walk_between_rooms() -> void:
	var data: LevelData = LevelData.load_json(LEVEL_PATH)
	var graph: RoomGraph = RoomGraph.from_level(data)
	for a: Dictionary in data.section("clocks"):
		for b: Dictionary in data.section("clocks"):
			var from: Vector2 = Vector2(float(a["pos"][0]), float(a["pos"][1]))
			var to: Vector2 = Vector2(float(b["pos"][0]), float(b["pos"][1]))
			assert_false(
				is_inf(graph.distance(from, to)), "Camino de R%s a R%s" % [a["id"], b["id"]]
			)
	var garita: Vector2 = Vector2(37, 26)
	var tapices: Vector2 = Vector2(65.8, 28)
	var walk: float = graph.distance(garita, tapices)
	assert_gt(walk, garita.distance_to(tapices), "Rodea por las puertas")
	var expected: float = (
		walk / RoundPlanner.GUARD_MOVEMENT.walk_speed * RULES.leg_walk_factor + RULES.leg_margin
	)
	assert_almost_eq(RoundPlanner.leg_seconds(walk), expected, 0.001)


func test_thief_never_receives_round_time_or_faults() -> void:
	var round_node: GuardRound = GuardRound.of(_guard())
	round_node.faults = 2
	assert_true(round_node.get_net_state().is_empty(), "Nada público")
	var collected: Dictionary = NetPrivateStates.new().collect({"Guard/Round": round_node}, true)
	assert_true(NetPrivateStates.for_role(collected, &"thief").is_empty(), "El ladrón, nada")
	var to_guard: Dictionary = NetPrivateStates.for_role(collected, &"guard_2")
	assert_eq(to_guard["Guard/Round#private"]["faults"], 2, "El equipo, sí")
	var clock: TimeClock3D = _clock()
	assert_eq(clock.get_net_state().keys(), ["expired"], "El reloj: solo la banderola")
	GameManager.current_state = GameManager.MatchState.IN_PROGRESS
	assert_false(GameManager.get_net_state().has("faults"), "Sin faltas durante la partida")
	GameManager.current_state = GameManager.MatchState.TIME_EXPIRED_DRAW
	assert_true(GameManager.get_net_state().has("faults"), "Faltas en la pantalla final")


func test_ai_guard_punches_its_next_clock() -> void:
	var guard: GuardController3D = _guard([1, 2])
	guard.is_ai_controlled = true
	guard.is_locally_controlled = false
	var ai: Node = Node.new()
	ai.name = "GuardAI"
	ai.set_script(GUARD_AI_SCRIPT)
	guard.add_child(ai)
	var other: TimeClock3D = _clock(2)
	other.global_position = guard.global_position + Vector3(-1.0, 0.0, 0.0)
	var clock: TimeClock3D = _clock(1)
	clock.global_position = guard.global_position + Vector3(1.0, 0.0, 0.0)
	await wait_physics_frames(3)
	assert_eq(GuardRound.of(guard).next_clock(), 2, "La IA ficha el suyo al pasar, y no el otro")


func test_bell_and_flag_while_late() -> void:
	var guard: GuardController3D = _guard([1, 2])
	var round_node: GuardRound = GuardRound.of(guard)
	var clock: TimeClock3D = _clock(1)
	var bells: Array = []
	var on_noise: Callable = func(
		_pos: Vector3, radius: float, _team: StringName, _cat: StringName, emitter: Node
	) -> void:
		if emitter == clock:
			bells.append(radius)
	SignalBus.noise_event_3d.connect(on_noise)
	var flag: Node3D = clock.get_node("ExpiredFlag") as Node3D
	assert_false(flag.visible, "Sin banderola a tiempo")
	round_node.step(90.0)
	for _i: int in range(int(RULES.alarm_pulse_interval * 2.0)):
		round_node.step(1.0)
	SignalBus.noise_event_3d.disconnect(on_noise)
	assert_eq(bells.size(), 2, "Una campanada cada alarm_pulse_interval")
	assert_almost_eq(float(bells[0]), RULES.alarm_noise_radius, 0.001)
	clock._physics_process(0.0)
	assert_true(flag.visible, "Banderola roja en el reloj al que llega tarde")
	clock.interact(guard)
	clock._physics_process(0.0)
	assert_false(flag.visible, "Fichar recoge la banderola")


func test_round_sheet_shows_route_and_warnings() -> void:
	var sheet: RoundSheet84 = RoundSheet84.new()
	add_child_autofree(sheet)
	var guard: GuardController3D = _guard([3, 1])
	guard.is_locally_controlled = true
	var round_node: GuardRound = GuardRound.of(guard)
	var mate: GuardRound = GuardRound.of(_guard())
	round_node.time_left = RULES.warning_time - 1.0
	sheet.refresh([round_node, mate])
	assert_string_contains(sheet.row_text(0), "[R3]", "La ruta con el reloj que toca")
	assert_string_contains(sheet.row_text(1), "%d s" % int(RULES.warning_time - 1.0))
	round_node.step(RULES.warning_time)
	mate.faults = RULES.allowed_misses * 2
	sheet.refresh([round_node, mate])
	assert_string_contains(sheet.row_text(1), "TARDE")
	assert_string_contains(
		sheet._faults_label.text, "%d / %d" % [mate.faults + round_node.faults, mate.faults]
	)
	mate.faults += 1
	sheet.refresh([round_node, mate])
	assert_string_contains(sheet._warning_label.text, "Ronda rota")


func test_safe_private_state_only_reaches_thief() -> void:
	var safe: SafeBox3D = SafeBox3D.new()
	add_child_autofree(safe)
	var collected: Dictionary = NetPrivateStates.new().collect({"Props/SafeBox3D": safe}, true)
	assert_true(NetPrivateStates.for_role(collected, &"guard_1").is_empty(), "Guardia: nada")
	assert_true(
		NetPrivateStates.for_role(collected, &"thief").has("Props/SafeBox3D#private"), "Ladrón: sí"
	)


## FEAT-042: con la alarma se acaba fichar. Las faltas de antes se quedan, no se apuntan más y
## nadie llega tarde (el final por tiempo no lo castiga)
func test_alarm_suspends_the_round() -> void:
	var round_node: GuardRound = GuardRound.of(_guard([1, 2], 10.0))
	round_node.step(10.0 + 10.0 + 1.0)  # tarde: dos faltas
	var before: int = round_node.faults
	assert_true(round_node.late)
	assert_gt(before, 0)
	round_node.suspend()
	assert_true(round_node.suspended)
	assert_false(round_node.late, "Con alarma nadie llega tarde")
	assert_false(RoundRules.any_expired([round_node], 0.1), "El final por tiempo no lo cuenta")
	assert_eq(round_node.faults, before, "Las faltas de antes se quedan")
	var state: Dictionary = round_node.get_net_state_private()
	assert_true(bool(state["off"]), "A los guardias les llega que no hay ronda")


func test_alarm_round_in_a_real_match() -> void:
	var map: HeistMap3D = (
		(load("res://scenes/maps/museum_v2.tscn") as PackedScene).instantiate() as HeistMap3D
	)
	add_child_autofree(map)
	await wait_physics_frames(3)
	var round_node: GuardRound = GuardRound.of(map.guards[0])
	assert_false(round_node.suspended)
	AlertDirector.of(get_tree()).raise(AlertDirector.Level.ALARM)
	await wait_physics_frames(2)
	assert_true(round_node.suspended, "Suena la alarma: se acabó fichar")


func test_legs_have_more_room() -> void:
	assert_almost_eq(RoundPlanner.leg_seconds(40.0), 40.0 / 4.2 * 2.3 + 25.0, 0.01)


func test_arrow_follows_the_path() -> void:
	var path: Array[Vector3] = [Vector3(0.5, 0, 0), Vector3(5, 0, 0), Vector3(5, 0, 8)]
	assert_eq(RoundArrow3D.next_point(path, Vector3.ZERO), Vector3(5, 0, 0), "Salta lo alcanzado")
	assert_almost_eq(RoundArrow3D.path_length(path, Vector3.ZERO), 13.0, 0.01)
	assert_eq(RoundArrow3D.next_point([] as Array[Vector3], Vector3.ONE), Vector3.ONE)
