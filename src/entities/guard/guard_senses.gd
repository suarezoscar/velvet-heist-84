## Componente de sentidos y detección visual y física para GuardController3D.
## Evalúa proximidad inmediata, cono de linterna Maglite y detección por iluminación.
class_name GuardSenses
extends RefCounted

const PERCEPTION_PROFILE_PATH: String = "res://data/balance/perception_guard.tres"


## Evalúa si el guardia detecta al ladrón devolviendo el método de detección:
## &"proximity", &"cone", &"light" o &"" si pasa desapercibido.
func detects(
	guard: GuardController3D, thief: ThiefController3D, lamps: Array[Lamp3D]
) -> StringName:
	if not _is_detection_valid(guard, thief):
		return &""

	var space_state: PhysicsDirectSpaceState3D = guard.get_world_3d().direct_space_state
	var perception: PerceptionProfile = guard.perception
	if perception == null:
		perception = load(PERCEPTION_PROFILE_PATH) as PerceptionProfile

	var guard_pos: Vector3 = guard.global_position
	var thief_pos: Vector3 = thief.global_position
	var eyes: Vector3 = guard_pos + Vector3(0.0, perception.eye_height, 0.0)
	var guard_forward: Vector3 = -guard.global_transform.basis.z
	var points: Array[Vector3] = PerceptionRules.visibility_points(thief, perception)

	var in_rear_arc: bool = PerceptionRules.is_in_rear_blind_arc(
		guard_pos, guard_forward, thief_pos, perception.rear_blind_arc_deg
	)

	# 1. Proximidad inmediata
	if not in_rear_arc:
		var d_prox: float = PerceptionRules.horizontal_distance(guard_pos, thief_pos)
		if d_prox <= perception.proximity_radius:
			for pt: Vector3 in points:
				if has_line_of_sight(space_state, eyes, pt):
					return &"proximity"

	# Mirando los monitores no ve el mundo: solo le quedan la proximidad y el oído (M3)
	if guard.is_watching_monitors():
		return &""

	# 2. Cono horizontal de la linterna Maglite
	if cone_sees(guard, thief):
		return &"cone"

	# 3. Detección por luz de lámparas
	if not in_rear_arc and light_point_lit(thief, lamps):
		var d_light: float = PerceptionRules.horizontal_distance(guard_pos, thief_pos)
		if d_light <= perception.lit_sight_range:
			for pt: Vector3 in points:
				if LightingRules.is_point_lit(space_state, pt, lamps):
					if has_line_of_sight(space_state, eyes, pt):
						return &"light"

	return &""


## Determina si el guardia ve al ladrón con el cono de su linterna encendida
static func cone_sees(guard: GuardController3D, thief: ThiefController3D) -> bool:
	if not _is_detection_valid(guard, thief) or not guard.flashlight_on:
		return false

	var space_state: PhysicsDirectSpaceState3D = guard.get_world_3d().direct_space_state
	var perception: PerceptionProfile = guard.perception
	if perception == null:
		perception = load(PERCEPTION_PROFILE_PATH) as PerceptionProfile

	var guard_pos: Vector3 = guard.global_position
	var thief_pos: Vector3 = thief.global_position
	var guard_forward: Vector3 = -guard.global_transform.basis.z
	var points: Array[Vector3] = PerceptionRules.visibility_points(thief, perception)

	var eje: Vector3 = Vector3(guard_forward.x, 0.0, guard_forward.z)
	var range_m: float = perception.flashlight_range
	var half_angle: float = perception.flashlight_half_angle_deg
	var in_cone: bool = PerceptionRules.is_in_flashlight_cone(
		guard_pos, eje, thief_pos, range_m, half_angle
	)
	if not in_cone:
		return false

	var flash_pos: Vector3 = guard_pos + Vector3(0.0, perception.flashlight_height, 0.0)
	for pt: Vector3 in points:
		if has_line_of_sight(space_state, flash_pos, pt):
			return true

	return false


## Comprueba si algún punto de visibilidad del ladrón está iluminado por lámparas activas
static func light_point_lit(thief: ThiefController3D, lamps: Array[Lamp3D]) -> bool:
	if thief == null or not thief.is_inside_tree() or lamps.is_empty():
		return false
	var world_3d: World3D = thief.get_world_3d()
	if world_3d == null or world_3d.direct_space_state == null:
		return false
	var space_state: PhysicsDirectSpaceState3D = world_3d.direct_space_state
	var profile: PerceptionProfile = load(PERCEPTION_PROFILE_PATH) as PerceptionProfile
	var points: Array[Vector3] = PerceptionRules.visibility_points(thief, profile)
	for pt: Vector3 in points:
		if LightingRules.is_point_lit(space_state, pt, lamps):
			return true
	return false


static func _is_detection_valid(guard: GuardController3D, thief: ThiefController3D) -> bool:
	if guard == null or thief == null:
		return false
	if not guard.is_inside_tree() or not thief.is_inside_tree():
		return false
	var world_3d: World3D = guard.get_world_3d()
	return world_3d != null and world_3d.direct_space_state != null


static func has_line_of_sight(
	space_state: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3
) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	var result: Dictionary = space_state.intersect_ray(query)
	return result.is_empty()
