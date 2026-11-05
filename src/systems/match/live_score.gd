## @file live_score.gd
## Puntuación en vivo de un jugador (#123, heist.md R11): su total sin lo oculto y los avisos
## breves al puntuar («+25 VISTO»). Hay una por rol (NetConfig.ROLES), hija de MatchRecorder,
## que la actualiza en el servidor (o sin red); con red solo la recibe su jugador (estado
## privado de su audiencia). Nunca la del rival ni la de los compañeros.
class_name LiveScore
extends Node

## Avisos que se recuerdan (los más antiguos se olvidan): acota el estado replicado
const MAX_NOTES: int = 4

var role: StringName = &""
var total: int = 0
## [[id, texto]]: id crece con cada aviso, para que el HUD sepa cuáles son nuevos
var notes: Array = []
var _next_id: int = 1
## {etiqueta: puntos} de la última actualización
var _last: Dictionary = {}


static func create(for_role: StringName) -> LiveScore:
	var live: LiveScore = LiveScore.new()
	live.role = for_role
	live.name = "LiveScore_%s" % for_role
	return live


## La del rol for_role (null si no hay)
static func of(tree: SceneTree, for_role: StringName) -> LiveScore:
	for node: Node in tree.get_nodes_in_group(&"live_scores"):
		if (node as LiveScore).role == for_role:
			return node as LiveScore
	return null


## Rol de un guardia: el orden en map.guards, como GuardSleep y NetSession
static func guard_role(guard: GuardController3D) -> StringName:
	var map: HeistMap3D = guard.get_parent() as HeistMap3D if guard != null else null
	var index: int = map.guards.find(guard) if map != null else -1
	if index < 0 or index + 1 >= NetConfig.ROLES.size():
		return &""
	return NetConfig.ROLES[index + 1]


## Rol del jugador local (&"" si no juega)
static func local_role(map: HeistMap3D) -> StringName:
	if map == null or map.local_player == null:
		return &""
	if map.local_player == map.thief:
		return NetConfig.ROLES[0]
	return guard_role(map.local_player as GuardController3D)


func _ready() -> void:
	add_to_group(&"net_state")
	add_to_group(&"live_scores")


## Autoridad: nuevo desglose en vivo (MatchScore.live); un aviso por cada línea que cambia
func update(live: Dictionary) -> void:
	var lines: Dictionary = live.get("lines", {})
	for label: String in lines:
		var points: int = int(lines[label][0])
		var change: int = points - int(_last.get(label, 0))
		var note: String = String(lines[label][1])
		if change != 0 and not note.is_empty():
			notes.append([_next_id, "%s%d %s" % ["+" if change > 0 else "−", absi(change), note]])
			_next_id += 1
		_last[label] = points
	while notes.size() > MAX_NOTES:
		notes.pop_front()
	total = int(live.get("total", 0))


func get_net_state() -> Dictionary:
	return {}


func get_net_state_private() -> Dictionary:
	return {"total": total, "notes": notes.duplicate(true)}


func net_private_audience() -> StringName:
	return role


func apply_net_state(state: Dictionary) -> void:
	if state.has("total"):
		total = int(state["total"])
	if state.has("notes"):
		notes = (state["notes"] as Array).duplicate(true)
