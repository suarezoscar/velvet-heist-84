## Construye la arquitectura de un nivel por datos (FEAT-015): suelos con su multiplicador de
## ruido, muros por los bordes de las salas sin duplicar los compartidos y con el hueco de cada
## puerta, alféizares de las ventanas, tabiques exentos y coberturas como cajas de maqueta.
## Los nombres de los nodos son deterministas: la red los necesita iguales en servidor y clientes.
class_name LevelArchitectureBuilder
extends RefCounted

## Capa del entorno estático (muros y suelos), la que usan percepción y SurfaceDetector3D
const LAYER_WORLD_SOLID: int = 1
## Grupo de muros, tabiques y alféizares: Interactor3D no interactúa a través de ellos
const WALLS_GROUP: StringName = &"walls"
const FLOOR_THICKNESS: float = 0.2
## Precisión al agrupar bordes en la misma línea (m)
const LINE_EPSILON: float = 0.01
## Tramos más cortos que esto se descartan (restos entre una puerta y una esquina)
const MIN_SEGMENT: float = 0.05

const SURFACE_COLORS: Dictionary = {
	"marble": Color(0.78, 0.76, 0.72),
	"wood_parquet": Color(0.55, 0.38, 0.22),
	"carpet": Color(0.45, 0.12, 0.14),
	"linoleum": Color(0.42, 0.45, 0.42),
	"asphalt": Color(0.16, 0.16, 0.18),
}
const WALL_COLOR: Color = Color(0.62, 0.6, 0.58)
const PARTITION_COLOR: Color = Color(0.5, 0.46, 0.4)
const COVER_COLOR: Color = Color(0.3, 0.32, 0.36)


## Crea el nodo Architecture con todo lo construido como hijo de parent
static func build(data: LevelData, parent: Node3D) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Architecture"
	parent.add_child(root)
	_build_floors(data, root)
	_build_walls(data, root)
	for partition: Dictionary in data.section("partitions"):
		var height: float = float(partition.get("height", data.wall_height))
		_add_segment_box(
			data,
			root,
			"Partition_%s" % partition["id"],
			partition["from"],
			partition["to"],
			height,
			height,
			PARTITION_COLOR
		)
	for window: Dictionary in data.section("windows"):
		var sill: float = float(window.get("sill", 1.0))
		_add_segment_box(
			data,
			root,
			"WindowSill_%s" % window["id"],
			window["from"],
			window["to"],
			sill,
			sill,
			WALL_COLOR
		)
	for cover: Dictionary in data.section("covers"):
		_add_cover(data, root, cover)
	return root


static func _build_floors(data: LevelData, root: Node3D) -> void:
	for room: Dictionary in data.section("rooms"):
		var rect: Rect2 = data.room_rect(room)
		var surface: String = String(room.get("surface", "marble"))
		var body: StaticBody3D = _static_body("Floor_%s" % room["id"])
		body.set_meta("noise_multiplier", LevelData.noise_multiplier_for(surface))
		body.set_meta("surface_id", surface)
		var size: Vector3 = Vector3(rect.size.x, FLOOR_THICKNESS, rect.size.y)
		var center: Vector3 = data.to_world(
			[rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y * 0.5],
			-FLOOR_THICKNESS * 0.5
		)
		_add_box(body, size, center, SURFACE_COLORS.get(surface, WALL_COLOR), size.y)
		root.add_child(body)


## Muros: une los bordes de las salas interiores por línea, resta puertas y ventanas y crea
## una caja por tramo. La colisión siempre mide wall_height; la vista es baja salvo en el
## perímetro norte y oeste, que no tapan nada a la cámara isométrica (mira hacia el noroeste)
static func _build_walls(data: LevelData, root: Node3D) -> void:
	var lines: Dictionary = _wall_lines(data)
	var gaps: Dictionary = _wall_gaps(data)
	var bounds: Rect2 = data.building_bounds()
	var keys: Array = lines.keys()
	keys.sort()
	for key: String in keys:
		var axis: String = key.substr(0, 1)
		var coord: float = float(key.substr(2))
		var tall: bool = (
			(axis == "H" and is_equal_approx(coord, bounds.position.y))
			or (axis == "V" and is_equal_approx(coord, bounds.position.x))
		)
		var visual: float = data.wall_height if tall else data.wall_low_height
		var pieces: Array = _subtract(_union(lines[key]), gaps.get(key, []))
		for index: int in range(pieces.size()):
			var piece: Vector2 = pieces[index]
			var a: Array = [piece.x, coord] if axis == "H" else [coord, piece.x]
			var b: Array = [piece.y, coord] if axis == "H" else [coord, piece.y]
			_add_segment_box(
				data,
				root,
				"Wall_%s_%d" % [key.replace(":", "_").replace(".", "_"), index],
				a,
				b,
				data.wall_height,
				visual,
				WALL_COLOR
			)


## Intervalos de muro por línea: "H:z" (muro este-oeste) o "V:x" (norte-sur)
static func _wall_lines(data: LevelData) -> Dictionary:
	var lines: Dictionary = {}
	for room: Dictionary in data.section("rooms"):
		if bool(room.get("exterior", false)):
			continue
		var r: Rect2 = data.room_rect(room)
		_push(lines, _line_key("H", r.position.y), Vector2(r.position.x, r.end.x))
		_push(lines, _line_key("H", r.end.y), Vector2(r.position.x, r.end.x))
		_push(lines, _line_key("V", r.position.x), Vector2(r.position.y, r.end.y))
		_push(lines, _line_key("V", r.end.x), Vector2(r.position.y, r.end.y))
	return lines


## Huecos de puertas y ventanas sobre la línea de muro en la que caen
static func _wall_gaps(data: LevelData) -> Dictionary:
	var gaps: Dictionary = {}
	for door: Dictionary in data.section("doors"):
		var pos: Array = door["pos"]
		var half: float = float(door.get("width", 1.2)) * 0.5
		if _door_axis(data, door) == "H":
			_push(gaps, _line_key("H", float(pos[1])), Vector2(pos[0] - half, pos[0] + half))
		else:
			_push(gaps, _line_key("V", float(pos[0])), Vector2(pos[1] - half, pos[1] + half))
	for window: Dictionary in data.section("windows"):
		var a: Array = window["from"]
		var b: Array = window["to"]
		if is_equal_approx(float(a[0]), float(b[0])):
			_push(gaps, _line_key("V", float(a[0])), Vector2(minf(a[1], b[1]), maxf(a[1], b[1])))
		else:
			_push(gaps, _line_key("H", float(a[1])), Vector2(minf(a[0], b[0]), maxf(a[0], b[0])))
	return gaps


## "H" si las dos salas de la puerta comparten un borde horizontal (z constante), si no "V"
static func _door_axis(data: LevelData, door: Dictionary) -> String:
	var a: Rect2 = data.room_rect(data.room_by_id(String(door["a"])))
	var b: Rect2 = data.room_rect(data.room_by_id(String(door["b"])))
	var shares_h: bool = (
		absf(a.end.y - b.position.y) < LINE_EPSILON or absf(b.end.y - a.position.y) < LINE_EPSILON
	)
	return "H" if shares_h else "V"


static func _line_key(axis: String, coord: float) -> String:
	return "%s:%.2f" % [axis, snappedf(coord, LINE_EPSILON)]


static func _push(dict: Dictionary, key: String, interval: Vector2) -> void:
	if not dict.has(key):
		dict[key] = []
	dict[key].append(interval)


## Une intervalos solapados o contiguos
static func _union(intervals: Array) -> Array:
	var sorted: Array = intervals.duplicate()
	sorted.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
	var merged: Array = []
	for interval: Vector2 in sorted:
		if not merged.is_empty() and interval.x <= merged[-1].y + LINE_EPSILON:
			merged[-1] = Vector2(merged[-1].x, maxf(merged[-1].y, interval.y))
		else:
			merged.append(interval)
	return merged


## Resta los huecos de los tramos y descarta los restos de menos de MIN_SEGMENT
static func _subtract(pieces: Array, holes: Array) -> Array:
	var result: Array = pieces
	for hole: Vector2 in holes:
		var next: Array = []
		for piece: Vector2 in result:
			if hole.y <= piece.x or hole.x >= piece.y:
				next.append(piece)
				continue
			if hole.x - piece.x > MIN_SEGMENT:
				next.append(Vector2(piece.x, hole.x))
			if piece.y - hole.y > MIN_SEGMENT:
				next.append(Vector2(hole.y, piece.y))
		result = next
	return result


## Caja a lo largo del segmento a-b (en planta), con colisión de collision_h y vista de visual_h.
## Se alarga medio grosor por cada extremo para cerrar las esquinas.
static func _add_segment_box(
	data: LevelData,
	root: Node3D,
	node_name: String,
	a: Array,
	b: Array,
	collision_h: float,
	visual_h: float,
	color: Color
) -> void:
	var start: Vector3 = data.to_world(a)
	var end: Vector3 = data.to_world(b)
	var t: float = data.wall_thickness
	var length: float = start.distance_to(end) + t
	var along_x: bool = absf(end.x - start.x) >= absf(end.z - start.z)
	var size: Vector3 = (
		Vector3(length, collision_h, t) if along_x else Vector3(t, collision_h, length)
	)
	var body: StaticBody3D = _static_body(node_name)
	body.add_to_group(WALLS_GROUP)
	body.position = (start + end) * 0.5
	_add_box(body, size, Vector3(0.0, collision_h * 0.5, 0.0), color, visual_h)
	root.add_child(body)


static func _add_cover(data: LevelData, root: Node3D, cover: Dictionary) -> void:
	var dims: Array = cover["size"]
	var size: Vector3 = Vector3(float(dims[0]), float(dims[2]), float(dims[1]))
	var body: StaticBody3D = _static_body("Cover_%s" % cover["id"])
	body.position = data.to_world(cover["pos"])
	body.rotation.y = deg_to_rad(-float(cover.get("rot_deg", 0.0)))
	body.set_meta("kind", String(cover.get("kind", "")))
	_add_box(body, size, Vector3(0.0, size.y * 0.5, 0.0), COVER_COLOR, size.y)
	root.add_child(body)


static func _static_body(node_name: String) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.collision_layer = LAYER_WORLD_SOLID
	body.collision_mask = 0
	return body


## Colisión de tamaño size centrada en center y malla de la misma planta con altura visual_h,
## apoyada en la misma base
static func _add_box(
	body: StaticBody3D, size: Vector3, center: Vector3, color: Color, visual_h: float
) -> void:
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "CollisionShape3D"
	col.shape = shape
	col.position = center
	body.add_child(col)
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(size.x, visual_h, size.z)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat
	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	mesh_inst.name = "Mesh"
	mesh_inst.mesh = mesh
	mesh_inst.position = Vector3(center.x, center.y - size.y * 0.5 + visual_h * 0.5, center.z)
	body.add_child(mesh_inst)
