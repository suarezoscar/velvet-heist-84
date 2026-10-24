## @file interactor_3d.gd
## Componente desacoplado que gestiona el escaneo y la ejecución de interacciones físicas
## hacia objetos del entorno (cajas fuertes, botín, teléfonos de disco, coches de fuga).
class_name Interactor3D
extends Node3D

## Señal emitida cuando el personaje apunta a un objeto interactuable válido
signal target_focused(target: Node3D)

## Señal emitida cuando el personaje deja de apuntar a un objeto interactuable
signal target_unfocused

## Capa de colisión exclusiva para objetos interactuables en el mapa
const INTERACTION_LAYER_MASK: int = 4

## Capa del entorno sólido, donde están los muros
const WORLD_SOLID_MASK: int = 1

## Altura (m) sobre el personaje a la que se comprueba que ningún muro tapa el objetivo
const WALL_CHECK_HEIGHT: float = 1.0

## Cuerpos sólidos que puede saltarse la comprobación (muebles) antes de rendirse
const WALL_CHECK_MAX_HITS: int = 8

## Alcance máximo de interacción en metros
@export var reach_distance: float = 1.8

var current_target: Node3D = null
var _ray: RayCast3D = null


func _ready() -> void:
	_setup_interaction_ray()


func _setup_interaction_ray() -> void:
	_ray = RayCast3D.new()
	_ray.name = "InteractionRay"
	_ray.target_position = Vector3(0.0, 0.0, -reach_distance)
	_ray.collision_mask = INTERACTION_LAYER_MASK
	_ray.collide_with_areas = true
	_ray.collide_with_bodies = true
	_ray.enabled = true
	add_child(_ray)


func _physics_process(_delta: float) -> void:
	_scan_for_interactables()


## Escanea continuamente en cada frame físico en busca de objetos con método `interact`
func _scan_for_interactables() -> void:
	var detected_target: Node3D = null

	if _ray != null and _ray.is_colliding():
		var collider: Object = _ray.get_collider()
		if collider is Node3D and collider.has_method("interact"):
			# Comprobar si el interactuable permite ser usado actualmente
			var can_use: bool = true
			if collider.has_method("can_interact"):
				can_use = bool(collider.call("can_interact", get_parent()))
			if can_use and _is_behind_wall(collider as Node3D, _ray.get_collision_point()):
				can_use = false
			if can_use:
				detected_target = collider as Node3D

	if detected_target != current_target:
		current_target = detected_target
		if current_target != null:
			target_focused.emit(current_target)
		else:
			target_unfocused.emit()


## true si un muro (grupo walls) se interpone entre el personaje y el punto del objetivo. El
## rayo de interacción solo ve la capa 4 y atravesaba paredes. Los muebles (coberturas,
## pedestales) y los cuerpos del propio objetivo y del personaje no cuentan.
func _is_behind_wall(target: Node3D, hit_point: Vector3) -> bool:
	if not is_inside_tree() or get_world_3d() == null:
		return false
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var from: Vector3 = global_position + Vector3(0.0, WALL_CHECK_HEIGHT, 0.0)
	var to: Vector3 = Vector3(hit_point.x, from.y, hit_point.z)
	var exclude: Array[RID] = []
	for owner_node: Node in [target, get_parent()]:
		if owner_node is CollisionObject3D:
			exclude.append((owner_node as CollisionObject3D).get_rid())
		for body: Node in owner_node.find_children("*", "CollisionObject3D", true, false):
			exclude.append((body as CollisionObject3D).get_rid())
	for _i: int in range(WALL_CHECK_MAX_HITS):
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			from, to, WORLD_SOLID_MASK, exclude
		)
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			return false
		var collider: Object = hit.get("collider")
		if (
			collider is Node
			and (collider as Node).is_in_group(LevelArchitectureBuilder.WALLS_GROUP)
		):
			return true
		exclude.append(hit.get("rid") as RID)
	return false


## Ejecuta la interacción sobre el objetivo actualmente enfocado
func execute_interaction(actor: Node3D) -> bool:
	if current_target != null and current_target.has_method("interact"):
		current_target.call("interact", actor)
		return true
	return false


## Devuelve el texto del tooltip informativo para el HUD
func get_target_prompt_text() -> String:
	if current_target != null and current_target.has_method("get_interaction_text"):
		return str(current_target.call("get_interaction_text", get_parent()))
	return ""
