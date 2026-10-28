## @file alert_director.gd
## Rastros y nivel de alerta (heist.md R6-R8). Hijo «Alert» del HeistDirector. El servidor (o
## la partida sin red) decide:
## - un pedestal vacío que ve un guardia (a RULES.trace_sight, sin muros) o una cámara mientras
##   alguien mira los monitores queda descubierto (TargetPiece3D.discovered);
## - la alerta sube y nunca baja: 1 rastro → sospecha; RULES.alarm_traces rastros, ver al
##   ladrón (un guardia o una cámara vigilada) o robar a lo bruto → alarma;
## - el walkie de los guardias deja marcas en su plano (estado privado de los guardias);
## - en alarma, las luces de alarma encienden las lámparas cercanas un rato.
class_name AlertDirector
extends Node

enum Level { CALM, SUSPICION, ALARM }

const RULES: HeistRules = preload("res://data/balance/heist_rules.tres")
const TICK: float = 0.2

var level: Level = Level.CALM
## Marcas del walkie: [{"pos": Vector3, "left": float}]
var pings: Array[Dictionary] = []
var flood_cooldown_left: float = 0.0
var _timer: float = 0.0
var _flood_left: float = 0.0
var _flooded: Dictionary = {}


func _ready() -> void:
	name = "Alert"
	add_to_group(&"net_state")
	add_to_group(&"heist_alert")


## La alerta del mapa (null si no hay golpe)
static func of(tree: SceneTree) -> AlertDirector:
	return tree.get_first_node_in_group(&"heist_alert") as AlertDirector


func _physics_process(delta: float) -> void:
	_age_pings(delta)
	if not GameManager.is_simulating():
		return
	flood_cooldown_left = maxf(0.0, flood_cooldown_left - delta)
	_tick_flood(delta)
	_timer -= delta
	if _timer > 0.0 or GameManager.current_state != GameManager.MatchState.IN_PROGRESS:
		return
	_timer = TICK
	scan()


## Busca rastros y avistamientos y sube la alerta
func scan() -> void:
	var guards: Array[GuardController3D] = _guards()
	var watching: bool = guards.any(
		func(g: GuardController3D) -> bool: return GuardSleep.sees_cameras(g)
	)
	for node: Node in get_tree().get_nodes_in_group(&"heist_targets"):
		var piece: TargetPiece3D = node as TargetPiece3D
		if piece.stolen and not piece.discovered and _trace_seen(piece, guards, watching):
			piece.discovered = true
			print("[AlertDirector] Rastro descubierto: %s" % piece.piece_name)
	var thief_seen: bool = guards.any(
		func(g: GuardController3D) -> bool: return g.is_perceiving_thief
	)
	if thief_seen or (watching and SecurityCamera3D.any_detects(self)):
		raise(Level.ALARM)
	var traces: int = discovered_count()
	if traces >= RULES.alarm_traces:
		raise(Level.ALARM)
	elif traces >= 1:
		raise(Level.SUSPICION)


func raise(new_level: Level) -> void:
	if new_level > level:
		level = new_level
		print("[AlertDirector] Alerta: %s" % Level.keys()[level])


func discovered_count() -> int:
	var count: int = 0
	for node: Node in get_tree().get_nodes_in_group(&"heist_targets"):
		count += 1 if (node as TargetPiece3D).discovered else 0
	return count


## Walkie: marca un punto para todo el equipo (lo llama HeistActions en el servidor)
func add_ping(pos: Vector3) -> void:
	pings.append({"pos": pos, "left": RULES.ping_time})


## Luces de alarma: enciende las lámparas a RULES.flood_radius de pos (false si no se puede)
func flood(pos: Vector3) -> bool:
	if level != Level.ALARM or flood_cooldown_left > 0.0:
		return false
	flood_cooldown_left = RULES.flood_cooldown
	for node: Node in get_tree().get_nodes_in_group(&"lamps"):
		var lamp: Lamp3D = node as Lamp3D
		if lamp != null and lamp.global_position.distance_to(pos) <= RULES.flood_radius:
			if not _flooded.has(lamp):
				_flooded[lamp] = lamp.is_switched_on
			lamp.set_switched(true)
	_flood_left = RULES.flood_time
	return true


func _tick_flood(delta: float) -> void:
	if _flood_left <= 0.0:
		return
	_flood_left -= delta
	if _flood_left > 0.0:
		return
	for lamp: Lamp3D in _flooded:
		if is_instance_valid(lamp):
			lamp.set_switched(bool(_flooded[lamp]))
	_flooded.clear()


func _age_pings(delta: float) -> void:
	for ping: Dictionary in pings:
		ping["left"] = float(ping["left"]) - delta
	pings = pings.filter(func(p: Dictionary) -> bool: return float(p["left"]) > 0.0)


func _trace_seen(piece: TargetPiece3D, guards: Array[GuardController3D], watching: bool) -> bool:
	var space: PhysicsDirectSpaceState3D = get_viewport().world_3d.direct_space_state
	var target: Vector3 = piece.global_position + Vector3.UP * 1.1
	for guard: GuardController3D in guards:
		if GuardSleep.sees_nothing(guard):
			continue
		var eye: Vector3 = VisionLogic.eye(guard)
		if (
			eye.distance_to(target) <= RULES.trace_sight
			and VisionLogic.wall_free(space, eye, target)
		):
			return true
	if watching:
		for node: Node in get_tree().get_nodes_in_group(&"security_camera"):
			if (node as SecurityCamera3D).sees(piece):
				return true
	return false


func _guards() -> Array[GuardController3D]:
	var guards: Array[GuardController3D] = []
	for node: Node in get_tree().get_nodes_in_group(&"guards"):
		guards.append(node as GuardController3D)
	return guards


## A todos: el nivel (el ladrón también lo ve, decisión 2)
func get_net_state() -> Dictionary:
	return {"level": int(level)}


## Solo a los guardias: las marcas del walkie
func get_net_state_private() -> Dictionary:
	var marks: Array = []
	for ping: Dictionary in pings:
		marks.append([ping["pos"], snappedf(float(ping["left"]), 0.5)])
	return {"pings": marks, "flood": ceilf(flood_cooldown_left)}


func net_private_audience() -> StringName:
	return &"guard"


func apply_net_state(state: Dictionary) -> void:
	if state.has("level"):
		level = int(state["level"]) as Level
	if state.has("pings"):
		pings.clear()
		for mark: Variant in state["pings"]:
			pings.append({"pos": mark[0] as Vector3, "left": float(mark[1])})
	if state.has("flood"):
		flood_cooldown_left = float(state["flood"])
