## Reglas puras del sistema de iluminación para determinar si puntos del mundo reciben luz.
## Verifica la distancia horizontal al radio de iluminación y la visibilidad por raycast.
class_name LightingRules
extends RefCounted


## Devuelve true si alguna lámpara de `lamps` con is_lit() cumple:
## horizontal_distance(lamp, point) <= lit_radius y rayo libre hacia point (máscara 1).
static func is_point_lit(
	space: PhysicsDirectSpaceState3D, point: Vector3, lamps: Array[Lamp3D]
) -> bool:
	if space == null:
		return false
	for lamp: Lamp3D in lamps:
		if lamp == null or not lamp.is_lit() or lamp.profile == null:
			continue
		var lamp_pos: Vector3 = lamp.global_position
		var d_h: float = Vector2(lamp_pos.x - point.x, lamp_pos.z - point.z).length()
		if d_h <= lamp.profile.lit_radius:
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
				lamp_pos, point
			)
			query.collision_mask = 1
			var result: Dictionary = space.intersect_ray(query)
			if result.is_empty():
				return true
	return false
