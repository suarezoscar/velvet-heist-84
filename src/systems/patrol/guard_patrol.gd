## @file guard_patrol.gd
## Salas del nivel para los guardias (heist.md R5, R5c; #116, sustituye a las rondas): dice si un
## punto está en la garita (donde el sueño no sube), elige la siguiente sala que patrulla la IA
## (más a menudo las que tienen piezas, sin repetir las últimas) y da el camino entre dos puntos
## cruzando por las puertas. Nodo «Patrol» que crea LevelEntitiesBuilder.
class_name GuardPatrol
extends Node

const RULES: GuardPatrolRules = preload("res://data/balance/guard_patrol.tres")

var graph: RoomGraph = null


func _ready() -> void:
	name = "Patrol"
	add_to_group(&"guard_patrol")


## La patrulla del mapa (null si el nivel no tiene salas)
static func of(tree: SceneTree) -> GuardPatrol:
	return tree.get_first_node_in_group(&"guard_patrol") as GuardPatrol if tree != null else null


## true si el punto está en una sala marcada como garita ("guard_post" en el nivel)
func in_guard_post(world: Vector3) -> bool:
	if graph == null:
		return false
	var room_id: String = graph.room_at(_design(world))
	return room_id != "" and bool(graph.data.room_by_id(room_id).get("guard_post", false))


## Siguiente sala de la IA (R5c): al azar con peso 1 + piezas × ai_piece_weight, sin las de
## avoid (sus últimas salas y la que tienen como destino otros guardias de IA, si quedan otras);
## ni el exterior, ni la garita, ni los pasillos
func pick_room(avoid: Array[String], rng: RandomNumberGenerator) -> String:
	var weights: Dictionary = room_weights(_piece_counts())
	for room_id: String in avoid:
		if weights.size() > 1:
			weights.erase(room_id)
	var total: float = 0.0
	for room_id: String in weights:
		total += float(weights[room_id])
	var roll: float = rng.randf() * total
	for room_id: String in weights:
		roll -= float(weights[room_id])
		if roll <= 0.0:
			return room_id
	return String(weights.keys().back()) if not weights.is_empty() else ""


## Peso de cada sala patrullable según cuántas piezas tiene
func room_weights(pieces: Dictionary) -> Dictionary:
	var weights: Dictionary = {}
	if graph == null:
		return weights
	for room: Dictionary in graph.data.section("rooms"):
		if (
			bool(room.get("exterior", false))
			or bool(room.get("guard_post", false))
			or bool(room.get("corridor", false))
		):
			continue
		var room_id: String = String(room["id"])
		weights[room_id] = 1.0 + float(pieces.get(room_id, 0)) * RULES.ai_piece_weight
	return weights


## Centro de una sala, a la altura de los actores
func room_center(room_id: String) -> Vector3:
	var rect: Rect2 = graph.data.room_rect(graph.data.room_by_id(room_id))
	var center: Vector2 = rect.get_center()
	return graph.data.to_world([center.x, center.y], LevelEntitiesBuilder.ACTOR_HEIGHT)


## Camino por las salas y sus puertas entre dos puntos del mundo (incluye el destino)
func walk_between(from: Vector3, to: Vector3) -> Array[Vector3]:
	var points: Array[Vector3] = []
	if graph == null:
		return [to]
	for point: Vector2 in graph.path(_design(from), _design(to)):
		points.append(graph.data.to_world([point.x, point.y], LevelEntitiesBuilder.ACTOR_HEIGHT))
	if points.is_empty():
		points.append(to)
	return points


## Puntos junto a cada pieza de la sala que sigue siéndolo para los guardias (a 1 m, hacia el
## centro de la sala, para no chocar con la peana)
func piece_stops(room_id: String) -> Array[Vector3]:
	var stops: Array[Vector3] = []
	var center: Vector3 = room_center(room_id)
	for piece: Node3D in _live_pieces():
		if graph.room_at(_design(piece.global_position)) != room_id:
			continue
		var toward: Vector3 = (center - piece.global_position).slide(Vector3.UP)
		var stop: Vector3 = piece.global_position + toward.limit_length(1.0)
		stops.append(Vector3(stop.x, center.y, stop.z))
	return stops


## Piezas que la IA tiene en cuenta: las descubiertas como robadas (R6) ya no
func _live_pieces() -> Array[Node3D]:
	var pieces: Array[Node3D] = []
	for node: Node in get_tree().get_nodes_in_group(&"heist_targets"):
		var piece: TargetPiece3D = node as TargetPiece3D
		if piece != null and not piece.discovered:
			pieces.append(piece)
	return pieces


func _piece_counts() -> Dictionary:
	var counts: Dictionary = {}
	for piece: Node3D in _live_pieces():
		var room_id: String = graph.room_at(_design(piece.global_position))
		counts[room_id] = int(counts.get(room_id, 0)) + 1
	return counts


func _design(world: Vector3) -> Vector2:
	var offset: Vector2 = graph.data.offset if graph != null else Vector2.ZERO
	return Vector2(world.x - offset.x, world.z - offset.y)
