## Reglas puras de asignación de roles del PoC (FEAT-014) sobre el diccionario de
## jugadores de NetManager (`peer_id -> player_info`). Sin estado propio.
## Las funciones de NetManager con el mismo propósito delegan aquí.
class_name NetRoleRegistry
extends RefCounted


## Verdadero si el rol está en el catálogo del PoC y nadie lo ocupa
static func is_role_available(players: Dictionary, role: StringName) -> bool:
	if not NetConfig.ROLES.has(role):
		return false
	return peer_for_role(players, role) == 0


## Peer que ocupa el rol (0 si nadie lo ocupa)
static func peer_for_role(players: Dictionary, role: StringName) -> int:
	for peer_id: int in players:
		if players[peer_id].get("role", &"") == role:
			return peer_id
	return 0


## Rol del peer (&"" si no está registrado)
static func role_for_peer(players: Dictionary, peer_id: int) -> StringName:
	if not players.has(peer_id):
		return &""
	return players[peer_id].get("role", &"")


## Primer rol libre en el orden de NetConfig.ROLES (&"" si no queda ninguno)
static func next_available_role(players: Dictionary) -> StringName:
	for role: StringName in NetConfig.ROLES:
		if is_role_available(players, role):
			return role
	return &""


## Verdadero si hay ladrón y al menos un guardia: en red no hay guardias de IA (FEAT-022)
static func can_start(players: Dictionary) -> bool:
	return peer_for_role(players, &"thief") != 0 and guard_count(players) > 0


## Guardias ocupados por jugadores
static func guard_count(players: Dictionary) -> int:
	var count: int = 0
	for peer_id: int in players:
		if String(players[peer_id].get("role", &"")).begins_with("guard_"):
			count += 1
	return count


## Renumera los guardias ocupados para que queden seguidos (guard_1..guard_n) en su orden;
## así los n primeros guardias del mapa son los de los jugadores
static func compact_guards(players: Dictionary) -> void:
	var guards: Array[StringName] = []
	for role: StringName in NetConfig.ROLES:
		if String(role).begins_with("guard_") and peer_for_role(players, role) != 0:
			guards.append(role)
	var peers: Array[int] = []
	for role: StringName in guards:
		peers.append(peer_for_role(players, role))
	for index: int in range(peers.size()):
		players[peers[index]]["role"] = NetConfig.ROLES[index + 1]


## Asigna desired_role a peer_id si está en NetConfig.ROLES y libre (o ya es suyo)
static func try_assign(players: Dictionary, peer_id: int, desired_role: StringName) -> bool:
	if not NetConfig.ROLES.has(desired_role):
		print("[NetRoleRegistry] Rol invalido: %s" % desired_role)
		return false
	var current_peer: int = peer_for_role(players, desired_role)
	if current_peer != 0 and current_peer != peer_id:
		print("[NetRoleRegistry] Rol %s ya ocupado por peer %d" % [desired_role, current_peer])
		return false
	if not players.has(peer_id):
		return false
	players[peer_id]["role"] = desired_role
	return true
