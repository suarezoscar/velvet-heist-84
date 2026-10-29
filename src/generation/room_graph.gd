## @file room_graph.gd
## Grafo de salas y puertas de un nivel (FEAT-034), en coordenadas del diseño (x, z). Da el
## camino entre dos puntos cruzando por los huecos de las puertas, con un punto a cada lado de
## cada hueco para no rozar las esquinas, y dentro de cada sala rodeando los muebles (RoomNav).
## Lo usan las rutas de fichaje (RoundPlanner) para medir los tramos y para las patrullas de la
## IA.
class_name RoomGraph
extends RefCounted

## Distancia (m) a cada lado del hueco de una puerta de los puntos de paso
const DOOR_APPROACH: float = 0.7

var data: LevelData = null
## Rodeo de los muebles dentro de cada sala (null: en línea recta)
var nav: RoomNav = null
## room_id -> [{"to": room_id, "door": Vector2, "normal": Vector2}]
var _links: Dictionary = {}


static func from_level(level: LevelData) -> RoomGraph:
	var graph: RoomGraph = RoomGraph.new()
	graph.data = level
	graph.nav = RoomNav.from_level(level)
	for door: Dictionary in level.section("doors"):
		var a: String = String(door["a"])
		var b: String = String(door["b"])
		if graph._exterior(a) or graph._exterior(b):
			continue  # las rondas van por dentro del edificio
		var pos: Vector2 = Vector2(float(door["pos"][0]), float(door["pos"][1]))
		var horizontal: bool = LevelArchitectureBuilder._door_axis(level, door) == "H"
		var normal: Vector2 = Vector2(0.0, 1.0) if horizontal else Vector2(1.0, 0.0)
		graph._link(a, b, pos, normal)
		graph._link(b, a, pos, normal)
	return graph


## Sala que contiene el punto (id; "" si ninguna)
func room_at(point: Vector2) -> String:
	for room: Dictionary in data.section("rooms"):
		if data.room_rect(room).has_point(point):
			return String(room["id"])
	return ""


## Puntos de paso desde from hasta to (incluido to); vacío si no hay camino
func path(from: Vector2, to: Vector2) -> Array[Vector2]:
	var start: String = room_at(from)
	var goal: String = room_at(to)
	var points: Array[Vector2] = []
	if start == "" or goal == "":
		return points
	var previous: Dictionary = {start: null}
	var queue: Array[String] = [start]
	while not queue.is_empty() and not previous.has(goal):
		var room: String = queue.pop_front()
		for link: Dictionary in _links.get(room, []):
			if not previous.has(link["to"]):
				previous[link["to"]] = {"room": room, "link": link}
				queue.append(link["to"])
	if not previous.has(goal):
		return points
	var crossings: Array[Dictionary] = []
	var cursor: String = goal
	while previous[cursor] != null:
		var step: Dictionary = previous[cursor]
		crossings.push_front({"from": step["room"], "link": step["link"]})
		cursor = step["room"]
	var cursor_point: Vector2 = from
	for crossing: Dictionary in crossings:
		var link: Dictionary = crossing["link"]
		var door: Vector2 = link["door"]
		var normal: Vector2 = link["normal"]
		var room_rect: Rect2 = data.room_rect(data.room_by_id(crossing["from"]))
		var side: float = signf((room_rect.get_center() - door).dot(normal))
		points.append_array(_inside(room_rect, cursor_point, door + normal * side * DOOR_APPROACH))
		cursor_point = door - normal * side * DOOR_APPROACH
		points.append(cursor_point)
	points.append_array(_inside(data.room_rect(data.room_by_id(goal)), cursor_point, to))
	return points


## Tramo dentro de una sala: rodea los muebles si hay RoomNav
func _inside(room: Rect2, a: Vector2, b: Vector2) -> Array[Vector2]:
	if nav == null:
		return [b] as Array[Vector2]
	return nav.route(room, a, b)


## Largo (m) del camino de from a to; INF si no hay camino
func distance(from: Vector2, to: Vector2) -> float:
	var points: Array[Vector2] = path(from, to)
	if points.is_empty():
		return INF
	var total: float = 0.0
	var last: Vector2 = from
	for point: Vector2 in points:
		total += last.distance_to(point)
		last = point
	return total


func _exterior(room_id: String) -> bool:
	return bool(data.room_by_id(room_id).get("exterior", false))


func _link(a: String, b: String, door: Vector2, normal: Vector2) -> void:
	if not _links.has(a):
		_links[a] = []
	_links[a].append({"to": b, "door": door, "normal": normal})
