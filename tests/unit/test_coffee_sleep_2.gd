## @file test_coffee_sleep_2.gd
## Café y sueño 2 (FEAT-033): el somnífero del ladrón duerme al siguiente guardia que se sirve
## café, la alarma despeja (adrenalina) y el fin de las luces de alarma da el bajón, el «Zzz»
## es público y el botín pesa.
extends GutTest

const MAP_SCENE: PackedScene = preload("res://scenes/maps/museum_v2.tscn")
const RULES: GuardSleepRules = preload("res://data/balance/guard_sleep.tres")
const HEIST_RULES: HeistRules = preload("res://data/balance/heist_rules.tres")

var _saved_state: GameManager.MatchState


func before_each() -> void:
	_saved_state = GameManager.current_state


func after_each() -> void:
	GameManager.current_state = _saved_state


func _map() -> HeistMap3D:
	var map: HeistMap3D = MAP_SCENE.instantiate() as HeistMap3D
	add_child_autofree(map)
	var guard: GuardController3D = map.guards[0]
	guard.is_ai_controlled = false
	guard.set_physics_process(false)
	return map


func _sleep(guard: GuardController3D) -> GuardSleep:
	return guard.get_node("Sleep") as GuardSleep


func _run(sleep: GuardSleep, seconds: float) -> void:
	for i: int in range(roundi(seconds / 0.5)):
		sleep.step(0.5)


func _machine() -> CoffeeMachine3D:
	return get_tree().get_first_node_in_group(&"coffee_machine") as CoffeeMachine3D


func _drug(machine: CoffeeMachine3D, thief: ThiefController3D) -> void:
	thief.global_position = machine.global_position + Vector3(0.8, 0.0, 0.0)
	assert_true(machine.can_interact(thief), "El ladrón puede drogar la cafetera")
	machine.interact(thief)
	for i: int in range(roundi(RULES.drug_time / 0.5) + 1):
		machine._physics_process(0.5)


func test_drugged_coffee_puts_the_next_guard_to_sleep() -> void:
	var map: HeistMap3D = _map()
	await wait_physics_frames(1)
	var guard: GuardController3D = map.guards[0]
	var sleep: GuardSleep = _sleep(guard)
	var machine: CoffeeMachine3D = _machine()
	_drug(machine, map.thief)
	assert_true(machine.drugged, "Drogada")
	assert_eq(machine.doses_left, RULES.drug_doses - 1, "Gasta la dosis")
	assert_false(machine.can_interact(map.thief), "Una vez basta")
	assert_eq(machine.get_net_state(), {}, "Los guardias no saben nada")
	assert_eq(machine.net_private_audience(), &"thief")
	guard.global_position = machine.global_position + Vector3(0.0, 0.0, 0.8)
	machine.interact(guard)
	_run(sleep, RULES.coffee_time + 0.5)
	assert_true(sleep.drugged and sleep.nodding, "Se duerme")
	assert_true(GuardSleep.sees_nothing(guard), "Dormido no ve nada")
	assert_eq(sleep.get_net_state()["zzz"], true, "Todos ven el «Zzz»")
	assert_string_contains(SleepHud84.status_text(sleep), "DROGADO")
	assert_false(machine.drugged, "La cafetera queda limpia")
	_run(sleep, RULES.drug_nap_time + 0.5)
	assert_false(sleep.nodding, "Despierta")
	assert_false(sleep.drugged)
	assert_eq(sleep.stage(), GuardSleep.Stage.EXHAUSTED, "Despierta agotado: a por otro café")
	machine.interact(guard)
	_run(sleep, RULES.coffee_time + 0.5)
	assert_eq(sleep.level, 0.0, "El siguiente café ya es normal")


func test_alarm_wakes_and_flood_end_crashes() -> void:
	var map: HeistMap3D = _map()
	await wait_physics_frames(1)
	var sleep: GuardSleep = _sleep(map.guards[0])
	var alert: AlertDirector = AlertDirector.of(get_tree())
	sleep.level = 0.9
	alert.raise(AlertDirector.Level.ALARM)
	assert_eq(sleep.level, 0.0, "Adrenalina: la alarma le despeja")
	assert_true(alert.flood(map.guards[0].global_position), "Luces de alarma")
	alert._tick_flood(HEIST_RULES.flood_time + 0.1)
	assert_almost_eq(sleep.level, RULES.crash_level, 0.001, "Bajón al apagarse")
	assert_eq(sleep.stage(), GuardSleep.Stage.DROWSY, "Somnoliento hasta que tome café")


func test_loot_slows_the_thief() -> void:
	var map: HeistMap3D = _map()
	await wait_physics_frames(1)
	var thief: ThiefController3D = map.thief
	assert_eq(thief.speed_factor(), 1.0, "Sin botín, a su paso")
	GameManager.heist.stolen.assign([&"T1", &"T2"])
	assert_almost_eq(thief.speed_factor(), 1.0 - 2.0 * HEIST_RULES.loot_slow, 0.001)
	GameManager.heist.stolen.assign([&"A", &"B", &"C", &"D", &"E", &"F", &"G", &"H"])
	assert_eq(thief.speed_factor(), HEIST_RULES.loot_min_speed, "Con un tope")
	assert_eq(map.guards[0].speed_factor(), 1.0, "Los guardias no cargan nada")
