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


## Siguiente sala de la IA: al azar con peso 1 + piezas × ai_piece_weight, sin las de recent;
## ni el exterior ni la garita
func pick_room(recent: Array[String], rng: RandomNumberGenerator) -> String:
	var weights: Dictionary = room_weights(_piece_counts())
	for room_id: String in recent:
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
		if bool(room.get("exterior", false)) or bool(room.get("guard_post", false)):
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


func _piece_counts() -> Dictionary:
	var counts: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group(&"heist_targets"):
		var room_id: String = graph.room_at(_design((node as Node3D).global_position))
		counts[room_id] = int(counts.get(room_id, 0)) + 1
	return counts


func _design(world: Vector3) -> Vector2:
	var offset: Vector2 = graph.data.offset if graph != null else Vector2.ZERO
	return Vector2(world.x - offset.x, world.z - offset.y)
