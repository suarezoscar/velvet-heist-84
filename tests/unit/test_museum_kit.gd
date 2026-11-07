extends GutTest
## Kit del museo (#177, fase 2): acabados por shader y piezas sueltas, solo aspecto.

const LEVEL: String = "res://data/levels/museum_v2.json"
const WALL_SHADER: Shader = preload("res://assets/shaders/museum_wall.gdshader")
const FLOOR_SHADER: Shader = preload("res://assets/shaders/museum_floor.gdshader")

var data: LevelData = null
var root: Node3D = null


func before_each() -> void:
	data = LevelData.load_json(LEVEL)
	root = Node3D.new()
	add_child_autofree(root)


func _build() -> Node:
	var arch: Node = LevelArchitectureBuilder.build(data, root)
	MuseumFinishBuilder.apply(data, arch)
	MuseumKitBuilder.build(data, root)
	return arch


func _room_index(room_id: String) -> int:
	var rooms: Array = data.section("rooms")
	for index: int in range(rooms.size()):
		if String(rooms[index]["id"]) == room_id:
			return index
	return -1


func test_room_map_marks_each_room_center() -> void:
	var image: Image = MuseumFinishBuilder.room_map(data).get_image()
	var bounds: Rect2 = data.building_bounds()
	for room: Dictionary in data.section("rooms"):
		bounds = bounds.merge(data.room_rect(room))
	bounds = bounds.grow(1.0)
	for room_id: String in ["VES", "VLT", "PS", "GAR", "ALY"]:
		var rect: Rect2 = data.room_rect(data.room_by_id(room_id))
		var cell: Vector2i = Vector2i(
			((rect.get_center() - bounds.position) / MuseumFinishBuilder.CELL).floor()
		)
		var value: int = roundi(image.get_pixelv(cell).r * 255.0)
		assert_eq(value, _room_index(room_id) + 1, "mapa de salas en %s" % room_id)


func test_finish_table_encodes_family_in_alpha() -> void:
	var image: Image = (
		MuseumFinishBuilder.finish_table(data, MuseumFinishBuilder.FINISHES).get_image()
	)
	var expected: Dictionary = {"VES": 0, "PS": 1, "VLT": 2, "ALY": 3}
	for room_id: String in expected:
		var alpha: float = image.get_pixel(_room_index(room_id) + 1, 0).a
		assert_almost_eq(alpha * 3.0, float(expected[room_id]), 0.02, "familia de %s" % room_id)


func test_door_family_takes_the_strongest_room() -> void:
	var f: MuseumFinishes = MuseumKitBuilder.FINISHES
	assert_eq(MuseumKitBuilder.door_family({"a": "ANTE", "b": "VLT"}, f), "vault")
	assert_eq(MuseumKitBuilder.door_family({"a": "PS", "b": "GAR"}, f), "service")
	assert_eq(MuseumKitBuilder.door_family({"a": "ALY", "b": "VES"}, f), "service")
	assert_eq(MuseumKitBuilder.door_family({"a": "GW", "b": "VES"}, f), "public")


func test_walls_and_floors_use_the_kit_shaders() -> void:
	var arch: Node = _build()
	var walls: int = 0
	for child: Node in arch.get_children():
		if child.name.begins_with("Wall_"):
			var mesh: BoxMesh = (child.get_node("Mesh") as MeshInstance3D).mesh as BoxMesh
			assert_eq((mesh.material as ShaderMaterial).shader, WALL_SHADER, child.name)
			walls += 1
		elif child.name.begins_with("Floor_"):
			var mat: ShaderMaterial = (
				(child.get_node("Mesh") as MeshInstance3D).material_override as ShaderMaterial
			)
			assert_eq(mat.shader, FLOOR_SHADER, child.name)
			var surface: String = String(child.get_meta("surface_id"))
			assert_eq(
				int(mat.get_shader_parameter(&"pattern")),
				int(MuseumFinishBuilder.PATTERNS[surface]),
				"patrón de %s" % child.name
			)
	assert_gt(walls, 0)


func test_kit_places_frames_lintels_and_window() -> void:
	_build()
	var kit: Node = root.get_node("MuseumKit")
	var doors: Array = data.section("doors")
	var leafless: int = doors.filter(func(d: Dictionary) -> bool: return not d.has("leaf")).size()
	var frames: int = 0
	var lintels: int = 0
	for child: Node in kit.get_children():
		frames += 1 if child.name.begins_with("Frame_") else 0
		lintels += 1 if child.name.begins_with("Lintel") else 0
	assert_eq(frames, doors.size(), "un marco por paso")
	assert_eq(lintels, leafless + data.section("windows").size(), "dintel en pasos y ventanas")
	assert_not_null(kit.get_node_or_null("Window_V1"))


func test_pilasters_only_in_public_rooms() -> void:
	_build()
	var kit: Node = root.get_node("MuseumKit")
	var count: int = 0
	for child: Node in kit.get_children():
		if not child.name.begins_with("Pilaster"):
			continue
		count += 1
		var p: Vector3 = (child as Node3D).position
		for offset: Vector2 in [Vector2(0.4, 0.4), Vector2(-0.4, -0.4)]:
			var design: Vector2 = Vector2(p.x, p.z) + offset - data.offset
			for room: Dictionary in data.section("rooms"):
				if data.room_rect(room).has_point(design):
					var family: int = MuseumKitBuilder.FINISHES.family_code(String(room["id"]))
					assert_eq(family, 0, "%s junto a %s" % [child.name, room["id"]])
	assert_gt(count, 0, "hay pilastras")


func test_kit_adds_no_collision_and_cuts_with_xray() -> void:
	_build()
	var kit: Node = root.get_node("MuseumKit")
	assert_eq(kit.find_children("*", "CollisionObject3D", true, false).size(), 0)
	for node: Node in kit.find_children("*", "MeshInstance3D", true, false):
		var inst: MeshInstance3D = node as MeshInstance3D
		var mat: Material = inst.get_surface_override_material(0)
		if mat == null and inst.mesh is BoxMesh:
			mat = (inst.mesh as BoxMesh).material
		assert_true(mat is ShaderMaterial, "%s con material de muro" % inst.get_path())
		var shader: Shader = (mat as ShaderMaterial).shader
		assert_true(shader == WALL_SHADER or shader == WallXRay.SHADER, "%s se recorta" % inst.name)
