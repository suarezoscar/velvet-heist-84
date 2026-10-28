## Estados de los actores que recibe cada peer en un snapshot (FEAT-014, FEAT-017, FEAT-020).
## A un guardia no le llega el ladrón si no lo percibe (o solo «cctv_only» si lo ve una cámara
## mientras mira los monitores); al ladrón no le llega un guardia que no ve (o solo «beam_only»
## si lleva la linterna encendida, vision.md R4). Con la partida terminada no se filtra nada.
class_name NetSnapshots
extends RefCounted

## Lo físico y visible de un actor remoto: nunca la percepción ni la estamina
const REMOTE_KEYS: Array[String] = ["pos", "vel", "rot_y", "crouching", "look", "flashlight"]
## Lo que basta para dibujar solo el haz de un guardia (vision.md R4)
const BEAM_KEYS: Array[String] = ["pos", "rot_y", "look", "flashlight"]


## Vistas del tick: {"guards": rol → &"world"|&"cctv"|&"", "thief": rol → &"full"|&"beam"|&""}
static func compute_views(map: HeistMap3D) -> Dictionary:
	var thief_view: Dictionary = {}
	var lamps: Array[Lamp3D] = VisionLogic.lamps_in(map)
	for index: int in range(mini(map.guards.size(), NetConfig.ROLES.size() - 1)):
		thief_view[NetConfig.ROLES[index + 1]] = VisionLogic.thief_view_of(
			map.thief, map.guards[index], lamps
		)
	return {
		"guards": NetVisibility.guard_views(map.guards, SecurityCamera3D.any_detects(map)),
		"thief": thief_view,
	}


## Estados que recibe peer_role; open (partida terminada) desactiva todos los filtros
static func build(
	session: NetSession, peer_role: StringName, views: Dictionary, open: bool
) -> Dictionary:
	var states: Dictionary = {}
	for role: StringName in NetConfig.ROLES:
		if role == peer_role:
			continue
		var mark: StringName = &"" if open else mark_for(peer_role, role, views)
		if mark == &"hidden":
			continue
		var actor: PlayerBase3D = session.actor_for_role(role)
		if actor == null:
			continue
		var state: Dictionary = remote_state(
			actor, BEAM_KEYS if mark == &"beam_only" else REMOTE_KEYS
		)
		if mark != &"":
			state[String(mark)] = true
		states[role] = state
	return states


## Marca de role para peer_role: &"" (completo), &"cctv_only", &"beam_only" o &"hidden".
## Ante un dato que falta, oculta: un rol sin vista calculada o un peer sin bando no ve nada
static func mark_for(peer_role: StringName, role: StringName, views: Dictionary) -> StringName:
	var peer_is_guard: bool = String(peer_role).begins_with("guard")
	if not peer_is_guard and peer_role != &"thief":
		return &"hidden"
	if role == &"thief" and peer_is_guard:
		match (views["guards"] as Dictionary).get(peer_role, &""):
			&"world":
				return &""
			&"cctv":
				return &"cctv_only"
		return &"hidden"
	if peer_role == &"thief" and String(role).begins_with("guard"):
		match (views["thief"] as Dictionary).get(role, &""):
			&"full":
				return &""
			&"beam":
				return &"beam_only"
		return &"hidden"
	return &""


static func remote_state(actor: PlayerBase3D, keys: Array[String] = REMOTE_KEYS) -> Dictionary:
	var full: Dictionary = actor.get_net_actor_state()
	var state: Dictionary = {}
	for key: String in keys:
		if full.has(key):
			state[key] = full[key]
	return state


## Roles enviados con su marca, para NETLOG («guard_1:beam_only»)
static func log_roles(states: Dictionary) -> Array[String]:
	var roles: Array[String] = []
	for role: StringName in states:
		var mark: String = ""
		for key: String in ["cctv_only", "beam_only"]:
			if (states[role] as Dictionary).has(key):
				mark = ":" + key
		roles.append(String(role) + mark)
	return roles
