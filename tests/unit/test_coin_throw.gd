## @file test_coin_throw.gd
## La moneda del ladrón (FEAT-038): apuntar manteniendo, lanzar al soltar y cancelar con el
## clic izquierdo; alcance, arco y tiempo de vuelo; quién la ve.
extends GutTest

const RULES: HeistRules = preload("res://data/balance/heist_rules.tres")
const FIXTURE_PATH: String = "res://tests/fixtures/level_small.json"
const THIEF_SCENE: PackedScene = preload("res://scenes/entities/thief_player.tscn")
const GUARD_SCENE: PackedScene = preload("res://scenes/entities/guard_player.tscn")


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


## Nivel pequeño de los tests (sala A de x 0-8, sala B de x 8-14, muro en x = 8 con puerta en
## z 2,4-3,6) con un actor en (2, 0, 1)
func _level_with(scene: PackedScene) -> PlayerBase3D:
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	LevelArchitectureBuilder.build(LevelData.load_json(FIXTURE_PATH), root)
	var actor: PlayerBase3D = scene.instantiate() as PlayerBase3D
	actor.is_locally_controlled = false
	root.add_child(actor)
	actor.global_position = Vector3(2.0, 0.0, 1.0)
	return actor


func test_guard_sees_the_coin_only_with_it_in_view() -> void:
	var guard: GuardController3D = _level_with(GUARD_SCENE) as GuardController3D
	await wait_physics_frames(2)
	var near: Vector3 = Vector3(4.0, 0.0, 1.0)
	var out_of_range: Vector3 = Vector3(2.0, 0.0, 60.0)
	var behind_wall_a: Vector3 = Vector3(11.0, 0.0, 0.5)
	var behind_wall_b: Vector3 = Vector3(12.0, 0.0, 1.0)
	assert_true(CoinFlightPresenter.visible_to(guard, near, near), "La ve salir a 2 m")
	assert_true(
		CoinFlightPresenter.visible_to(guard, out_of_range, near), "Ve caer la que viene de lejos"
	)
	assert_false(
		CoinFlightPresenter.visible_to(guard, behind_wall_a, behind_wall_b),
		"Tras el muro, dentro del radio, no la ve"
	)
	var sleep: GuardSleep = GuardSleep.attach(guard)
	sleep.nodding = true
	assert_false(CoinFlightPresenter.visible_to(guard, near, near), "Dando una cabezada no ve nada")


func test_coin_stops_short_of_a_wall() -> void:
	var thief: PlayerBase3D = _level_with(THIEF_SCENE)
	await wait_physics_frames(2)
	var landing: Vector3 = CoinThrow.landing(thief, Vector3(13.0, 0.0, 1.0))
	assert_lt(landing.x, 8.0, "No atraviesa el muro de x = 8")
	assert_gt(landing.x, 7.0, "Cae junto al muro")


func test_guard_that_only_sees_the_landing_does_not_learn_the_origin() -> void:
	var guard: GuardController3D = _level_with(GUARD_SCENE) as GuardController3D
	await wait_physics_frames(2)
	var landing: Vector3 = Vector3(4.0, 0.0, 1.0)
	var far_origin: Vector3 = Vector3(2.0 + 30.0, 1.2, 1.0)
	var view: Dictionary = CoinFlightPresenter.view_for(guard, far_origin, landing, 0.5)
	assert_false(view.is_empty(), "Ve la moneda caer")
	var shown: Vector3 = view["from"]
	assert_ne(shown, far_origin, "No recibe desde dónde se lanzó")
	assert_true(VisionLogic.sees_point(guard, shown), "El tramo empieza dentro de su vista")
	assert_gt(shown.x, landing.x, "Pero sí de qué lado viene")
	assert_lt(float(view["flight"]), 0.5, "Vuelo acortado para caer a la vez")
	assert_almost_eq(
		shown.y, landing.y + CoinThrow.HAND_HEIGHT, 0.01, "La altura no delata el origen"
	)
	assert_almost_eq(
		float(view["delay"]) + float(view["flight"]), 0.5, 0.001, "Empieza a verla cuando entra"
	)
	var near: Vector3 = Vector3(3.0, 1.2, 1.0)
	assert_eq(
		CoinFlightPresenter.view_for(guard, near, landing, 0.3)["from"], near, "Si ve salir, entera"
	)
