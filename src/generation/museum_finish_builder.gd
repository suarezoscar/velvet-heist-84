## @file museum_finish_builder.gd
## Acabados del kit del museo (#177, fase 2): pinta muros, tabiques, molduras y suelos ya
## construidos por LevelArchitectureBuilder sin tocar sus cajas ni su colisión. Genera desde el
## JSON el «mapa de salas» (una celda de CELL m con el índice de sala + 1) y una tabla con el
## acabado de cada sala; museum_wall.gdshader mira en ellos a qué sala da cada cara.
class_name MuseumFinishBuilder
extends RefCounted

## Piezas del muro (museum_wall.gdshader, uniform part)
enum Part { WALL, BASEBOARD, CORNICE, PARTITION }

const FINISHES: MuseumFinishes = preload("res://data/visual/museum_finishes.tres")
const WALL_SHADER: Shader = preload("res://assets/shaders/museum_wall.gdshader")
const FLOOR_SHADER: Shader = preload("res://assets/shaders/museum_floor.gdshader")
const LOOK: NightLook = preload("res://data/visual/night_look.tres")
const CELL: float = 0.25
const PATTERNS: Dictionary = {
	"marble": 0, "wood_parquet": 1, "carpet": 2, "linoleum": 3, "asphalt": 4
}
const PART_META: StringName = &"museum_part"

## Materiales de muro del último nivel pintado (el kit los usa para sus dinteles)
static var _materials: Dictionary = {}


## Pinta la arquitectura del nivel (nodo Architecture con sus Wall_, Partition_, WindowSill_ y
## Floor_); devuelve los materiales de muro por pieza
static func apply(data: LevelData, arch: Node, finishes: MuseumFinishes = FINISHES) -> Dictionary:
	var map_tex: ImageTexture = room_map(data)
	var finish_tex: ImageTexture = finish_table(data, finishes)
	var corner: Vector2 = _bounds(data).position
	var origin: Vector3 = data.to_world([corner.x, corner.y])
	var mats: Dictionary = {}
	for part: int in Part.values():
		mats[part] = _wall_material(
			part, map_tex, finish_tex, Vector2(origin.x, origin.z), finishes
		)
	for child: Node in arch.get_children():
		var body: StaticBody3D = child as StaticBody3D
		if body == null:
			continue
		var node_name: String = body.name
		if node_name.begins_with("Floor_"):
			_paint_floor(data, body, node_name.trim_prefix("Floor_"), finishes)
			continue
		var base: int = Part.PARTITION if node_name.begins_with("Partition_") else Part.WALL
		var walled: bool = node_name.begins_with("Wall_") or node_name.begins_with("WindowSill_")
		if not walled and base != Part.PARTITION:
			continue
		for mesh_node: Node in body.get_children():
			var inst: MeshInstance3D = mesh_node as MeshInstance3D
			if inst == null or not (inst.mesh is BoxMesh):
				continue
			var part: int = int(inst.get_meta(PART_META, base))
			(inst.mesh as BoxMesh).material = mats[part]
	_materials = mats
	return mats


## Material de muro de una pieza del último nivel pintado (null si aún no hay)
static func wall_material(part: int) -> Material:
	return _materials.get(part) as Material


## Índice de sala + 1 por celda (R8); la celda (0, 0) está en la esquina de _bounds
static func room_map(data: LevelData) -> ImageTexture:
	var bounds: Rect2 = _bounds(data)
	var size: Vector2i = Vector2i(ceili(bounds.size.x / CELL), ceili(bounds.size.y / CELL))
	var image: Image = Image.create(size.x, size.y, false, Image.FORMAT_R8)
	var rooms: Array = data.section("rooms")
	for index: int in range(rooms.size()):
		var rect: Rect2 = data.room_rect(rooms[index])
		var from: Vector2i = Vector2i(((rect.position - bounds.position) / CELL).round())
		var to: Vector2i = Vector2i(((rect.end - bounds.position) / CELL).round())
		image.fill_rect(Rect2i(from, to - from), Color8(index + 1, 0, 0))
	return ImageTexture.create_from_image(image)


## Columna por sala (la 0: fuera de toda sala): paño con la familia en alfa (código / 3) y friso
static func finish_table(data: LevelData, finishes: MuseumFinishes) -> ImageTexture:
	var rooms: Array = data.section("rooms")
	var image: Image = Image.create(rooms.size() + 1, 2, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, Color(finishes.exterior_wall, 1.0))
	image.set_pixel(0, 1, finishes.dado)
	for index: int in range(rooms.size()):
		var room_id: String = String(rooms[index]["id"])
		var family: float = finishes.family_code(room_id) / 3.0
		image.set_pixel(index + 1, 0, Color(finishes.paint_of(room_id), family))
		image.set_pixel(index + 1, 1, finishes.dado)
	return ImageTexture.create_from_image(image)


static func _bounds(data: LevelData) -> Rect2:
	var bounds: Rect2 = data.building_bounds()
	for room: Dictionary in data.section("rooms"):
		bounds = bounds.merge(data.room_rect(room))
	return bounds.grow(1.0)


static func _wall_material(
	part: int, map_tex: Texture2D, finish_tex: Texture2D, origin: Vector2, f: MuseumFinishes
) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = WALL_SHADER
	var params: Dictionary = {
		&"room_map": map_tex,
		&"room_finish": finish_tex,
		&"map_origin": origin,
		&"map_cell": CELL,
		&"part": part,
		&"cap_color": f.cap,
		&"partition_cap": f.partition_cap,
		&"baseboard_color": f.baseboard,
		&"rail_color": f.rail,
		&"cornice_color": f.cornice,
		&"service_wall": f.service_wall,
		&"stripe_color": f.stripe,
		&"vault_wall": f.vault_wall,
		&"exterior_wall": f.exterior_wall,
		&"penumbra_tint": LOOK.penumbra_tint,
		&"band_softness": LOOK.band_softness,
		&"pattern_strength": f.wall_pattern_strength,
	}
	for key: StringName in params:
		mat.set_shader_parameter(key, params[key])
	return WallXRay.register(mat, "museum:%d" % part)


static func _paint_floor(
	data: LevelData, body: StaticBody3D, room_id: String, f: MuseumFinishes
) -> void:
	var room: Dictionary = data.room_by_id(room_id)
	var surface: String = String(room.get("surface", "marble"))
	var colors: Array = f.floors.get(surface, f.floors.get("marble", []))
	if surface == "carpet" and f.carpets.has(room_id):
		colors = (f.carpets[room_id] as Array) + [colors[3]]
	var rect: Rect2 = data.room_rect(room)
	var a: Vector3 = data.to_world([rect.position.x, rect.position.y])
	var b: Vector3 = data.to_world([rect.end.x, rect.end.y])
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = FLOOR_SHADER
	mat.set_shader_parameter(&"pattern", int(PATTERNS.get(surface, 0)))
	mat.set_shader_parameter(&"color_a", colors[0])
	mat.set_shader_parameter(&"color_b", colors[1])
	mat.set_shader_parameter(&"color_c", colors[2])
	mat.set_shader_parameter(&"roughness", float(colors[3]))
	mat.set_shader_parameter(&"room_rect", Vector4(a.x, a.z, b.x, b.z))
	mat.set_shader_parameter(&"penumbra_tint", LOOK.penumbra_tint)
	mat.set_shader_parameter(&"band_softness", LOOK.band_softness)
	mat.set_shader_parameter(&"pattern_strength", f.floor_pattern_strength)
	(body.get_node("Mesh") as MeshInstance3D).material_override = mat
