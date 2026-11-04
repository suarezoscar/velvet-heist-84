## @file guard_exit_cover.gd
## IA sin red durante la cuenta atrás de las rejas (heist.md R7b, decisión 7 de #120): el
## guardia que no persigue ni investiga va corriendo a la salida libre más cercana a la última
## campana (una por guardia, sin repetir la de otro) y espera allí girando la linterna.
## Lógica pura sobre el árbol; la usa GuardAI3D.
class_name GuardExitCover
extends RefCounted

## Metros hacia dentro de la puerta donde espera (no en el umbral)
const INSIDE: float = 1.5
## Radianes por segundo que gira la linterna mientras espera
const SWEEP_SPEED: float = 1.2


## Punto donde cubrir la salida libre más cercana a la última campana, o null sin cuenta atrás
## o sin salidas libres
static func pick(ai: GuardAI3D, guard: Node3D) -> Variant:
	var tree: SceneTree = ai.get_tree()
	var lockdown: HeistLockdown = HeistLockdown.of(tree)
	if lockdown == null or not lockdown.is_running():
		return null
	var bell: Vector3 = guard.global_position
	var alert: AlertDirector = AlertDirector.of(tree)
	if alert != null and not alert.alarm_marks.is_empty():
		bell = alert.alarm_marks.back()["pos"]
	var taken: Array[ExitZone3D] = []
	for node: Node in tree.get_nodes_in_group(&"guards"):
		var other: GuardAI3D = node.get_node_or_null("GuardAI") as GuardAI3D
		if other != null and other != ai and other.cover_exit != null:
			taken.append(other.cover_exit)
	var best: ExitZone3D = null
	for node: Node in tree.get_nodes_in_group(&"heist_exits"):
		var zone: ExitZone3D = node as ExitZone3D
		if zone == null or zone.outdoor or taken.has(zone):
			continue
		if best == null or _flat(zone.global_position, bell) < _flat(best.global_position, bell):
			best = zone
	if best == null:
		return null
	ai.cover_exit = best
	var inward: Vector3 = (guard.global_position - best.global_position).slide(Vector3.UP)
	return best.global_position + inward.normalized() * INSIDE


## Quieto en la salida, girando la linterna
static func watch(guard: GuardController3D, time: float) -> void:
	guard.apply_world_move(Vector3.ZERO)
	var angle: float = time * SWEEP_SPEED
	guard.look_target_position = guard.global_position + Vector3(sin(angle), 0.0, cos(angle)) * 3.0


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
