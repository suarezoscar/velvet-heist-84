## @file guard_exit_cover.gd
## IA sin red durante la cuenta atrás de las rejas (heist.md R7b, decisión 7 de #120): el
## guardia que no persigue ni investiga va corriendo a la salida libre más cercana a la última
## campana (una por guardia, sin repetir la de otro) y espera allí girando la linterna. Con las
## rejas cerradas, solo cubre las salidas que siguen abiertas (#121).
## Además (R7c, #121): si ve una caja de la reja saboteada o a medias a menos de
## box_notice_distance m, va y la repara. Lógica sobre el árbol; la usa GuardAI3D.
class_name GuardExitCover
extends RefCounted

const RULES: HeistRules = preload("res://data/balance/heist_rules.tres")
## Metros a los que se pone a reparar una caja
const REPAIR_REACH: float = 1.2
## Metros hacia dentro de la puerta donde espera (no en el umbral)
const INSIDE: float = 1.5
## Radianes por segundo que gira la linterna mientras espera
const SWEEP_SPEED: float = 1.2


## Punto donde cubrir la salida libre más cercana a la última campana, o null sin cuenta atrás
## o sin salidas libres
static func pick(ai: GuardAI3D, guard: Node3D) -> Variant:
	var tree: SceneTree = ai.get_tree()
	var lockdown: HeistLockdown = HeistLockdown.of(tree)
	if lockdown == null or not lockdown.escapes_open():
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
		if zone == null or zone.outdoor or taken.has(zone) or not lockdown.exit_open(zone.exit_id):
			continue
		if best == null or _flat(zone.global_position, bell) < _flat(best.global_position, bell):
			best = zone
	if best == null:
		return null
	ai.cover_exit = best
	var inward: Vector3 = (guard.global_position - best.global_position).slide(Vector3.UP)
	return best.global_position + inward.normalized() * INSIDE


## Cada tick: reparar una caja que ve manda sobre cubrir; con la cuenta atrás (o salidas abiertas
## tras el cierre) patrullar o ir a por café pasa a cubrir una salida
static func update(ai: GuardAI3D, guard: GuardController3D) -> void:
	var state: GuardAI3D.AIState = ai.current_state
	var lockdown: HeistLockdown = HeistLockdown.of(ai.get_tree())
	if ai.cover_exit != null and lockdown != null and not lockdown.exit_open(ai.cover_exit.exit_id):
		ai.cover_exit = null  # su reja ya bajó: a por otra
		if state == GuardAI3D.AIState.COVER:
			ai.current_state = GuardAI3D.AIState.PATROL
	if state in [GuardAI3D.AIState.PATROL, GuardAI3D.AIState.COFFEE, GuardAI3D.AIState.COVER]:
		var box: GateBox3D = spot_box(guard)
		if box != null:
			ai.repair_box = box
			ai.current_state = GuardAI3D.AIState.REPAIR
			return
	if ai.current_state == GuardAI3D.AIState.PATROL or ai.current_state == GuardAI3D.AIState.COFFEE:
		var point: Variant = ai.cover_point if ai.cover_exit != null else pick(ai, guard)
		if point is Vector3:
			ai.cover_point = point
			ai.current_state = GuardAI3D.AIState.COVER
			ai.go_to(GuardPatrol.of(ai.get_tree()), point)


## Los estados COVER (ir y esperar en la salida) y REPAIR (ir a la caja y repararla)
static func process(ai: GuardAI3D, guard: GuardController3D) -> void:
	if ai.current_state == GuardAI3D.AIState.REPAIR:
		_repair(ai, guard)
		return
	if _flat(ai.cover_point, guard.global_position) > GuardAI3D.WAYPOINT_REACHED_DISTANCE:
		ai.follow_path(ai.cover_point, true)  # con la alarma, corriendo
	else:
		watch(guard, Time.get_ticks_msec() / 1000.0)


## Caja de la reja saboteada o a medias que el guardia ve de cerca (sin muro en medio), o null
static func spot_box(guard: GuardController3D) -> GateBox3D:
	if GuardSleep.sees_nothing(guard):
		return null
	for node: Node in guard.get_tree().get_nodes_in_group(&"gate_boxes"):
		var box: GateBox3D = node as GateBox3D
		if box == null or not box.is_tampered():
			continue
		if _flat(box.global_position, guard.global_position) > RULES.box_notice_distance:
			continue
		var from: Vector3 = guard.global_position + Vector3.UP * 1.5
		var to: Vector3 = box.global_position + Vector3(0.0, GateBox3D.HEIGHT, 0.0)
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
		query.exclude = [guard.get_rid()]
		if guard.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			return box
	return null


static func _repair(ai: GuardAI3D, guard: GuardController3D) -> void:
	var box: GateBox3D = ai.repair_box
	if box == null or not is_instance_valid(box) or not box.is_tampered():
		ai.repair_box = null  # reparada: vuelve a lo suyo
		ai.current_state = GuardAI3D.AIState.PATROL
		return
	var to_box: Vector3 = (box.global_position - guard.global_position).slide(Vector3.UP)
	guard.look_target_position = box.global_position
	if to_box.length() > REPAIR_REACH:
		guard.apply_world_move(to_box.normalized())
		return
	guard.apply_world_move(Vector3.ZERO)
	if box.can_interact(guard):
		box.interact(guard)


## Quieto en la salida, girando la linterna
static func watch(guard: GuardController3D, time: float) -> void:
	guard.apply_world_move(Vector3.ZERO)
	var angle: float = time * SWEEP_SPEED
	guard.look_target_position = guard.global_position + Vector3(sin(angle), 0.0, cos(angle)) * 3.0


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
