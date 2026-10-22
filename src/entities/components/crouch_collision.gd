## Cápsula de pie y agachado, y comprobación de espacio libre para levantarse.
class_name CrouchCollision
extends RefCounted

const STAND_HEIGHT: float = 1.6
const CROUCH_HEIGHT: float = 1.0
const CAPSULE_RADIUS: float = 0.35
## Meta que marca la forma ya duplicada para este personaje (no se comparte con la escena)
const LOCAL_SHAPE_META: StringName = &"vh84_local_shape"


## Ajusta altura, radio y origen (altura / 2) de la cápsula. Si la forma es null crea una
## CapsuleShape3D; si no tiene LOCAL_SHAPE_META, la duplica una vez y la marca.
static func apply(shape_node: CollisionShape3D, crouching: bool) -> void:
	if shape_node == null:
		return

	if shape_node.shape == null:
		var new_shape: CapsuleShape3D = CapsuleShape3D.new()
		new_shape.set_meta(LOCAL_SHAPE_META, true)
		shape_node.shape = new_shape
	elif not shape_node.shape.has_meta(LOCAL_SHAPE_META):
		var dup_shape: Shape3D = shape_node.shape.duplicate()
		dup_shape.set_meta(LOCAL_SHAPE_META, true)
		shape_node.shape = dup_shape

	var capsule: CapsuleShape3D = shape_node.shape as CapsuleShape3D
	if capsule == null:
		return

	var target_height: float = CROUCH_HEIGHT if crouching else STAND_HEIGHT
	capsule.height = target_height
	capsule.radius = CAPSULE_RADIUS
	shape_node.transform.origin = Vector3(0.0, target_height * 0.5, 0.0)


## Rayo desde body.global_position + (0, 0.1, 0) hasta + (0, height, 0), máscara 1, excluyendo
## al cuerpo. Devuelve true si no choca o si el cuerpo no está en el árbol.
static func has_headroom(body: CharacterBody3D, height: float) -> bool:
	if body == null or not body.is_inside_tree():
		return true
	var world_3d: World3D = body.get_world_3d()
	if world_3d == null:
		return true
	var space_state: PhysicsDirectSpaceState3D = world_3d.direct_space_state
	if space_state == null:
		return true
	var from_pos: Vector3 = body.global_position + Vector3(0.0, 0.1, 0.0)
	var to_pos: Vector3 = body.global_position + Vector3(0.0, height, 0.0)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.collision_mask = 1
	query.exclude = [body.get_rid()]
	var hit: Dictionary = space_state.intersect_ray(query)
	return hit.is_empty()
