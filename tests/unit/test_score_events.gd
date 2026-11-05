## @file test_score_events.gd
## Puntos nuevos de #123 (heist.md R11): despistes, walkie que acierta, robos en silencio cerca,
## falsificación descubierta, quién da la alarma y lo que llega al informe y a la puntuación
## en vivo de cada jugador.
extends GutTest

const MAP_SCENE: PackedScene = preload("res://scenes/maps/museum_v2.tscn")
const RULES: ScoreRules = preload("res://data/balance/score_rules.tres")

var _saved_state: GameManager.MatchState
var _saved_timer: float


func before_each() -> void:
	_saved_state = GameManager.current_state
	_saved_timer = GameManager.match_timer


func after_each() -> void:
	GameManager.current_state = _saved_state
	GameManager.match_timer = _saved_timer


func _map() -> HeistMap3D:
	var map: HeistMap3D = MAP_SCENE.instantiate() as HeistMap3D
	add_child_autofree(map)
	for guard: GuardController3D in map.guards:
		guard.set_physics_process(false)
	await wait_physics_frames(2)
	GameManager.current_state = GameManager.MatchState.IN_PROGRESS
	GameManager.match_timer = 600.0
	return map


func test_losing_them_needs_time_without_being_seen_or_hit() -> void:
	var events: ScoreEvents = ScoreEvents.new()
	events.tick({"G1": true}, Vector3.ZERO, 0, 0.0)
	events.tick({}, Vector3.ZERO, 0, RULES.lose_them_time - 0.5)
	events.tick({}, Vector3.ZERO, 1, RULES.lose_them_time)  # le pegan: vuelve a empezar
	events.tick({}, Vector3.ZERO, 1, RULES.lose_them_time * 1.5)
	assert_eq(events.lost, 0)
	events.tick({}, Vector3.ZERO, 1, RULES.lose_them_time * 2.0 + 0.1)
	assert_eq(events.lost, 1, "8 s sin verlo ni pegarle")
	events.tick({}, Vector3.ZERO, 1, RULES.lose_them_time * 4.0)
	assert_eq(events.lost, 1, "Una vez por cada vez que lo ven")


func test_walkie_hits_when_a_teammate_starts_seeing_him_near_the_mark() -> void:
	var events: ScoreEvents = ScoreEvents.new()
	events.on_ping("G1", Vector3(10, 0, 0), 0.0)
	events.tick({"G1": true}, Vector3(10, 0, 0), 0, 1.0)
	assert_eq(int(events.walkie.get("G1", 0)), 0, "Si lo ve el mismo, no")
	events.tick({"G2": true}, Vector3(10 + RULES.walkie_hit_radius + 1.0, 0, 0), 0, 2.0)
	assert_eq(int(events.walkie.get("G1", 0)), 0, "Lejos de la marca, no")
	events.tick({}, Vector3(12, 0, 0), 0, 2.5)
	events.tick({"G2": true}, Vector3(12, 0, 0), 0, 3.0)
	assert_eq(int(events.walkie.get("G1", 0)), 1, "Empieza a verlo cerca de la marca")
	events.tick({}, Vector3(12, 0, 0), 0, 3.5)
	events.tick({"G2": true}, Vector3(12, 0, 0), 0, 4.0)
	assert_eq(int(events.walkie.get("G1", 0)), 1, "Cada marca, una vez")
	events.on_ping("G1", Vector3(10, 0, 0), 5.0)
	events.tick({}, Vector3(10, 0, 0), 0, 5.0 + RULES.walkie_hit_window)
	events.tick({"G2": true}, Vector3(10, 0, 0), 0, 5.0 + RULES.walkie_hit_window + 0.5)
	assert_eq(int(events.walkie.get("G1", 0)), 1, "Fuera de tiempo, no")


func test_walkie_on_someone_a_teammate_already_sees_does_not_count() -> void:
	var events: ScoreEvents = ScoreEvents.new()
	for i: int in range(3):  # persecución: los dos lo ven y G1 marca a sus pies cada 10 s
		var now: float = i * 10.0
		events.tick({"G1": true, "G2": true}, Vector3.ZERO, 0, now)
		events.on_ping("G1", Vector3.ZERO, now)
		events.tick({"G1": true, "G2": true}, Vector3.ZERO, 0, now + 0.1)
	assert_eq(int(events.walkie.get("G1", 0)), 0)


func test_live_note_survives_the_sighting_turning_into_the_alarm() -> void:
	var live: LiveScore = autofree(LiveScore.create(&"guard_1"))
	live.update(MatchScore.live(MatchScore.guard({"seen": 1})))  # antes de decidir la alarma
	live.update(MatchScore.live(MatchScore.guard({"alarm": true})))  # esa vista era la alarma
	live.update(MatchScore.live(MatchScore.guard({"alarm": true, "seen": 1})))  # otra de verdad
	assert_eq(live.total, 75)
	assert_eq(live.notes, [[1, "+25 VISTO"], [2, "+50 ALARMA"], [3, "+25 VISTO"]])


func test_silent_theft_near_a_guard_costs_him() -> void:
	var map: HeistMap3D = await _map()
	var heist: HeistDirector = GameManager.heist
	var piece: TargetPiece3D = heist.piece(heist.targets[0])
	var near: GuardController3D = map.guards[0]
	var far: GuardController3D = map.guards[1]
	near.global_position = piece.global_position + Vector3(2.0, 0.0, 0.0)
	far.global_position = piece.global_position + Vector3(0.0, 0.0, 30.0)
	await wait_physics_frames(2)
	piece.steal(false)
	var events: ScoreEvents = MatchRecorder.of(get_tree()).events
	assert_eq(int(events.near_theft.get(String(near.name), 0)), 1, "A 2 m, sin muros")
	assert_eq(int(events.near_theft.get(String(far.name), 0)), 0)
	var other: TargetPiece3D = heist.piece(heist.targets[1])
	near.global_position = other.global_position + Vector3(2.0, 0.0, 0.0)
	await wait_physics_frames(2)
	other.steal(true)
	assert_eq(int(events.near_theft.get(String(near.name), 0)), 1, "A lo bruto no cuenta")


func test_examined_fake_counts_and_gives_the_alarm_by_traces() -> void:
	var map: HeistMap3D = await _map()
	var heist: HeistDirector = GameManager.heist
	var alert: AlertDirector = AlertDirector.of(get_tree())
	var first: TargetPiece3D = heist.piece(heist.targets[0])
	first.steal(false, TargetPieceLook.Flaw.TINT)
	first.discovered = true  # el primer rastro, de nadie
	alert.scan()
	var second: TargetPiece3D = heist.piece(heist.targets[1])
	second.steal(false, TargetPieceLook.Flaw.SIZE)
	var guard: GuardController3D = map.guards[1]
	second._finish_inspect(guard)
	alert.scan()
	assert_eq(alert.level, AlertDirector.Level.ALARM, "Dos rastros")
	assert_eq(alert.alarm_by, String(guard.name), "La alarma es de quien descubre el segundo")
	assert_false(alert.alarm_sight)
	var report: Dictionary = MatchRecorder.of(get_tree()).build_report()
	var entry: Dictionary = report["guards"][1]
	assert_true(entry["alarm"])
	assert_eq(int(entry["examined"]), 1)
	assert_eq(int(report["thief"]["clean"]), 0, "Las dos descubiertas")


func test_alarm_by_sight_is_not_also_a_sighting() -> void:
	var map: HeistMap3D = await _map()
	var alert: AlertDirector = AlertDirector.of(get_tree())
	var guard: GuardController3D = map.guards[0]
	var recorder: MatchRecorder = MatchRecorder.of(get_tree())
	recorder.track(String(guard.name), true, false, 1.0)
	recorder.track(String(guard.name), true, false, 10.0)
	alert.raise(AlertDirector.Level.ALARM, Vector3.ZERO, String(guard.name), true)
	var entry: Dictionary = recorder.build_report()["guards"][0]
	assert_true(entry["alarm"])
	assert_eq(int(entry["seen"]), 1, "Dos vistas: una es la alarma (+50) y otra +25")
	assert_eq(int(recorder.build_report()["thief"]["seen"]), 2, "El ladrón pierde las dos")


func test_clean_piece_fast_escape_and_hits_taken_in_the_report() -> void:
	var map: HeistMap3D = await _map()
	var heist: HeistDirector = GameManager.heist
	heist.piece(heist.targets[0]).steal(false, TargetPieceLook.Flaw.POSE)
	map.guards[0].set_meta(MatchRecorder.HITS_META, 1)
	var lockdown: HeistLockdown = HeistLockdown.of(get_tree())
	lockdown.left = 12.7
	GameManager.current_state = GameManager.MatchState.THIEF_ESCAPED_PARTIAL
	var report: Dictionary = MatchRecorder.of(get_tree()).build_report()
	var thief: Dictionary = report["thief"]
	assert_eq(int(thief["clean"]), 1, "Nadie la examinó")
	assert_eq(int(thief["fast"]), 12)
	assert_eq(int(thief["hits_taken"]), 1)
	assert_eq(int(thief["guards"]), map.guards.size())
	lockdown.closed = true
	assert_eq(
		int(MatchRecorder.of(get_tree()).build_report()["thief"]["fast"]), 0, "Tras el cierre"
	)


func test_each_player_gets_only_its_live_score() -> void:
	var map: HeistMap3D = await _map()
	var guard: GuardController3D = map.guards[0]
	var role: StringName = LiveScore.guard_role(guard)
	assert_eq(role, &"guard_1")
	MatchRecorder.of(get_tree()).track(String(guard.name), true, false, 1.0)
	await wait_physics_frames(roundi(MatchRecorder.LIVE_TICK * 60.0) + 2)
	var live: LiveScore = LiveScore.of(get_tree(), role)
	assert_eq(live.total, RULES.guard_seen)
	assert_eq(live.notes.back()[1], "+25 VISTO")
	assert_eq(live.net_private_audience(), &"guard_1")
	var thief_live: LiveScore = LiveScore.of(get_tree(), &"thief")
	assert_eq(thief_live.total, RULES.thief_seen)
	assert_eq(LiveScore.local_role(map), &"thief", "Sin red se juega con el ladrón")


func test_a_guard_whose_player_left_stops_counting() -> void:
	var map: HeistMap3D = await _map()
	var gone: GuardController3D = map.guards[0]
	var session: NetSession = autofree(NetSession.new())
	session.map = map
	var server: NetSessionServer = NetSessionServer.new()
	server._session = session
	server._peer_roles[7] = LiveScore.guard_role(gone)
	server._on_peer_disconnected(7)
	var recorder: MatchRecorder = MatchRecorder.of(get_tree())
	recorder.track(String(gone.name), true, false, 1.0)
	await wait_physics_frames(2)
	var report: Dictionary = recorder.build_report()
	assert_eq((report["guards"] as Array).size(), map.guards.size() - 1, "Sin su ficha")
	assert_eq(int(report["thief"]["guards"]), map.guards.size() - 1, "G son los que siguen")
	assert_eq(int(report["guards"][0]["guards"]), map.guards.size() - 1)
