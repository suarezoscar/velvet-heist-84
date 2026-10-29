## @file round_planner.gd
## Reparte las rondas de fichaje al empezar cada partida (FEAT-034, interaction.md parte R).
## Nodo «Rounds». Cada guardia recibe RULES.route_length relojes en orden: empieza en una zona
## distinta de la de sus compañeros y va alternando zonas, para que el equipo se reparta. Cada
## tramo dura lo que se tarda andando por el camino entre salas (RoomGraph), por
## RULES.leg_walk_factor, más RULES.leg_margin. Los guardias de la IA patrullan su ruta.
class_name RoundPlanner
extends Node

const RULES: TimeClockRules = preload("res://data/balance/time_clock_rules.tres")
const GUARD_MOVEMENT: MovementProfile = preload("res://data/balance/movement_guard.tres")

var graph: RoomGraph = null
var _planned: bool = false


func _ready() -> void:
	name = "Rounds"
	add_to_group(&"round_planner")


## El planificador del mapa (null si no hay rondas)
static func of(tree: SceneTree) -> RoundPlanner:
	return tree.get_first_node_in_group(&"round_planner") as RoundPlanner


## Camino por las salas y sus puertas entre dos puntos del mundo (FEAT-042: la flecha)
func walk_between(from: Vector3, to: Vector3) -> Array[Vector3]:
	if graph == null:
		return [to]
	return _walk(_design(from), _design(to))


func _physics_process(_delta: float) -> void:
	if not GameManager.is_simulating():
		return
	if GameManager.current_state != GameManager.MatchState.IN_PROGRESS:
		_planned = false
	elif not _planned:
		_planned = true
		plan(RandomNumberGenerator.new())


## Autoridad: da una ruta a cada guardia de la escena (en su orden)
func plan(rng: RandomNumberGenerator) -> void:
	var zones: Dictionary = {}
	var clocks: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group(&"time_clock"):
		var clock: TimeClock3D = node as TimeClock3D
		zones[clock.clock_id] = clock.zone
		clocks[clock.clock_id] = clock
	var guards: Array[GuardController3D] = []
	for node: Node in get_tree().get_nodes_in_group(&"guards"):
		if GuardRound.of(node) != null:
			guards.append(node as GuardController3D)
	var routes: Array = pick_routes(zones, guards.size(), RULES.route_length, rng)
	for index: int in range(guards.size()):
		var route: Array[int] = []
		route.assign(routes[index])
		var stops: Array[Vector2] = [_design(guards[index].global_position)]
		for clock_id: int in route:
			stops.append(_design((clocks[clock_id] as TimeClock3D).global_position))
		var legs: Array[float] = []
		for leg: int in range(route.size()):
			legs.append(leg_seconds(_distance(stops[leg], stops[leg + 1])))
		if route.size() > 1:  # al dar la vuelta, el primer tramo sale del último reloj
			legs[0] = maxf(legs[0], leg_seconds(_distance(stops[-1], stops[1])))
		GuardRound.of(guards[index]).assign(route, legs)
		if guards[index].is_ai_controlled:
			_patrol(guards[index], stops)


## Segundos de un tramo de distance metros
static func leg_seconds(distance: float) -> float:
	if is_inf(distance):
		return RULES.round_duration
	return distance / GUARD_MOVEMENT.walk_speed * RULES.leg_walk_factor + RULES.leg_margin


## Rutas de length relojes para guards guardias: el guardia g empieza en la zona g y alterna
## zonas sin repetir reloj dentro de su ruta
static func pick_routes(
	zones: Dictionary, guards: int, length: int, rng: RandomNumberGenerator
) -> Array:
	var by_zone: Dictionary = {}
	for clock_id: int in zones:
		var zone: String = String(zones[clock_id])
		if not by_zone.has(zone):
			by_zone[zone] = []
		by_zone[zone].append(clock_id)
	var zone_names: Array = by_zone.keys()
	zone_names.sort()
	var routes: Array = []
	for g: int in range(guards):
		var route: Array[int] = []
		var z: int = g
		var tries: int = 0
		while route.size() < mini(length, zones.size()) and tries < length * zone_names.size() * 2:
			var pool: Array = by_zone[zone_names[z % zone_names.size()]].filter(
				func(id: int) -> bool: return not route.has(id)
			)
			if not pool.is_empty():
				route.append(pool[rng.randi_range(0, pool.size() - 1)])
			z += 1
			tries += 1
		routes.append(route)
	return routes


## La IA recorre su ruta: de la garita al primer reloj y luego en bucle (patrol_loop_start)
func _patrol(guard: GuardController3D, stops: Array[Vector2]) -> void:
	var ai: Node = guard.get_node_or_null("GuardAI")
	if ai == null or graph == null or stops.size() < 2:
		return
	var points: Array[Vector3] = _walk(stops[0], stops[1])
	var loop_start: int = points.size()
	for leg: int in range(2, stops.size()):
		points.append_array(_walk(stops[leg - 1], stops[leg]))
	points.append_array(_walk(stops[-1], stops[1]))
	ai.set("patrol_waypoints", points)
	ai.set("patrol_loop_start", loop_start)


func _walk(from: Vector2, to: Vector2) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for point: Vector2 in graph.path(from, to):
		points.append(graph.data.to_world([point.x, point.y], LevelEntitiesBuilder.ACTOR_HEIGHT))
	return points


func _distance(from: Vector2, to: Vector2) -> float:
	return graph.distance(from, to) if graph != null else 0.0


func _design(world: Vector3) -> Vector2:
	var offset: Vector2 = graph.data.offset if graph != null else Vector2.ZERO
	return Vector2(world.x - offset.x, world.z - offset.y)
