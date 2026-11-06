## @file match_countdown.gd
## El arranque de la partida (#165): con red, todos quietos con «CARGANDO EL MUSEO…» hasta que
## cada jugador ha cargado el mapa; después, para todos a la vez, 3-2-1 «¡YA!» y a jugar. Sin
## red, el 3-2-1 empieza al cerrar la tarjeta del rol (RoleBriefing84). Mientras está frozen()
## nadie se mueve y el reloj de la partida no corre. Lo decide el servidor (o la partida sin
## red) y lo reciben todos (grupo net_state); MatchCountdown84 lo enseña.
class_name MatchCountdown
extends Node

enum Phase { WAITING, COUNTING, GO }

## Segundos del 3-2-1
const COUNT_TIME: float = 3.0

var phase: Phase = Phase.WAITING
var left: float = COUNT_TIME
## Peers que ya han cargado el mapa (con red; lo enseña la pantalla de carga)
var loaded: Array[int] = []
var _session: NetSession = null


static func of(tree: SceneTree) -> MatchCountdown:
	return tree.get_first_node_in_group(&"match_countdown") as MatchCountdown if tree else null


## true mientras nadie se puede mover: con red, cargando o en el 3-2-1; sin red, en el 3-2-1
static func frozen(tree: SceneTree) -> bool:
	var countdown: MatchCountdown = of(tree)
	if countdown == null or countdown.phase == Phase.GO:
		return false
	return countdown.phase == Phase.COUNTING or NetManager.is_online()


## Sin red: se cierra la tarjeta del rol y empieza el 3-2-1
static func begin(tree: SceneTree) -> void:
	var countdown: MatchCountdown = of(tree)
	if countdown != null and countdown.phase == Phase.WAITING and not NetManager.is_online():
		countdown.phase = Phase.COUNTING


func _ready() -> void:
	name = "MatchCountdown"
	add_to_group(&"match_countdown")
	add_to_group(&"net_state")


func _physics_process(delta: float) -> void:
	if not GameManager.is_simulating():
		return
	if phase == Phase.WAITING and NetManager.is_online():
		_check_loaded()
	elif phase == Phase.COUNTING:
		left -= delta
		if left <= 0.0:
			left = 0.0
			phase = Phase.GO


## Servidor: ¿han cargado ya todos los jugadores con bando?
func _check_loaded() -> void:
	if _session == null:
		var found: Array[Node] = get_tree().root.find_children(
			"NetSession", "NetSession", true, false
		)
		_session = found[0] as NetSession if not found.is_empty() else null
	if _session == null:
		return
	var session: NetSession = _session
	loaded.assign(session.ready_peers())
	var players: Dictionary = NetManager.get_connected_players()
	for peer: int in players:
		if NetRoleRegistry.role_for_peer(players, peer) != &"" and not loaded.has(peer):
			return
	phase = Phase.COUNTING


func get_net_state() -> Dictionary:
	return {"phase": int(phase), "left": snappedf(left, 0.1), "loaded": loaded.duplicate()}


func apply_net_state(state: Dictionary) -> void:
	phase = int(state.get("phase", phase)) as Phase
	left = float(state.get("left", left))
	loaded.assign(state.get("loaded", loaded))
