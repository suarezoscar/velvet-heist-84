## @file test_level_builder.gd
## Tests del nivel por datos (FEAT-015, criterios 2 a 6) con el nivel pequeño de
## tests/fixtures/level_small.json y del contenido de data/levels/museum_v2.json (criterio 1).
extends GutTest

const FIXTURE_PATH: String = "res://tests/fixtures/level_small.json"
const MUSEUM_V2_PATH: String = "res://data/levels/museum_v2.json"
const THIEF_SCENE: PackedScene = preload("res://scenes/entities/thief_player.tscn")
const GUARD_SCENE: PackedScene = preload("res://scenes/entities/guard_player.tscn")


func _build_architecture() -> Node3D:
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	LevelArchitectureBuilder.build(LevelData.load_json(FIXTURE_PATH), root)
	await wait_physics_frames(2)
	return root


func _ray_hits(root: Node3D, from: Vector3, to: Vector3) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
	return not root.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func test_door_gaps_open_and_walls_closed() -> void:
	var root: Node3D = await _build_architecture()
	assert_false(_ray_hits(root, Vector3(7, 1, 3), Vector3(9, 1, 3)), "D1 deja pasar (x=8, z=3)")
	assert_true(_ray_hits(root, Vector3(7, 1, 4.5), Vector3(9, 1, 4.5)), "Muro a 1,5 m de D1")
	assert_false(_ray_hits(root, Vector3(4, 1, 5), Vector3(4, 1, 7)), "D2 deja pasar (z=6, x=4)")
	assert_true(_ray_hits(root, Vector3(6, 1, 5), Vector3(6, 1, 7)), "Muro a 2 m de D2")


func test_window_has_sill_only() -> void:
	var root: Node3D = await _build_architecture()
	assert_true(_ray_hits(root, Vector3(12, 0.5, 5), Vector3(12, 0.5, 7)), "Alféizar bajo")
	assert_false(_ray_hits(root, Vector3(12, 1.5, 5), Vector3(12, 1.5, 7)), "Vista sobre W1")


func test_shared_edge_is_not_duplicated() -> void:
	var root: Node3D = await _build_architecture()
	var arch: Node = root.get_node("Architecture")
	var shared: Array[String] = []
	for child: Node in arch.get_children():
		if String(child.name).begins_with("Wall_V_8_00"):
			shared.append(String(child.name))
	assert_eq(shared.size(), 2, "El borde x=8 compartido por A y B son 2 tramos (hueco de D1)")


func test_floors_read_noise_multiplier_from_surface_tres() -> void:
	var root: Node3D = await _build_architecture()
	var arch: Node = root.get_node("Architecture")
	var carpet: SurfaceAcousticData = load("res://data/balance/surface_carpet.tres")
	var marble: SurfaceAcousticData = load("res://data/balance/surface_marble.tres")
	assert_almost_eq(
		float(arch.get_node("Floor_A").get_meta("noise_multiplier")), carpet.noise_multiplier, 0.001
	)
	assert_almost_eq(
		float(arch.get_node("Floor_B").get_meta("noise_multiplier")), marble.noise_multiplier, 0.001
	)
	assert_almost_eq(float(arch.get_node("Floor_OUT").get_meta("noise_multiplier")), 1.0, 0.001)


func test_wall_collision_full_and_low_visual_except_north_west() -> void:
	var root: Node3D = await _build_architecture()
	for child: Node in root.get_node("Architecture").get_children():
		var wall_name: String = String(child.name)
		if not wall_name.begins_with("Wall_"):
			continue
		var shape: BoxShape3D = (child.get_node("CollisionShape3D") as CollisionShape3D).shape
		var mesh: BoxMesh = (child.get_node("Mesh") as MeshInstance3D).mesh
		assert_almost_eq(shape.size.y, 3.2, 0.001, "%s colisiona a 3,2 m" % wall_name)
		var tall: bool = (
			wall_name.begins_with("Wall_H_0_00") or wall_name.begins_with("Wall_V_0_00")
		)
		assert_almost_eq(
			mesh.size.y, 3.2 if tall else 1.2, 0.001, "Altura visible de %s" % wall_name
		)


func test_entities_and_actor_placement() -> void:
	var map: Node3D = Node3D.new()
	var thief: ThiefController3D = THIEF_SCENE.instantiate() as ThiefController3D
	var guard: GuardController3D = GUARD_SCENE.instantiate() as GuardController3D
	map.add_child(thief)
	map.add_child(guard)
	add_child_autofree(map)
	LevelEntitiesBuilder.build(LevelData.load_json(FIXTURE_PATH), map)
	var props: Node = map.get_node("Props")
	var masterpiece: LootItem3D = props.get_node("Loot_M") as LootItem3D
	assert_true(masterpiece.is_masterpiece and masterpiece.is_heavy, "M es la Pieza Maestra")
	assert_eq((props.get_node("Loot_L1") as LootItem3D).loot_value, 700)
	assert_eq((props.get_node("Switch_SW1") as LightSwitch3D).circuit_id, 1)
	assert_eq((props.get_node("TimeClock_01") as TimeClock3D).round_duration, 90.0)
	assert_not_null(props.get_node_or_null("SafeBox3D"))
	assert_not_null(props.get_node_or_null("EscapeCar3D"))
	assert_not_null(props.get_node_or_null("Camera_CAM_1"))
	assert_not_null(props.get_node_or_null("Monitor_CAM_1"))
	assert_almost_eq(thief.position.x, 10.0, 0.001, "Ladrón en su aparición")
	assert_almost_eq(thief.position.z, 8.0, 0.001)
	var ai: Node = guard.get_node("GuardAI")
	assert_eq((ai.get("patrol_waypoints") as Array).size(), 2, "El guardia recibe su patrulla")


func test_build_is_deterministic() -> void:
	var first: Node3D = Node3D.new()
	var second: Node3D = Node3D.new()
	add_child_autofree(first)
	add_child_autofree(second)
	var data: LevelData = LevelData.load_json(FIXTURE_PATH)
	LevelArchitectureBuilder.build(data, first)
	LevelArchitectureBuilder.build(data, second)
	assert_eq(
		_child_names(first.get_node("Architecture")), _child_names(second.get_node("Architecture"))
	)


func test_museum_v2_data_matches_design() -> void:
	var data: LevelData = LevelData.load_json(MUSEUM_V2_PATH)
	assert_not_null(data, "museum_v2.json se lee")
	assert_eq(data.section("rooms").size(), 16, "15 salas y el callejón")
	assert_eq(data.section("doors").size(), 24, "P01–P24")
	assert_eq(data.section("windows").size(), 1, "V1")
	assert_eq(data.section("clocks").size(), 4, "R1–R4")
	assert_eq(data.section("cameras").size(), 3, "CAM-1..3")
	assert_eq(data.section("monitors").size(), 3, "Un monitor por cámara")
	assert_eq((data.entry("spawns").get("guards", []) as Array).size(), 3, "Tres guardias")
	# heist.md: 6 candidatas (2 de cada protección) y 3 salidas exteriores; sin cuota
	var kinds: Dictionary = {}
	for target: Dictionary in data.section("targets"):
		kinds[target["protection"]] = int(kinds.get(target["protection"], 0)) + 1
	assert_eq(data.section("targets").size(), 6, "Seis piezas candidatas")
	assert_eq(kinds, {"combination": 2, "pressure": 2, "sensor": 2}, "Dos de cada protección")
	assert_eq(data.section("exits").size(), 3, "P01, P02 y P03")
	assert_true(data.section("loot").is_empty(), "Sin botín suelto")


func _child_names(node: Node) -> Array[String]:
	var names: Array[String] = []
	for child: Node in node.get_children():
		names.append(String(child.name))
	return names
