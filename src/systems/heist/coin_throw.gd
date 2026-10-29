## @file coin_throw.gd
## Reglas puras de la moneda del ladrón (heist.md R8, FEAT-038), compartidas por la mira, el
## lanzamiento y lo que se dibuja:
## - cae en el punto del ratón, a RULES.throw_range como mucho; pasa por encima de los muebles
##   bajos y por los vanos, y se para contra muros y puertas cerradas (capa de muros);
## - vuela en arco RULES.coin_flight_time segundos a throw_range, menos cuanto más cerca cae.
class_name CoinThrow
extends RefCounted

const RULES: HeistRules = preload("res://data/balance/heist_rules.tres")
## Altura (m) de la mano del ladrón al lanzar
const HAND_HEIGHT: float = 1.2
## Altura del rayo contra muros (m sobre el suelo): por encima de los muebles bajos
const WALL_CHECK_HEIGHT: float = 1.0
## Cuánto se separa la moneda del muro con el que choca (m)
const WALL_GAP: float = 0.3
## Altura del arco respecto a la distancia
const ARC_RISE: float = 0.25
## Vuelo mínimo (s), para que un lanzamiento a los pies también se vea
const MIN_FLIGHT: float = 0.15


## Punto de salida de la moneda: la mano del ladrón
static func origin(thief: Node3D) -> Vector3:
	return thief.global_position + Vector3(0.0, HAND_HEIGHT, 0.0)


## Dónde cae una moneda lanzada hacia aim_point (en el suelo del ladrón)
static func landing(thief: PlayerBase3D, aim_point: Vector3) -> Vector3:
	var flat: Vector3 = aim_point - thief.global_position
	flat.y = 0.0
	if flat.length() < 0.5:
		flat = -thief.global_basis.z
	var reach: Vector3 = flat.limit_length(RULES.throw_range)
	var from: Vector3 = thief.global_position + Vector3(0.0, WALL_CHECK_HEIGHT, 0.0)
	var target: Vector3 = from + reach
	if thief.is_inside_tree():
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			from, target, LevelArchitectureBuilder.LAYER_WALLS
		)
		var hit: Dictionary = thief.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var stop: Vector3 = hit["position"] as Vector3
			target = stop - reach.normalized() * minf(WALL_GAP, from.distance_to(stop))
	target.y = thief.global_position.y
	return target


## Segundos de vuelo entre dos puntos
static func flight_time(from: Vector3, to: Vector3) -> float:
	var flat: float = Vector2(to.x - from.x, to.z - from.z).length()
	return maxf(MIN_FLIGHT, RULES.coin_flight_time * flat / RULES.throw_range)


## Punto del arco en t (0 = mano, 1 = suelo)
static func arc_point(from: Vector3, to: Vector3, t: float) -> Vector3:
	var flat: float = Vector2(to.x - from.x, to.z - from.z).length()
	var point: Vector3 = from.lerp(to, t)
	point.y += 4.0 * flat * ARC_RISE * t * (1.0 - t)
	return point
