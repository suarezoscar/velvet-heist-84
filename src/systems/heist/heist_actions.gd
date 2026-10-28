## @file heist_actions.gd
## Acciones del golpe (heist.md R7-R8), validadas por quien tiene la autoridad (el servidor o
## la partida sin red):
## - throw_coin (ladrón): lanza una moneda al punto del ratón, a RULES.throw_range como mucho
##   (si hay un muro, cae contra él). Suena como un ruido del ladrón: los guardias no lo
##   distinguen de un paso. Quedan RULES.coins por partida;
## - walkie (guardia): marca el punto del ratón en el plano del equipo; el chasquido delata a
##   quien habla. Espera RULES.walkie_cooldown entre usos;
## - alarm_lights (guardia, en alarma): enciende las lámparas cercanas (AlertDirector.flood).
class_name HeistActions
extends RefCounted

const RULES: HeistRules = preload("res://data/balance/heist_rules.tres")
const ACTIONS: Array[StringName] = [&"throw_coin", &"walkie", &"alarm_lights"]


## true si la acción es del golpe y se ha ejecutado
static func handle(actor: PlayerBase3D, action: StringName) -> bool:
	if not ACTIONS.has(action) or actor == null or not actor.is_inside_tree():
		return false
	if GameManager.current_state != GameManager.MatchState.IN_PROGRESS:
		return false
	var heist: HeistDirector = GameManager.heist
	var alert: AlertDirector = AlertDirector.of(actor.get_tree())
	if heist == null or alert == null:
		return false
	match action:
		&"throw_coin":
			return actor is ThiefController3D and throw_coin(actor, heist)
		&"walkie":
			return actor is GuardController3D and walkie(actor as GuardController3D, alert)
		&"alarm_lights":
			return actor is GuardController3D and alert.flood(actor.global_position)
	return false


static func throw_coin(thief: PlayerBase3D, heist: HeistDirector) -> bool:
	if heist.coins_left <= 0:
		return false
	var from: Vector3 = thief.global_position + Vector3.UP
	var aim: Vector3 = thief.look_target_position - thief.global_position
	aim.y = 0.0
	if aim.length() < 0.5:
		aim = -thief.global_basis.z
	var target: Vector3 = thief.global_position + aim.limit_length(RULES.throw_range)
	target.y = from.y
	var space: PhysicsDirectSpaceState3D = thief.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, target, LevelArchitectureBuilder.LAYER_WALLS
	)
	var hit: Dictionary = space.intersect_ray(query)
	var landing: Vector3 = (hit["position"] as Vector3) if not hit.is_empty() else target
	landing.y = thief.global_position.y
	heist.coins_left -= 1
	# Ruido del ladrón sin emisor: a quien lo oye le llega como cualquier otro ruido suyo
	NoiseEmit.emit(landing, RULES.coin_radius, &"thief", NoiseEmit.MECHANISM, null)
	return true


static func walkie(guard: GuardController3D, alert: AlertDirector) -> bool:
	var now: float = Time.get_ticks_msec() / 1000.0
	if GuardSleep.sees_nothing(guard) or now < float(guard.get_meta(&"walkie_ready_at", 0.0)):
		return false
	guard.set_meta(&"walkie_ready_at", now + RULES.walkie_cooldown)
	alert.add_ping(guard.look_target_position)
	NoiseEmit.emit(guard.global_position, RULES.walkie_radius, &"guard", NoiseEmit.MECHANISM, guard)
	return true
