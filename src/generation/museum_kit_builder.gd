## @file museum_kit_builder.gd
## Piezas sueltas del kit del museo (#177, fase 2), colocadas desde el JSON del nivel: marco en
## cada paso (familia según las salas que une: cámara > servicio > pública), dintel de muro sobre
## él, pilastras en las esquinas y cruces de las salas públicas y marco en las ventanas. Solo
## aspecto: sin colisión, recortadas por WallXRay como los muros, y fuera de CelConverter.
class_name MuseumKitBuilder
extends RefCounted

const FINISHES: MuseumFinishes = preload("res://data/visual/museum_finishes.tres")
const FRAME_PATH: String = "res://assets/models/door_frame_%s_%s.glb"
const PILASTER: PackedScene = preload("res://assets/models/wall_pilaster.glb")
const WINDOW_FRAME: PackedScene = preload("res://assets/models/window_frame_service.glb")
const FAMILY_NAMES: Array[String] = ["public", "service", "vault", "service"]
## Altura de la cara inferior del dintel de muro sobre cada paso (encima del marco)
const LINTEL_FROM: float = 2.4
const WINDOW_TOP: float = 2.5
const EPS: float = 0.02


static func build(data: LevelData, map: Node3D, finishes: MuseumFinishes = FINISHES) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "MuseumKit"
	map.add_child(root)
	var wall_mat: Material = MuseumFinishBuilder.wall_material(MuseumFinishBuilder.Part.WALL)
	for door: Dictionary in data.section("doors"):
		_add_door(data, root, door, finishes, wall_mat)
	for window: Dictionary in data.section("windows"):
		_add_window(data, root, window, wall_mat)
	var arch: Node = map.get_node_or_null("Architecture")
	if arch != null:
		for point: Vector3 in junctions(arch):
			if _all_public(data, point, finishes):
				_place(root, PILASTER.instantiate() as Node3D, point, 0.0, "Pilaster")
	for door3d: Node in map.find_children("Door_*", "Door3D", true, false):
		var lintel: MeshInstance3D = door3d.get_node_or_null("Lintel") as MeshInstance3D
		if lintel != null and wall_mat != null:
			(lintel.mesh as BoxMesh).material = wall_mat
	return root


## Familia del marco de un paso: la más fuerte de las dos salas (cámara > servicio > pública)
static func door_family(door: Dictionary, finishes: MuseumFinishes) -> String:
	var code: int = 0
	for key: String in ["a", "b"]:
		var family: int = finishes.family_code(String(door.get(key, "")))
		code = maxi(code, 1 if family == 3 else family)
	return FAMILY_NAMES[code]


## Puntos (mundo, y = 0) donde se encuentran un muro este-oeste y uno norte-sur
static func junctions(arch: Node) -> Array[Vector3]:
	var h: Array = []
	var v: Array = []
	for child: Node in arch.get_children():
		if not child.name.begins_with("Wall_"):
			continue
		var mesh: MeshInstance3D = child.get_node_or_null("Mesh") as MeshInstance3D
		if mesh == null:
			continue
		var size: Vector3 = (mesh.mesh as BoxMesh).size
		var pos: Vector3 = (child as Node3D).position
		if size.x >= size.z:
			var half: float = (size.x - size.z) * 0.5
			h.append([pos.z, pos.x - half, pos.x + half])
		else:
			var half_v: float = (size.z - size.x) * 0.5
			v.append([pos.x, pos.z - half_v, pos.z + half_v])
	var found: Dictionary = {}
	for a: Array in h:
		for b: Array in v:
			var on_h: bool = b[0] >= a[1] - EPS and b[0] <= a[2] + EPS
			var on_v: bool = a[0] >= b[1] - EPS and a[0] <= b[2] + EPS
			if on_h and on_v:
				var key: Vector3 = Vector3(snappedf(b[0], 0.01), 0.0, snappedf(a[0], 0.01))
				found[key] = true
	var points: Array[Vector3] = []
	points.assign(found.keys())
	return points


static func _all_public(data: LevelData, point: Vector3, finishes: MuseumFinishes) -> bool:
	var any: bool = false
	for offset: Vector2 in [
		Vector2(0.4, 0.4), Vector2(-0.4, 0.4), Vector2(0.4, -0.4), Vector2(-0.4, -0.4)
	]:
		var room_id: String = _room_at(data, Vector2(point.x, point.z) + offset)
		if room_id == "":
			continue
		if finishes.family_code(room_id) != 0:
			return false
		any = true
	return any


static func _room_at(data: LevelData, world_xz: Vector2) -> String:
	var design: Vector2 = world_xz - data.offset
	for room: Dictionary in data.section("rooms"):
		if data.room_rect(room).has_point(design):
			return String(room["id"])
	return ""


static func _add_door(
	data: LevelData, root: Node3D, door: Dictionary, finishes: MuseumFinishes, wall_mat: Material
) -> void:
	var width: float = float(door.get("width", 1.2))
	var key: String = "24" if width > 1.8 else "12"
	var path: String = FRAME_PATH % [door_family(door, finishes), key]
	var yaw: float = PI * 0.5 if LevelArchitectureBuilder._door_axis(data, door) == "V" else 0.0
	var pos: Vector3 = data.to_world(door["pos"])
	var scene: PackedScene = load(path) as PackedScene
	_place(root, scene.instantiate() as Node3D, pos, yaw, "Frame_%s" % door["id"])
	if not door.has("leaf"):  # la puerta con hoja (Door3D) ya trae su dintel
		var top: float = data.wall_height
		var lintel_name: String = "Lintel_%s" % door["id"]
		_lintel(root, lintel_name, pos, yaw, width, LINTEL_FROM, top, data.wall_thickness, wall_mat)


static func _add_window(
	data: LevelData, root: Node3D, window: Dictionary, wall_mat: Material
) -> void:
	var a: Vector3 = data.to_world(window["from"])
	var b: Vector3 = data.to_world(window["to"])
	var yaw: float = 0.0 if absf(b.x - a.x) >= absf(b.z - a.z) else PI * 0.5
	var sill: float = float(window.get("sill", 1.0))
	var center: Vector3 = (a + b) * 0.5
	_place(
		root,
		WINDOW_FRAME.instantiate() as Node3D,
		center + Vector3.UP * sill,
		yaw,
		"Window_%s" % window["id"]
	)
	var width: float = a.distance_to(b)
	var top: float = data.wall_height
	var lintel_name: String = "Lintel_%s" % window["id"]
	_lintel(root, lintel_name, center, yaw, width, sill + 1.5, top, data.wall_thickness, wall_mat)


## Dintel de muro (sin colisión) sobre un hueco, pintado como los muros
static func _lintel(
	root: Node3D,
	node_name: String,
	pos: Vector3,
	yaw: float,
	width: float,
	from: float,
	to: float,
	thick: float,
	wall_mat: Material
) -> void:
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(width - thick, to - from, thick)  # entre los extremos de los muros
	box.material = wall_mat
	var inst: MeshInstance3D = MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = box
	inst.position = pos + Vector3.UP * (from + to) * 0.5
	inst.rotation.y = yaw
	root.add_child(inst)


## Coloca una pieza y cambia sus materiales por los de muro (cel, contorno y rayos X)
static func _place(
	root: Node3D, piece: Node3D, pos: Vector3, yaw: float, node_name: String
) -> void:
	piece.name = node_name
	piece.position = pos
	piece.rotation.y = yaw
	piece.add_to_group(CelConverter.SKIP_GROUP)
	root.add_child(piece)
	for node: Node in piece.find_children("*", "MeshInstance3D", true, false):
		var inst: MeshInstance3D = node as MeshInstance3D
		for index: int in range(inst.mesh.get_surface_count()):
			var source: BaseMaterial3D = inst.mesh.surface_get_material(index) as BaseMaterial3D
			var color: Color = source.albedo_color if source != null else Color.WHITE
			inst.set_surface_override_material(index, WallXRay.material(color))
