## @file test_vents.gd
## Conductos (heist.md R10, reescrita con #167): se elige la salida fuera, en el plano, quieto y
## a la vista; solo tras elegir se cuela; el viaje dura la distancia (con botín) hasta un
## máximo, la cámara va de una rejilla a otra y no se puede esperar dentro.
extends GutTest

const MAP_SCENE: PackedScene = preload("res://scenes/maps/museum_v2.tscn")
const RULES: VentRules = preload("res://data/balance/vent_rules.tres")

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
	map.thief.set_physics_process(false)
	await wait_physics_frames(2)
	GameManager.current_state = GameManager.MatchState.IN_PROGRESS
	GameManager.match_timer = 600.0
	return map


func _tick(node: Node, seconds: float) -> void:
	for i: int in range(roundi(seconds / 0.1)):
		node._physics_process(0.1)


func test_choose_outside_then_enter_and_travel() -> void:
	var map: HeistMap3D = await _map()
	var thief: ThiefController3D = map.thief
	var travel: VentTravel = VentTravel.of(get_tree())
	var entry: Vent3D = travel.get_node("Vent_V_TAL") as Vent3D
	for guard: GuardController3D in map.guards:
		assert_false(entry.can_interact(guard), "Los guardias no entran (cerrada)")
	thief.global_position = entry.exit_point()
	entry.interact(thief)
	assert_eq(travel.phase, VentTravel.Phase.CHOOSING, "E abre el plano")
	assert_false(thief.in_vent, "Fuera, a la vista")
	assert_false(travel.choices.has(entry), "No se ofrece la de entrada")
	assert_eq(travel.choices.size(), 2, "Las otras dos de la red de servicio")
	for i: int in range(travel.choices.size()):
		assert_lte(travel.seconds_to(travel.selected), travel.seconds_to(i), "La más corta")
	thief.apply_input({"movement_vector": Vector2(0.0, 1.0)})
	assert_eq(thief.current_input_dir, Vector2.ZERO, "Quieto ante la rejilla")
	var first: int = travel.selected
	assert_true(thief.perform_action(VentTravel.NEXT))
	assert_ne(travel.selected, first, "→ cambia de salida")
	var target: Vent3D = travel.target()
	assert_true(thief.perform_action(&"interact"), "E confirma")
	assert_eq(travel.phase, VentTravel.Phase.ENTERING, "Se cuela")
	_tick(entry, RULES.enter_time + 0.1)
	assert_eq(travel.phase, VentTravel.Phase.TRAVELING)
	assert_true(thief.in_vent, "Dentro")
	assert_true(entry.open_left > 0.0, "La rejilla queda abierta: rastro")
	var expected: float = VentTravel.travel_time(entry.global_position, target.global_position, 0)
	assert_almost_eq(travel.total, expected, 0.01, "Tarda la distancia a travel_speed")
	assert_lte(travel.total, RULES.max_travel_time)
	travel.left = travel.total * 0.5
	var mid: Vector3 = entry.exit_point().lerp(target.exit_point(), 0.5)
	assert_almost_eq(
		VentTravel.focus(get_tree(), thief).x, mid.x, 0.01, "La cámara, a medio camino"
	)
	assert_false(thief.perform_action(&"interact"), "Dentro no se puede dar la vuelta")
	_tick(travel, travel.left + 0.2)
	assert_false(thief.in_vent, "Sale solo al llegar")
	assert_almost_eq(thief.global_position.x, target.exit_point().x, 0.2, "Por la elegida")
	assert_true(target.open_left > 0.0, "Y la deja abierta")


func test_closing_the_map_or_a_hit_does_not_enter() -> void:
	var map: HeistMap3D = await _map()
	var thief: ThiefController3D = map.thief
	var travel: VentTravel = VentTravel.of(get_tree())
	var entry: Vent3D = travel.get_node("Vent_V_GW") as Vent3D
	thief.global_position = entry.exit_point()
	entry.interact(thief)
	assert_true(thief.perform_action(&"dial_cancel"), "Esc, W o S cierran")
	assert_eq(travel.phase, VentTravel.Phase.NONE)
	entry.interact(thief)
	var guard: GuardController3D = map.guards[0]
	guard.global_position = thief.global_position + Vector3(0.6, 0.0, 0.0)
	guard.look_at(thief.global_position)
	thief.register_baton_hit()  # le pegan mientras elige
	travel._physics_process(0.1)
	assert_eq(travel.phase, VentTravel.Phase.NONE, "El golpe cierra el plano")
	assert_false(thief.in_vent)


func test_travel_time_has_a_maximum_even_with_loot() -> void:
	var far: float = VentTravel.travel_time(Vector3.ZERO, Vector3(100.0, 0.0, 0.0), 3)
	assert_eq(far, RULES.max_travel_time, "Nunca más de 10 s")
	var near: float = VentTravel.travel_time(Vector3.ZERO, Vector3(4.0, 0.0, 0.0), 0)
	assert_almost_eq(near, 4.0 / RULES.travel_speed, 0.001)


func test_vent_state_only_reaches_the_thief() -> void:
	var map: HeistMap3D = await _map()
	var travel: VentTravel = VentTravel.of(get_tree())
	assert_true(travel.get_net_state().is_empty(), "Nada público")
	var collected: Dictionary = NetPrivateStates.new().collect({"Props/Vents": travel}, true)
	assert_true(NetPrivateStates.for_role(collected, &"guard_1").is_empty(), "Guardias: nada")
	assert_true(NetPrivateStates.for_role(collected, &"thief").has("Props/Vents#private"))
	travel.apply_net_state({"phase": 1, "entry": "V_TAL", "choices": ["V_MNT"], "sel": 0})
	assert_false(map.thief.in_vent, "Eligiendo, fuera")
	assert_true(VentTravel.holds(map.thief), "Pero quieto")
	travel.apply_net_state({"phase": 2, "entry": "V_TAL", "choices": ["V_MNT"], "sel": 0})
	assert_true(map.thief.in_vent, "Viajando, dentro")
	travel.apply_net_state({"phase": 0})


func test_mouse_pick_becomes_steps_and_confirm() -> void:
	var map: HeistMap3D = await _map()
	var travel: VentTravel = VentTravel.of(get_tree())
	var entry: Vent3D = travel.get_node("Vent_V_TAL") as Vent3D
	map.thief.global_position = entry.exit_point()
	entry.interact(map.thief)
	VentInput.pick(2, 0, 3)
	assert_eq(VentInput.poll(get_tree()), [VentTravel.NEXT, VentTravel.NEXT, &"interact"])


func test_inside_the_vent_nothing_else_works() -> void:
	var map: HeistMap3D = await _map()
	var thief: ThiefController3D = map.thief
	thief.in_vent = true
	assert_false(thief.perform_action(&"throw_coin"), "Sin monedas desde el conducto")
	assert_false(thief.perform_action(&"force"), "Ni robos a lo bruto")
	assert_false(HeistActions.handle(thief, &"throw_coin"), "Ni por la vía de las monedas")
	var camera: SecurityCamera3D = get_tree().get_first_node_in_group(&"security_camera")
	thief.global_position = (
		camera.mount.global_position
		+ (-camera.mount.global_transform.basis.z * 3.0 + Vector3.DOWN * 2.0)
	)
	assert_false(camera._check_line_of_sight(thief), "Las cámaras no lo ven")
	thief.in_vent = false
