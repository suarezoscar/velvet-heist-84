## @file test_coin_throw.gd
## La moneda del ladrón (FEAT-038): apuntar manteniendo, lanzar al soltar y cancelar con el
## clic izquierdo; alcance, arco y tiempo de vuelo; quién la ve.
extends GutTest

const RULES: HeistRules = preload("res://data/balance/heist_rules.tres")


func after_each() -> void:
	CoinTrigger.reset()


func test_hold_aims_and_release_throws() -> void:
	assert_false(CoinTrigger.step(true, false, false), "Pulsar no lanza")
	assert_true(CoinTrigger.aiming, "Apunta mientras lo mantiene")
	assert_false(CoinTrigger.step(false, false, false))
	assert_true(CoinTrigger.step(false, true, false), "Soltar lanza")
	assert_false(CoinTrigger.aiming)


func test_quick_click_throws() -> void:
	assert_true(CoinTrigger.step(true, true, false), "Pulsar y soltar en el mismo fotograma")


func test_left_click_cancels_without_throwing() -> void:
	CoinTrigger.step(true, false, false)
	assert_false(CoinTrigger.step(false, false, true), "Cancelar no lanza")
	assert_false(CoinTrigger.aiming, "Deja de apuntar")
	assert_false(CoinTrigger.step(false, true, false), "Soltar tras cancelar no lanza")
	assert_true(CoinTrigger.step(true, true, false), "El siguiente lanzamiento va bien")


func test_release_without_aiming_does_nothing() -> void:
	assert_false(CoinTrigger.step(false, true, false))


func test_flight_time_grows_with_distance() -> void:
	var near: float = CoinThrow.flight_time(Vector3.ZERO, Vector3(2.0, 0.0, 0.0))
	var far: float = CoinThrow.flight_time(Vector3.ZERO, Vector3(RULES.throw_range, 0.0, 0.0))
	assert_almost_eq(far, RULES.coin_flight_time, 0.001, "A todo el alcance")
	assert_lt(near, far)
	assert_gte(CoinThrow.flight_time(Vector3.ZERO, Vector3.ZERO), CoinThrow.MIN_FLIGHT)


func test_arc_starts_in_hand_rises_and_lands() -> void:
	var from: Vector3 = Vector3(0.0, 1.2, 0.0)
	var to: Vector3 = Vector3(8.0, 0.0, 0.0)
	assert_eq(CoinThrow.arc_point(from, to, 0.0), from)
	assert_eq(CoinThrow.arc_point(from, to, 1.0), to)
	var middle: Vector3 = CoinThrow.arc_point(from, to, 0.5)
	assert_gt(middle.y, from.lerp(to, 0.5).y + 1.0, "Sube por encima de la línea recta")


func test_landing_is_limited_by_range_and_walls_in_the_museum() -> void:
	var map: HeistMap3D = (load("res://scenes/maps/museum_v2.tscn") as PackedScene).instantiate()
	add_child_autofree(map)
	await wait_physics_frames(3)
	var thief: ThiefController3D = map.thief
	var far_aim: Vector3 = thief.global_position + Vector3(60.0, 0.0, 0.0)
	var landing: Vector3 = CoinThrow.landing(thief, far_aim)
	var flat: Vector2 = Vector2(
		landing.x - thief.global_position.x, landing.z - thief.global_position.z
	)
	assert_lte(flat.length(), RULES.throw_range + 0.01, "Nunca más allá del alcance")
	assert_almost_eq(landing.y, thief.global_position.y, 0.01, "Cae al suelo del ladrón")
	assert_true(
		CoinFlightPresenter.visible_to(thief, CoinThrow.origin(thief), landing),
		"El ladrón ve siempre su moneda"
	)
	var guard: GuardController3D = map.guards[0]
	var far_away: Vector3 = guard.global_position + Vector3(200.0, 0.0, 200.0)
	assert_false(
		CoinFlightPresenter.visible_to(guard, far_away, far_away), "Un guardia lejos no la ve"
	)
