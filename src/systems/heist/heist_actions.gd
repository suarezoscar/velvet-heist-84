## @file heist_actions.gd
## Acciones del golpe (heist.md R7-R8), validadas por quien tiene la autoridad (el servidor o
## la partida sin red):
## - throw_coin (ladrón): lanza una moneda al punto del ratón (CoinThrow: alcance, muros y
##   arco). Vuela en arco y suena al caer como un ruido del ladrón: los guardias no lo
##   distinguen de un paso. Quedan RULES.coins por partida (FEAT-038);
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
	if actor is ThiefController3D and (actor as ThiefController3D).in_vent:
		return false  # FEAT-034: desde el conducto no se lanza nada
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
	var from: Vector3 = CoinThrow.origin(thief)
	var landing: Vector3 = CoinThrow.landing(thief, thief.look_target_position)
	var flight: float = CoinThrow.flight_time(from, landing)
	heist.coins_left -= 1
	SignalBus.coin_thrown.emit(from, landing, flight)
	# Suena al caer. Ruido del ladrón sin emisor: a quien lo oye le llega como cualquier otro
	thief.get_tree().create_timer(flight, false).timeout.connect(
		func() -> void:
			NoiseEmit.emit(landing, RULES.coin_radius, &"thief", NoiseEmit.MECHANISM, null)
	)
	return true


static func walkie(guard: GuardController3D, alert: AlertDirector) -> bool:
	var now: float = Time.get_ticks_msec() / 1000.0
	if GuardSleep.sees_nothing(guard) or now < float(guard.get_meta(&"walkie_ready_at", 0.0)):
		return false
	guard.set_meta(&"walkie_ready_at", now + RULES.walkie_cooldown)
	alert.add_ping(guard.look_target_position)
	NoiseEmit.emit(guard.global_position, RULES.walkie_radius, &"guard", NoiseEmit.MECHANISM, guard)
	return true
