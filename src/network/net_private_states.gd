## Estados privados del mundo por audiencia (FEAT-014 y FEAT-016): la caja fuerte solo
## para el ladrón y los relojes de ronda solo para los guardias. Cada nodo del grupo
## net_state que tenga get_net_state_private() y net_private_audience() entra aquí.
class_name NetPrivateStates
extends RefCounted

const SUFFIX: String = "#private"

var _last: Dictionary = {}


## true si un peer con el rol role debe recibir los estados de la audiencia audience
static func audience_matches(audience: StringName, role: StringName) -> bool:
	if audience == &"guard":
		return String(role).begins_with("guard")
	return audience == role


## {audiencia: {ruta#private: estado}}; con full, todos aunque no hayan cambiado (para un
## peer nuevo, sin tocar lo último enviado a los demás)
func collect(world_nodes: Dictionary, full: bool) -> Dictionary:
	var result: Dictionary = {}
	for path: String in world_nodes:
		var node: Node = world_nodes[path]
		if not is_instance_valid(node) or not node.has_method("get_net_state_private"):
			continue
		var state: Dictionary = node.call("get_net_state_private")
		if not full:
			if _last.get(path) == state:
				continue
			_last[path] = state
		var audience: StringName = node.call("net_private_audience")
		if not result.has(audience):
			result[audience] = {}
		result[audience]["%s%s" % [path, SUFFIX]] = state
	return result


## Cambios privados que le tocan a un rol
static func for_role(collected: Dictionary, role: StringName) -> Dictionary:
	var result: Dictionary = {}
	for audience: StringName in collected:
		if audience_matches(audience, role):
			result.merge(collected[audience], true)
	return result


## Olvida una ruta que ya no existe
func forget(path: String) -> void:
	_last.erase(path)
