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
