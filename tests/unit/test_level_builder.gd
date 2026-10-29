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


## FEAT-034: los muros se ven a toda su altura y usan el material que se recorta delante del
## jugador local (WallXRay)
func test_walls_full_height_with_xray_material() -> void:
	var root: Node3D = await _build_architecture()
	for child: Node in root.get_node("Architecture").get_children():
		var wall_name: String = String(child.name)
		if not wall_name.begins_with("Wall_"):
			continue
		var shape: BoxShape3D = (child.get_node("CollisionShape3D") as CollisionShape3D).shape
		var mesh: BoxMesh = (child.get_node("Mesh") as MeshInstance3D).mesh
		assert_almost_eq(shape.size.y, 3.2, 0.001, "%s colisiona a 3,2 m" % wall_name)
		assert_almost_eq(mesh.size.y, 3.2, 0.001, "Altura visible de %s" % wall_name)
		var mat: ShaderMaterial = mesh.material as ShaderMaterial
		assert_not_null(mat, "%s usa el material de WallXRay" % wall_name)
		assert_eq(mat.shader, WallXRay.SHADER)


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
	assert_eq((props.get_node("TimeClock_01") as TimeClock3D).clock_id, 1)
	assert_not_null(GuardRound.of(guard), "FEAT-034: cada guardia lleva su ronda")
	assert_not_null(props.get_node_or_null("Rounds"), "Y hay quien reparte las rutas")
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
	assert_eq(data.section("rooms").size(), 22, "FEAT-034: 21 salas con el ala este y el callejón")
	assert_eq(data.section("doors").size(), 36, "P01–P38 sin P21 ni P24 (la garita tiene una)")
	assert_eq(data.section("windows").size(), 1, "V1")
	assert_eq(data.section("clocks").size(), 8, "R1–R8")
	assert_eq(data.section("cameras").size(), 5, "CAM-1..5")
	assert_eq(data.section("monitors").size(), 5, "Un monitor por cámara")
	assert_eq((data.entry("spawns").get("guards", []) as Array).size(), 3, "Tres guardias")
	# FEAT-034: 20 candidatas (7 combinación, 7 presión, 6 sensor) y 4 salidas exteriores
	var kinds: Dictionary = {}
	for target: Dictionary in data.section("targets"):
		kinds[target["protection"]] = int(kinds.get(target["protection"], 0)) + 1
	assert_eq(data.section("targets").size(), 20, "Veinte piezas candidatas")
	assert_eq(kinds, {"combination": 7, "pressure": 7, "sensor": 6}, "Reparto de protecciones")
	assert_eq(data.section("exits").size(), 4, "P01, P02, P03 y P38")
	assert_eq(data.section("wings").size(), 4, "Cuatro alas con cuadro eléctrico")
	assert_eq(data.section("vents").size(), 11, "Tres redes de ventilación")
	assert_true(data.section("loot").is_empty(), "Sin botín suelto")
	var garita_doors: int = 0
	for door: Dictionary in data.section("doors"):
		if "GAR" in [door["a"], door["b"]]:
			garita_doors += 1
			assert_true(door.has("leaf"), "La puerta de la garita tiene hoja")
	assert_eq(garita_doors, 1, "La garita tiene una sola puerta")


func _child_names(node: Node) -> Array[String]:
	var names: Array[String] = []
	for child: Node in node.get_children():
		names.append(String(child.name))
	return names
