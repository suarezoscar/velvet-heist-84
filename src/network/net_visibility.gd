## Reglas puras del filtro de visibilidad del ladrón por peer (FEAT-014).
## Decide qué roles remotos recibe un cliente en cada snapshot del servidor.
class_name NetVisibility
extends RefCounted


## Roles cuyo estado remoto recibe peer_role; nunca incluye el propio.
## Un peer de guardia no recibe al ladrón mientras no lo percibe.
static func roles_visible_to(peer_role: StringName, perceiving: Dictionary) -> Array[StringName]:
	var visible: Array[StringName] = []
	for role: StringName in NetConfig.ROLES:
		if role == peer_role:
			continue
		if role == &"thief" and String(peer_role).begins_with("guard"):
			if not bool(perceiving.get(peer_role, false)):
				continue
		visible.append(role)
	return visible


## Cómo ve cada rol de guardia al ladrón (interaction.md M6): &"world" si lo percibe él,
## &"cctv" si solo una cámara lo detecta mientras ese guardia mira los monitores, o &"".
## Los guardias van en orden de escena: guards[i] es NetConfig.ROLES[i + 1].
static func guard_views(guards: Array[GuardController3D], cameras_detect: bool) -> Dictionary:
	var views: Dictionary = {}
	for index: int in range(guards.size()):
		if index + 1 >= NetConfig.ROLES.size():
			break
		var guard: GuardController3D = guards[index]
		var view: StringName = &""
		if guard.is_perceiving_thief:
			view = &"world"
		elif cameras_detect and guard.is_watching_monitors():
			view = &"cctv"
		views[NetConfig.ROLES[index + 1]] = view
	return views
