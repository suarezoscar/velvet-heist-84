## @file vision_logic.gd
## Reglas puras de la visión (vision.md): línea de visión cortada solo por muros y tabiques,
## radio de cada bando y cuándo el ladrón ve a un guardia (R3).
class_name VisionLogic
extends RefCounted

const RULES: VisionProfile = preload("res://data/balance/vision_rules.tres")
const PERCEPTION: PerceptionProfile = preload("res://data/balance/perception_guard.tres")
## Altura (m) del punto del guardia que se comprueba con luz
const LIT_CHECK_HEIGHT: float = 1.2


## Ojos del personaje (eye_height de perception_guard.tres)
static func eye(actor: Node3D) -> Vector3:
	return actor.global_position + Vector3(0.0, PERCEPTION.eye_height, 0.0)


## Radio de la zona visible según el bando
static func view_radius(actor: Node3D) -> float:
	return RULES.thief_view_radius if actor is ThiefController3D else RULES.guard_view_radius


## true si ningún muro ni tabique del nivel corta el segmento
static func wall_free(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	if space == null:
		return true
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, to, LevelArchitectureBuilder.LAYER_WALLS
	)
	return space.intersect_ray(query).is_empty()


## true si point está en la zona visible del actor (R1): dentro de su radio y sin muros entre
## sus ojos y el punto
static func sees_point(actor: Node3D, point: Vector3) -> bool:
	if actor == null or not actor.is_inside_tree():
		return false
	if PerceptionRules.horizontal_distance(actor.global_position, point) > view_radius(actor):
		return false
	var space: PhysicsDirectSpaceState3D = actor.get_world_3d().direct_space_state
	return wall_free(space, eye(actor), point + Vector3(0.0, 0.3, 0.0))


## R3: el ladrón ve al guardia si está en su zona visible y además iluminado, con la linterna
## encendida o a dark_sight_radius o menos
static func thief_sees_guard(
	thief: ThiefController3D, guard: GuardController3D, lamps: Array[Lamp3D]
) -> bool:
	if thief == null or guard == null or not thief.is_inside_tree() or not guard.is_inside_tree():
		return false
	var distance: float = PerceptionRules.horizontal_distance(
		thief.global_position, guard.global_position
	)
	if distance > RULES.thief_view_radius:
		return false
	var space: PhysicsDirectSpaceState3D = thief.get_world_3d().direct_space_state
	if not wall_free(space, eye(thief), eye(guard)):
		return false
	if guard.flashlight_on or distance <= RULES.dark_sight_radius:
		return true
	var point: Vector3 = guard.global_position + Vector3(0.0, LIT_CHECK_HEIGHT, 0.0)
	return LightingRules.is_point_lit(space, point, lamps)


## Cómo ve el ladrón a cada guardia: &"full", &"cctv" (solo en las pantallas, si está ante los
## monitores), &"beam" (solo el haz) o &"" (nada)
static func thief_view_of(
	thief: ThiefController3D, guard: GuardController3D, lamps: Array[Lamp3D]
) -> StringName:
	if thief_sees_guard(thief, guard, lamps):
		return &"full"
	if thief.is_watching_monitors() and SecurityCamera3D.any_sees_guard(thief, guard, lamps):
		return &"cctv"  # FEAT-042: lo ve solo en las imágenes de las cámaras
	return &"beam" if guard.flashlight_on else &""


## Lámparas del árbol de context
static func lamps_in(context: Node) -> Array[Lamp3D]:
	var lamps: Array[Lamp3D] = []
	if context == null or not context.is_inside_tree():
		return lamps
	for node: Node in context.get_tree().get_nodes_in_group(&"lamps"):
		if node is Lamp3D:
			lamps.append(node as Lamp3D)
	return lamps
