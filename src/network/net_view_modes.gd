## Aplica en el cliente cómo ve el jugador local a los demás según el último snapshot
## (FEAT-017 y FEAT-020): un guardia local ve al ladrón en el mundo, solo en las imágenes CCTV
## o nada; el ladrón local ve a cada guardia entero, solo su haz o nada.
class_name NetViewModes
extends RefCounted


static func apply(map: HeistMap3D, local_role: StringName, states: Dictionary) -> void:
	var present: Dictionary = {}
	for key: Variant in states:
		present[StringName(key)] = states[key]
	if String(local_role).begins_with("guard") and map.thief != null:
		var mode: ThiefController3D.ViewMode = ThiefController3D.ViewMode.HIDDEN
		if present.has(&"thief"):
			var cctv: bool = bool((present[&"thief"] as Dictionary).get("cctv_only", false))
			mode = ThiefController3D.ViewMode.CCTV if cctv else ThiefController3D.ViewMode.WORLD
		map.thief.set_view_mode(mode)
	if local_role == &"thief":
		for index: int in range(map.guards.size()):
			var role: StringName = (
				NetConfig.ROLES[index + 1] if index + 1 < NetConfig.ROLES.size() else &""
			)
			var guard: GuardController3D = map.guards[index]
			if not present.has(role):
				# Fuera del snapshot (o sin rol): ni cuerpo ni un haz congelado en su último sitio
				guard.set_body_visible(false)
				guard.apply_flashlight_state(false)
				continue
			var state: Dictionary = present[role]
			guard.set_body_visible(not bool(state.get("beam_only", false)))
