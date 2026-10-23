## Reglas puras de percepción cercana (sin estado ni física); las usan guardia, IA y mapa.
class_name PerceptionRules
extends RefCounted


## Distancia en el plano XZ
static func horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Verdadero si target está en el arco ciego trasero del observador. Se usan las proyecciones
## XZ de observer_forward y de (target_pos - observer_pos). Si alguna mide < 0.001, devuelve
## false. Ángulo en grados entre ellas; devuelve ángulo > 180.0 - arc_deg / 2.0 (el borde
## pertenece al arco visible).
static func is_in_rear_blind_arc(
	observer_pos: Vector3, observer_forward: Vector3, target_pos: Vector3, arc_deg: float
) -> bool:
	var fwd_2d: Vector2 = Vector2(observer_forward.x, observer_forward.z)
	var to_target_3d: Vector3 = target_pos - observer_pos
	var to_target_2d: Vector2 = Vector2(to_target_3d.x, to_target_3d.z)
	if fwd_2d.length() < 0.001 or to_target_2d.length() < 0.001:
		return false
	var angle_deg: float = rad_to_deg(absf(fwd_2d.angle_to(to_target_2d)))
	return angle_deg > 180.0 - arc_deg / 2.0


## Puntos del mundo: target.global_position + Vector3(0, h, 0) para cada h de
## profile.crouch_points si target.is_crouching, o de profile.stand_points si no
static func visibility_points(target: PlayerBase3D, profile: PerceptionProfile) -> Array[Vector3]:
	var points: Array[Vector3] = []
	if target == null or profile == null:
		return points
	var heights: PackedFloat32Array = (
		profile.crouch_points if target.is_crouching else profile.stand_points
	)
	for h: float in heights:
		points.append(target.global_position + Vector3(0.0, h, 0.0))
	return points


## true si viewer es null o viewer.team_id != &"guard"; si es guardia,
## horizontal_distance(viewer.global_position, origin) <= radius
static func ring_visible_to(viewer: PlayerBase3D, origin: Vector3, radius: float) -> bool:
	if viewer == null or viewer.team_id != &"guard":
		return true
	return horizontal_distance(viewer.global_position, origin) <= radius


## Sector horizontal: d_h <= range y ángulo en XZ entre axis y (target - origin) <= half_angle_deg
## (el borde pertenece al cono). Si alguna proyección XZ mide < 0.001, devuelve false.
static func is_in_flashlight_cone(
	origin: Vector3, axis: Vector3, target: Vector3, range_m: float, half_angle_deg: float
) -> bool:
	var axis_2d: Vector2 = Vector2(axis.x, axis.z)
	var to_target_3d: Vector3 = target - origin
	var to_target_2d: Vector2 = Vector2(to_target_3d.x, to_target_3d.z)
	var d_h: float = to_target_2d.length()
	if axis_2d.length() < 0.001 or d_h < 0.001:
		return false
	if d_h > range_m:
		return false
	var angle_deg: float = rad_to_deg(absf(axis_2d.angle_to(to_target_2d)))
	return angle_deg <= half_angle_deg
