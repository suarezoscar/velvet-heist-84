## @file test_guard_sleep.gd
## Sueño del guardia y café (heist.md R5, FEAT-029): acampar se mide por permanencia en un
## círculo (los pasitos no engañan), el sueño sube, bosteza y ve menos, da cabezadas, el café
## lo quita, y el estado solo le llega a su guardia.
extends GutTest

const MAP_SCENE: PackedScene = preload("res://scenes/maps/museum_v2.tscn")
const RULES: GuardSleepRules = preload("res://data/balance/guard_sleep.tres")

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


func _run(sleep: GuardSleep, seconds: float) -> void:
	for i: int in range(roundi(seconds / 0.5)):
		sleep.step(0.5)


func test_camping_is_presence_not_stillness() -> void:
	var meter: CampingMeter = CampingMeter.new()
	var max_samples: int = 20
	for i: int in range(max_samples):
		var shuffle: float = 1.5 if i % 2 == 0 else -1.5  # pasitos adelante y atrás
		meter.feed(Vector3(shuffle, 0.0, 0.0), 1.0, max_samples)
	assert_true(
		meter.is_camping(8.0, 0.75, max_samples), "Ir y venir dentro del círculo es acampar"
	)
	var walker: CampingMeter = CampingMeter.new()
	for i: int in range(max_samples):
		walker.feed(Vector3(float(i) * 3.0, 0.0, 0.0), 1.0, max_samples)
	assert_false(walker.is_camping(8.0, 0.75, max_samples), "Patrullar no")
	var short: CampingMeter = CampingMeter.new()
	short.feed(Vector3.ZERO, 1.0, max_samples)
	assert_false(short.is_camping(8.0, 0.75, max_samples), "Sin ventana llena, no se sabe")


func test_camping_guard_gets_drowsy_yawns_and_sees_less() -> void:
	var guard: GuardController3D = _human_guard()
	await wait_physics_frames(1)
	var sleep: GuardSleep = _sleep(guard)
	_run(sleep, RULES.window + 50.0)
	assert_eq(sleep.stage(), GuardSleep.Stage.DROWSY, "Somnoliento")
	assert_gt(_voices, 0, "Bosteza y se oye")
	assert_almost_eq(
		guard.perception.lit_sight_range,
		GuardSleep.PERCEPTION.lit_sight_range * RULES.drowsy_sight,
		0.01,
		"Ve menos"
	)
	_run(sleep, 60.0)
	assert_eq(sleep.stage(), GuardSleep.Stage.EXHAUSTED, "Agotado")
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
	_run(sleep, RULES.window + 50.0)
	assert_false(
		machine.can_interact(get_tree().get_first_node_in_group(&"thief")), "Solo guardias"
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
	_run(sleep, RULES.window + 20.0)
	assert_eq(sleep.level, 0.0, "Despejado, no sube aunque acampe")


func test_ai_guards_and_chases_do_not_sleep() -> void:
	var map: HeistMap3D = MAP_SCENE.instantiate() as HeistMap3D
	add_child_autofree(map)
	await wait_physics_frames(1)
	assert_false(_sleep(map.guards[0]).is_active(), "La IA no duerme")
	var guard: GuardController3D = map.guards[1]
	guard.is_ai_controlled = false
	guard.set_physics_process(false)
	guard.is_perceiving_thief = true
	_run(_sleep(guard), RULES.window + 60.0)
	assert_eq(_sleep(guard).level, 0.0, "Persiguiendo no le entra sueño")


func test_sleep_state_is_private_to_its_guard() -> void:
	var guard: GuardController3D = _human_guard()
	await wait_physics_frames(1)
	var sleep: GuardSleep = _sleep(guard)
	assert_eq(sleep.net_private_audience(), &"guard_1")
	assert_true(sleep.get_net_state().is_empty(), "Nada público")
	sleep.level = 0.523
	assert_almost_eq(float(sleep.get_net_state_private()["level"]), 0.5, 0.001, "Redondeado")
	assert_string_contains(SleepHud84.status_text(sleep), "SOMNOLIENTO")
