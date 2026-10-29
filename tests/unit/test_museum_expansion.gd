## @file test_museum_expansion.gd
## Museo ampliado (FEAT-034): la puerta de la garita, la ventilación del ladrón, el decorado
## (cuadros con sus créditos, focos) y el recorte de paredes delante del jugador local.
extends GutTest

const MAP_SCENE: PackedScene = preload("res://scenes/maps/museum_v2.tscn")
const DOOR_RULES: DoorRules = preload("res://data/balance/door_rules.tres")
const VENT_RULES: VentRules = preload("res://data/balance/vent_rules.tres")
const LEVEL_PATH: String = "res://data/levels/museum_v2.json"

var _saved_state: GameManager.MatchState


func before_each() -> void:
	_saved_state = GameManager.current_state


func after_each() -> void:
	GameManager.current_state = _saved_state


func _map() -> HeistMap3D:
	var map: HeistMap3D = MAP_SCENE.instantiate() as HeistMap3D
	add_child_autofree(map)
	return map


func _tick(node: Node, seconds: float) -> void:
	for _i: int in range(roundi(seconds / 0.1) + 1):
		node._physics_process(0.1)


func test_garita_door_opens_closes_and_blocks() -> void:
	var map: HeistMap3D = _map()
	await wait_physics_frames(2)
	var door: Door3D = map.find_child("Door_P20", true, false) as Door3D
	assert_not_null(door, "La garita tiene su puerta")
	assert_false(door.is_open, "Empieza cerrada")
	var leaf: StaticBody3D = door.find_child("Leaf", true, false) as StaticBody3D
	assert_true(
		leaf.collision_layer & LevelArchitectureBuilder.LAYER_WALLS != 0, "Cerrada tapa la vista"
	)
	for guard: GuardController3D in map.guards:
		guard.is_ai_controlled = false
		guard.global_position = door.global_position + Vector3(10.0, 0.0, 10.0)
	var guard: GuardController3D = map.guards[0]
	door.interact(guard)
	assert_true(door.is_open, "Un guardia la abre al momento")
	var col: CollisionShape3D = leaf.get_node("CollisionShape3D") as CollisionShape3D
	assert_true(col.disabled, "Abierta deja pasar")
	map.thief.global_position = door.global_position + Vector3(10.0, 0.0, -10.0)
	_tick(door, DOOR_RULES.auto_close)
	assert_false(door.is_open, "Se cierra sola")
	map.thief.global_position = door.global_position + Vector3(0.0, 0.0, 1.0)
	door.interact(map.thief)
	assert_false(door.is_open, "El ladrón no abre al momento")
	assert_string_contains(door.get_interaction_text(map.thief), "Forzando")
	_tick(door, DOOR_RULES.pick_time)
	assert_true(door.is_open, "La fuerza en pick_time")
	map.thief.global_position = door.global_position
	_tick(door, DOOR_RULES.auto_close + 1.0)
	assert_true(door.is_open, "No se cierra con alguien en el hueco")
	assert_eq(door.get_net_state(), {"open": true})


func test_ai_guard_opens_the_door() -> void:
	var map: HeistMap3D = _map()
	await wait_physics_frames(2)
	var door: Door3D = map.find_child("Door_P20", true, false) as Door3D
	map.guards[0].is_ai_controlled = true
	map.guards[0].global_position = door.global_position + Vector3(0.5, 0.0, 0.0)
	door._physics_process(0.1)
	assert_true(door.is_open, "La IA la abre al acercarse")


func test_vent_travel_hides_the_thief() -> void:
	var map: HeistMap3D = _map()
	await wait_physics_frames(2)
	var thief: ThiefController3D = map.thief
	var travel: VentTravel = VentTravel.of(get_tree())
	var entry: Vent3D = travel.get_node("Vent_V_TAL") as Vent3D
	for guard: GuardController3D in map.guards:
		assert_false(entry.can_interact(guard), "Los guardias no entran (cerrada)")
	thief.global_position = entry.exit_point()
	assert_true(entry.can_interact(thief))
	entry.interact(thief)
	_tick(entry, VENT_RULES.enter_time)
	assert_true(thief.in_vent, "Dentro del conducto")
	assert_eq(travel.phase, VentTravel.Phase.CHOOSING)
	assert_true(entry.open_left > 0.0, "La rejilla queda abierta: rastro")
	var guard: GuardController3D = map.guards[0]
	guard.global_position = thief.global_position + Vector3(0.5, 0.0, 0.0)
	assert_false(guard.validate_melee_hit(thief), "No se le puede golpear")
	assert_false(GuardSenses._is_detection_valid(guard, thief), "Ni ver")
	assert_string_contains(entry.get_interaction_text(thief), "Conducto")
	var names: Array[String] = []
	for vent: Vent3D in travel.choices:
		names.append(vent.vent_id)
	assert_eq(names.size(), 3, "Las tres rejillas de la red de servicio")
	thief.current_input_dir = Vector2(1.0, 0.0)
	travel._physics_process(0.1)
	thief.current_input_dir = Vector2.ZERO
	travel._physics_process(0.1)
	var target: Vent3D = travel.choices[travel.selected]
	assert_ne(target, entry, "Derecha cambia de salida")
	entry.interact(thief)
	assert_eq(travel.phase, VentTravel.Phase.TRAVELING)
	var expected: float = (
		entry.global_position.distance_to(target.global_position) / VENT_RULES.travel_speed
	)
	assert_almost_eq(travel.left, expected, 0.01, "Tarda la distancia a travel_speed")
	_tick(travel, expected + 0.2)
	assert_false(thief.in_vent, "Sale")
	assert_almost_eq(thief.global_position.x, target.exit_point().x, 0.2, "Por la otra rejilla")
	assert_true(target.open_left > 0.0, "Y la deja abierta")
	assert_true(target.can_interact(guard), "Un guardia puede cerrarla")
	target.interact(guard)
	assert_eq(target.open_left, 0.0)


func test_vent_state_only_reaches_the_thief() -> void:
	var map: HeistMap3D = _map()
	await wait_physics_frames(2)
	var travel: VentTravel = VentTravel.of(get_tree())
	assert_true(travel.get_net_state().is_empty(), "Nada público")
	var collected: Dictionary = NetPrivateStates.new().collect({"Props/Vents": travel}, true)
	assert_true(NetPrivateStates.for_role(collected, &"guard_1").is_empty(), "Guardias: nada")
	assert_true(NetPrivateStates.for_role(collected, &"thief").has("Props/Vents#private"))
	travel.apply_net_state({"phase": 1, "entry": "V_TAL", "choices": ["V_TAL", "V_MNT"], "sel": 1})
	assert_true(map.thief.in_vent, "En el cliente del ladrón, dentro del conducto")
	assert_eq(travel.choices.size(), 2)


func test_inside_the_vent_nothing_else_works() -> void:
	var map: HeistMap3D = _map()
	await wait_physics_frames(2)
	var thief: ThiefController3D = map.thief
	thief.in_vent = true
	assert_false(thief.perform_action(&"throw_coin"), "Sin monedas desde el conducto")
	assert_false(thief.perform_action(&"force"), "Ni robos a lo bruto")
	GameManager.current_state = GameManager.MatchState.IN_PROGRESS
	assert_false(HeistActions.handle(thief, &"throw_coin"), "Ni por la vía de las monedas")
	var camera: SecurityCamera3D = get_tree().get_first_node_in_group(&"security_camera")
	thief.global_position = (
		camera.mount.global_position
		+ (-camera.mount.global_transform.basis.z * 3.0 + Vector3.DOWN * 2.0)
	)
	assert_false(camera._check_line_of_sight(thief), "Las cámaras no lo ven")
	thief.in_vent = false


func test_paintings_have_images_and_credits() -> void:
	var data: LevelData = LevelData.load_json(LEVEL_PATH)
	var credits: String = FileAccess.get_file_as_string(
		"res://assets/textures/paintings/CREDITS.md"
	)
	var slugs: Array[String] = []
	for art: Dictionary in data.section("art"):
		slugs.append(String(art["painting"]))
	for target: Dictionary in data.section("targets"):
		if target.get("model", "") == "painting":
			slugs.append(String(target["painting"]))
	assert_gt(slugs.size(), 25, "Un museo lleno de cuadros")
	for slug: String in slugs:
		assert_true(ResourceLoader.exists(PaintingArt.TEXTURE_DIR % slug), "Existe %s" % slug)
		assert_string_contains(credits, "`%s.jpg`" % slug, "Créditos de %s" % slug)


func test_dressing_spots_and_xray() -> void:
	var map: HeistMap3D = _map()
	await wait_physics_frames(2)
	var dressing: Node = map.get_node("Dressing")
	var spots: int = 0
	for child: Node in dressing.get_children():
		if child is SpotLight3D:
			spots += 1
	assert_eq(spots, 20, "Un foco por pieza candidata")
	assert_not_null(map.get_node_or_null("WallXRay"))
	await wait_process_frames(2)
	var mat: ShaderMaterial = WallXRay.material(LevelArchitectureBuilder.WALL_COLOR)
	assert_gt(float(mat.get_shader_parameter(&"xray_radius")), 0.0, "Recorta alrededor del local")
	var center: Vector3 = mat.get_shader_parameter(&"xray_center")
	assert_almost_eq(center.x, map.local_player.global_position.x, 0.01)


func test_guards_see_a_counter_and_the_map_has_the_level() -> void:
	var map: HeistMap3D = _map()
	await wait_physics_frames(2)
	var heist: HeistDirector = GameManager.heist
	assert_eq(ContractList84.guards_line(heist), "CANDIDATAS 20 · RASTROS 0 · plano [M]")
	heist.piece(heist.candidates()[0]).discovered = true
	assert_string_contains(ContractList84.guards_line(heist), "CANDIDATAS 19 · RASTROS 1")
	assert_true(map.get_meta(&"level_data") is LevelData, "El plano (M) tiene los datos")


func test_vent_has_a_time_limit() -> void:
	var map: HeistMap3D = _map()
	await wait_physics_frames(2)
	var thief: ThiefController3D = map.thief
	var travel: VentTravel = VentTravel.of(get_tree())
	var entry: Vent3D = travel.get_node("Vent_V_GW") as Vent3D
	thief.global_position = entry.exit_point()
	travel.enter(thief, entry)
	assert_string_contains(entry.get_interaction_text(thief), "%d s" % int(VENT_RULES.max_inside))
	_tick(travel, VENT_RULES.max_inside + 0.2)
	assert_false(thief.in_vent, "Se acabó el tiempo: fuera")
	assert_almost_eq(thief.global_position.x, entry.exit_point().x, 0.2, "Por donde entró")
