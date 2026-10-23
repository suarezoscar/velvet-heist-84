## Lectura y escritura del estado de red de un actor (FEAT-014, contrato de PKG-2).
## PlayerBase3D lo usa desde get_net_actor_state y apply_net_actor_state.
class_name ActorNetState
extends RefCounted


## Devuelve el snapshot de estado del actor; los guardias añaden linterna, estamina y percepción
static func read(actor: PlayerBase3D) -> Dictionary:
	var state: Dictionary = {
		"crouching": actor.is_crouching,
		"look": actor.look_target_position,
		"pos": actor.global_position,
		"rot_y": actor.rotation.y,
		"vel": actor.velocity,
	}
	if actor is GuardController3D:
		var guard: GuardController3D = actor as GuardController3D
		state["flashlight"] = guard.flashlight_on
		state["last_seen_left"] = guard.last_seen_time_left
		state["last_seen_pos"] = guard.last_seen_position
		state["perceiving"] = guard.is_perceiving_thief
		state["stamina"] = guard.stamina
	return state


## Aplica un snapshot recibido por red; las claves ausentes conservan su valor actual
static func write(actor: PlayerBase3D, state: Dictionary) -> void:
	if state.has("pos"):
		actor.global_position = state["pos"] as Vector3
	if state.has("vel"):
		actor.velocity = state["vel"] as Vector3
	if state.has("rot_y"):
		actor.rotation.y = float(state["rot_y"])
	if state.has("look"):
		actor.look_target_position = state["look"] as Vector3
	if state.has("crouching"):
		actor.set_crouching(bool(state["crouching"]))
	actor.is_net_interpolating = false
	if actor is GuardController3D:
		var guard: GuardController3D = actor as GuardController3D
		if state.has("flashlight"):
			guard.apply_flashlight_state(bool(state["flashlight"]))
		guard.stamina = float(state.get("stamina", guard.stamina))
		guard.is_perceiving_thief = bool(state.get("perceiving", guard.is_perceiving_thief))
		guard.last_seen_position = state.get("last_seen_pos", guard.last_seen_position) as Vector3
		guard.last_seen_time_left = float(state.get("last_seen_left", guard.last_seen_time_left))
