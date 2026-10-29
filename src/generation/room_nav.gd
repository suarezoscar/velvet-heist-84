## @file room_nav.gd
## Caminos dentro de una sala que rodean los muebles (FEAT-034), en coordenadas del diseño.
## Los obstáculos salen de los datos del nivel: coberturas, pedestales y vitrinas de las piezas,
## tabiques, la cafetera, la mesa de monitores y las mesas de réplicas, inflados con el radio de
## un personaje. Si la recta está libre, va recta; si no, A* en una rejilla de CELL m dentro de
## la sala y luego se estira el camino quitando los puntos que sobran. Lo usa RoomGraph.
class_name RoomNav
extends RefCounted

const CELL: float = 0.25
## Radio de un personaje más un margen (m)
const RADIUS: float = 0.45
## Separación de los muros de la sala (m)
const WALL_MARGIN: float = 0.35
const SAMPLE_STEP: float = 0.15
const PIECE_SIZES: Dictionary = {"pedestal": 0.7, "case": 0.9, "safe": 0.8}

var obstacles: Array[Rect2] = []
## Rejilla A* de cada sala, hecha una vez (clave: el rectángulo de la sala)
var _grids: Dictionary = {}


static func from_level(data: LevelData) -> RoomNav:
	var nav: RoomNav = RoomNav.new()
	for cover: Dictionary in data.section("covers"):
		nav._add_box(
			cover["pos"], Vector2(cover["size"][0], cover["size"][1]), cover.get("rot_deg", 0)
		)
	for target: Dictionary in data.section("targets"):
		var side: float = float(PIECE_SIZES.get(String(target.get("variant", "pedestal")), 0.9))
		nav._add_box(target["pos"], Vector2(side, side), 0)
	for table: Dictionary in data.section("replica_tables"):
		nav._add_box(table["pos"], Vector2(1.2, 0.6), 0)
	if not data.entry("coffee").is_empty():
		var coffee: Dictionary = data.entry("coffee")
		nav._add_box(coffee["pos"], Vector2(2.2, 1.1), coffee.get("rot_deg", 0))
	if not data.entry("cctv_desk").is_empty():
		var desk: Dictionary = data.entry("cctv_desk")
		nav._add_box(desk["pos"], Vector2(3.6, 0.7), desk.get("rot_deg", 0))
	for partition: Dictionary in data.section("partitions"):
		var a: Vector2 = Vector2(partition["from"][0], partition["from"][1])
		var b: Vector2 = Vector2(partition["to"][0], partition["to"][1])
		var rect: Rect2 = Rect2(a, Vector2.ZERO).expand(b).grow(0.15 + RADIUS)
		nav.obstacles.append(rect)
	return nav


## true si el punto está libre en la sala (lejos de muros y muebles)
func is_free(room: Rect2, point: Vector2) -> bool:
	if not room.grow(-WALL_MARGIN).has_point(point):
		return false
	for rect: Rect2 in obstacles:
		if rect.has_point(point):
			return false
	return true


## true si se puede ir en línea recta de a a b dentro de la sala
func clear(room: Rect2, a: Vector2, b: Vector2) -> bool:
	var steps: int = maxi(1, ceili(a.distance_to(b) / SAMPLE_STEP))
	for i: int in range(1, steps):
		if not is_free(room, a.lerp(b, float(i) / steps)):
			return false
	return true


## Puntos de paso de a a b dentro de room (sin a, con b)
func route(room: Rect2, a: Vector2, b: Vector2) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if clear(room, a, b):
		result.append(b)
		return result
	var cells: Array[Vector2] = _astar(room, _cell_of(room, a), _cell_of(room, b))
	var points: Array[Vector2] = [a]
	for cell: Vector2 in cells:
		points.append(_center(room, cell))
	points.append(b)
	var anchor: int = 0
	while anchor < points.size() - 1:
		var far: int = points.size() - 1
		while far > anchor + 1 and not clear(room, points[anchor], points[far]):
			far -= 1
		result.append(points[far])
		anchor = far
	return result


func _astar(room: Rect2, start: Vector2i, goal: Vector2i) -> Array[Vector2]:
	var astar: AStarGrid2D = _grid(room)
	var was_solid: Array[bool] = [astar.is_point_solid(start), astar.is_point_solid(goal)]
	astar.set_point_solid(start, false)
	astar.set_point_solid(goal, false)
	var found: Array[Vector2] = []
	for cell: Vector2i in astar.get_id_path(start, goal, true):
		found.append(Vector2(cell))
	astar.set_point_solid(start, was_solid[0])
	astar.set_point_solid(goal, was_solid[1])
	return found


func _grid(room: Rect2) -> AStarGrid2D:
	if _grids.has(room):
		return _grids[room]
	var size: Vector2i = Vector2i(ceili(room.size.x / CELL), ceili(room.size.y / CELL))
	var astar: AStarGrid2D = AStarGrid2D.new()
	astar.region = Rect2i(Vector2i.ZERO, size)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for x: int in range(size.x):
		for y: int in range(size.y):
			astar.set_point_solid(Vector2i(x, y), not is_free(room, _center(room, Vector2(x, y))))
	_grids[room] = astar
	return astar


func _cell_of(room: Rect2, point: Vector2) -> Vector2i:
	var local: Vector2 = (point - room.position) / CELL
	return Vector2i(
		clampi(floori(local.x), 0, ceili(room.size.x / CELL) - 1),
		clampi(floori(local.y), 0, ceili(room.size.y / CELL) - 1)
	)


func _center(room: Rect2, cell: Vector2) -> Vector2:
	return room.position + (cell + Vector2(0.5, 0.5)) * CELL


## Caja de planta size (ancho x fondo) girada rot_deg, como rectángulo inflado con RADIUS
func _add_box(pos: Array, size: Vector2, rot_deg: Variant) -> void:
	var angle: float = deg_to_rad(float(rot_deg))
	var half: Vector2 = size * 0.5
	var extent: Vector2 = Vector2(
		absf(half.x * cos(angle)) + absf(half.y * sin(angle)),
		absf(half.x * sin(angle)) + absf(half.y * cos(angle))
	)
	var center: Vector2 = Vector2(float(pos[0]), float(pos[1]))
	obstacles.append(Rect2(center - extent, extent * 2.0).grow(RADIUS))
