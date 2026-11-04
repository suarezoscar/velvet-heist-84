## @file test_guard_sleep.gd
## Sueño del guardia y café (heist.md R5, #116): fuera de la garita el sueño sube, dentro se
## congela (también con el café, la alarma o viendo al ladrón); bosteza y ve menos, da cabezadas,
## el café lo quita, duermen también los guardias de la IA y el estado solo le llega a su guardia.
extends GutTest

const MAP_SCENE: PackedScene = preload("res://scenes/maps/museum_v2.tscn")
const RULES: GuardSleepRules = preload("res://data/balance/guard_sleep.tres")
## Segundos fuera de la garita hasta somnoliento (~180 s) y hasta agotado (~240 s)
const DROWSY_AT: float = 0.75 / 0.004167
const EXHAUSTED_AT: float = 1.0 / 0.004167

var _saved_state: GameManager.MatchState
var _voices: int = 0


func before_each() -> void:
	_saved_state = GameManager.current_state
	_voices = 0
	SignalBus.noise_event_3d.connect(_on_noise)


func after_each() -> void:
	GameManager.current_state = _saved_state
	SignalBus.noise_event_3d.disconnect(_on_noise)


func _on_noise(_p: Vector3, _r: float, _t: StringName, category: StringName, _e: Node) -> void:
	if category == &"voice":
		_voices += 1


func _human_guard() -> GuardController3D:
	var map: HeistMap3D = MAP_SCENE.instantiate() as HeistMap3D
	add_child_autofree(map)
	var guard: GuardController3D = map.guards[0]
	guard.is_ai_controlled = false
	guard.set_physics_process(false)
	return guard


func _sleep(guard: GuardController3D) -> GuardSleep:
	return guard.get_node("Sleep") as GuardSleep


## Saca al guardia de la garita (a una sala cualquiera del museo)
func _leave_post(guard: GuardController3D) -> void:
	var patrol: GuardPatrol = GuardPatrol.of(get_tree())
	guard.global_position = patrol.room_center("ORI")


func _run(sleep: GuardSleep, seconds: float) -> void:
	for i: int in range(roundi(seconds / 0.5)):
		sleep.step(0.5)


func test_guard_outside_gets_drowsy_yawns_and_sees_less() -> void:
	var guard: GuardController3D = _human_guard()
	await wait_physics_frames(1)
	_leave_post(guard)
	var sleep: GuardSleep = _sleep(guard)
	_run(sleep, DROWSY_AT - 10.0)
	assert_eq(sleep.stage(), GuardSleep.Stage.AWAKE, "A los ~170 s sigue despierto")
	assert_eq(_voices, 0, "Sin bostezos")
	_run(sleep, 15.0)
	assert_eq(sleep.stage(), GuardSleep.Stage.DROWSY, "Somnoliento a los ~180 s")
	assert_gt(_voices, 0, "Bosteza y se oye")
	assert_almost_eq(
		guard.perception.lit_sight_range,
		GuardSleep.PERCEPTION.lit_sight_range * RULES.drowsy_sight,
		0.01,
		"Ve menos"
	)
	_run(sleep, EXHAUSTED_AT - DROWSY_AT - 15.0)
	assert_eq(sleep.stage(), GuardSleep.Stage.DROWSY, "A los ~230 s todavía no")
	_run(sleep, 20.0)
	assert_eq(sleep.stage(), GuardSleep.Stage.EXHAUSTED, "Agotado a los ~240 s")
	var nodded: bool = false
	for i: int in range(40):
		sleep.step(0.5)
		if sleep.nodding:
			nodded = true
			assert_eq(guard.perception.lit_sight_range, 0.0, "En la cabezada no ve nada")
	assert_true(nodded, "Da cabezadas")


func test_coffee_clears_sleep_and_must_stay() -> void:
	var guard: GuardController3D = _human_guard()
	await wait_physics_frames(1)
	var sleep: GuardSleep = _sleep(guard)
	var machine: CoffeeMachine3D = get_tree().get_first_node_in_group(&"coffee_machine")
	_leave_post(guard)
	_run(sleep, DROWSY_AT + 10.0)
	assert_string_contains(
		machine.get_interaction_text(get_tree().get_first_node_in_group(&"thief")),
		"somnífero",
		"El ladrón no se sirve café: lo droga (FEAT-033)"
	)
	assert_true(machine.can_interact(guard))
	machine.interact(guard)
	guard.global_position += Vector3(RULES.coffee_leash + 1.0, 0.0, 0.0)
	_run(sleep, RULES.coffee_time + 1.0)
	assert_gt(sleep.level, 0.0, "Si se va, el café no cuenta")
	machine.interact(guard)
	_run(sleep, RULES.coffee_time + 0.5)
	assert_eq(sleep.level, 0.0, "Café: sin sueño")
	assert_gt(sleep.fresh_left, 0.0, "Y despejado un rato")
	_run(sleep, RULES.fresh_time - 10.0)
	assert_eq(sleep.level, 0.0, "Despejado, no sube aunque esté fuera de la garita")


func test_ai_guards_sleep_too() -> void:
	var map: HeistMap3D = MAP_SCENE.instantiate() as HeistMap3D
	add_child_autofree(map)
	await wait_physics_frames(1)
	GameManager.current_state = GameManager.MatchState.IN_PROGRESS
	var ai_guard: GuardController3D = map.guards[0]
	assert_true(ai_guard.is_ai_controlled, "Es de la IA")
	assert_true(_sleep(ai_guard).is_active(), "La IA también duerme (#116)")
	_leave_post(ai_guard)
	_run(_sleep(ai_guard), 100.0)
	assert_almost_eq(_sleep(ai_guard).level, 100.0 * RULES.rise_rate, 0.001, "Y le sube")


func test_sleep_rises_only_outside_the_post() -> void:
	var guard: GuardController3D = _human_guard()
	await wait_physics_frames(1)
	var sleep: GuardSleep = _sleep(guard)
	var patrol: GuardPatrol = GuardPatrol.of(get_tree())
	guard.global_position = patrol.room_center("GAR")
	assert_true(patrol.in_guard_post(guard.global_position), "Parte de la garita")
	sleep.step(10.0)
	assert_eq(sleep.level, 0.0, "Dentro de la garita no sube")
	_leave_post(guard)
	sleep.step(10.0)
	assert_almost_eq(sleep.level, 10.0 * RULES.rise_rate, 0.0001, "Fuera sube rise_rate·delta")
	guard.global_position = patrol.room_center("GAR")
	var frozen: float = sleep.level
	sleep.step(10.0)
	assert_eq(sleep.level, frozen, "Al volver a la garita se congela")


func test_sleep_does_not_rise_when_fresh_alarm_or_chase() -> void:
	var guard: GuardController3D = _human_guard()
	await wait_physics_frames(1)
	_leave_post(guard)
	var sleep: GuardSleep = _sleep(guard)
	sleep.fresh_left = 30.0
	sleep.step(10.0)
	assert_eq(sleep.level, 0.0, "Despejado por el café, no sube")
	sleep.fresh_left = 0.0
	var alert: AlertDirector = AlertDirector.of(get_tree())
	alert.level = AlertDirector.Level.ALARM
	assert_false(sleep.rises(1.0), "Con la alarma sonando, no sube")
	sleep.step(10.0)
	assert_eq(sleep.level, 0.0)
	alert.level = AlertDirector.Level.CALM
	assert_true(sleep.rises(1.0), "En calma y fuera, sube")
	guard.is_perceiving_thief = true
	_run(sleep, DROWSY_AT + 60.0)
	assert_eq(sleep.level, 0.0, "Persiguiendo no le entra sueño")


func test_sleep_state_is_private_to_its_guard() -> void:
	var guard: GuardController3D = _human_guard()
	await wait_physics_frames(1)
	var sleep: GuardSleep = _sleep(guard)
	assert_eq(sleep.net_private_audience(), &"guard_1")
	assert_eq(sleep.get_net_state().keys(), ["zzz"], "Público solo el «Zzz» (FEAT-033)")
	sleep.level = 0.783
	assert_almost_eq(float(sleep.get_net_state_private()["level"]), 0.8, 0.001, "Redondeado")
	assert_string_contains(SleepHud84.status_text(sleep), "SOMNOLIENTO")


func test_audience_follows_scene_order_not_guard_id() -> void:
	var map: HeistMap3D = MAP_SCENE.instantiate() as HeistMap3D
	add_child_autofree(map)
	await wait_physics_frames(1)
	map.guards[0].guard_id = 7  # un guard_id que no cuadra con el rol no debe importar
	assert_eq(_sleep(map.guards[0]).net_private_audience(), &"guard_1")
	assert_eq(_sleep(map.guards[1]).net_private_audience(), &"guard_2")
	assert_false(NetPrivateStates.audience_matches(&"guard_1", &"thief"), "Al ladrón no le llega")
	assert_false(NetPrivateStates.audience_matches(&"guard_1", &"guard_2"), "Ni a otro guardia")


func test_nodding_guard_does_not_see_cameras() -> void:
	var guard: GuardController3D = _human_guard()
	await wait_physics_frames(1)
	guard.monitor_watch.state = GuardMonitorWatch.State.WATCHING
	var guards: Array[GuardController3D] = [guard]
	assert_eq(
		NetVisibility.guard_views(guards, true)[&"guard_1"], &"cctv", "Despierto, ve las cámaras"
	)
	_sleep(guard).nodding = true
	assert_eq(NetVisibility.guard_views(guards, true)[&"guard_1"], &"", "En la cabezada, nada")
	guard.monitor_watch.state = GuardMonitorWatch.State.NONE


func test_yawn_has_sound() -> void:
	var mix: NoiseMix = load("res://assets/audio/noise_mix.tres") as NoiseMix
	assert_false(mix.streams_for(&"voice", 1.0).is_empty(), "El bostezo suena")
