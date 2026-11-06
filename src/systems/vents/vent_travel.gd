## @file vent_travel.gd
## El viaje del ladrón por la ventilación (FEAT-034; heist.md R10 reescrita con #167). Nodo
## «Vents», padre de las rejillas. Decide el servidor (o la partida sin red); solo el ladrón
## recibe su estado.
## - CHOOSING: E en una rejilla abre el plano (VentPanel84) delante de ella. El ladrón se queda
##   quieto, a la vista y atrapable; ← → (o A D, o el ratón) eligen la salida, E confirma y
##   Esc, W o S (o un golpe) cierran el plano sin entrar. No se ofrece la rejilla de entrada.
## - ENTERING: tras confirmar se cuela (Vent3D, RULES.enter_time, con el ruido de la rejilla).
## - TRAVELING: dentro, nadie lo ve ni lo toca. Dura la distancia en línea recta entre las dos
##   rejillas a RULES.travel_speed, más lento con botín, y como mucho RULES.max_travel_time.
##   La cámara se desliza de una rejilla a otra (focus) y sale al llegar. No se puede esperar
##   dentro ni darse la vuelta.
class_name VentTravel
extends Node

enum Phase { NONE, CHOOSING, TRAVELING, ENTERING }

const RULES: VentRules = preload("res://data/balance/vent_rules.tres")
const HEIST_RULES: HeistRules = preload("res://data/balance/heist_rules.tres")
## Acciones del plano (NetConfig.ACTIONS); Esc, W y S llegan como dial_cancel
const PREV: StringName = &"vent_prev"
const NEXT: StringName = &"vent_next"

var phase: Phase = Phase.NONE
var thief: ThiefController3D = null
var entry: Vent3D = null
## Salidas posibles (sin la de entrada), de oeste a este
var choices: Array[Vent3D] = []
var selected: int = 0
## Segundos que quedan de viaje y lo que dura entero (para la cámara)
var left: float = 0.0
var total: float = 0.0
var _hits: int = 0


static func of(tree: SceneTree) -> VentTravel:
	return tree.get_first_node_in_group(&"vent_travel") as VentTravel if tree != null else null


## true si el ladrón tiene el plano abierto
static func is_choosing(tree: SceneTree) -> bool:
	var travel: VentTravel = of(tree)
	return travel != null and travel.phase == Phase.CHOOSING


## true si who está quieto ante la rejilla: con el plano abierto o colándose
static func holds(who: Node3D) -> bool:
	var travel: VentTravel = of(who.get_tree()) if who != null and who.is_inside_tree() else null
	return (
		travel != null and travel.thief == who and travel.phase in [Phase.CHOOSING, Phase.ENTERING]
	)


## Dónde mira la cámara que sigue a actor: durante el viaje, de la rejilla de entrada a la de
## salida; si no, el propio actor
static func focus(tree: SceneTree, actor: Node3D) -> Vector3:
	var travel: VentTravel = of(tree)
	if travel == null or travel.phase != Phase.TRAVELING or not (actor is ThiefController3D):
		return actor.global_position
	if travel.entry == null or travel.choices.is_empty() or travel.total <= 0.0:
		return actor.global_position
	var weight: float = clampf(1.0 - travel.left / travel.total, 0.0, 1.0)
	return travel.entry.exit_point().lerp(travel.target().exit_point(), weight)


## Segundos de viaje de from a to con pieces piezas del encargo (R10, #167)
static func travel_time(from: Vector3, to: Vector3, pieces: int) -> float:
	var slow: float = 1.0 + HEIST_RULES.loot_slow * pieces
	return minf(from.distance_to(to) / RULES.travel_speed * slow, RULES.max_travel_time)


func _ready() -> void:
	name = "Vents"
	add_to_group(&"vent_travel")
	add_to_group(&"net_state")


func _process(delta: float) -> void:
	if phase == Phase.TRAVELING and not GameManager.is_simulating():
		left = maxf(0.0, left - delta)  # el cliente adelanta la cámara entre estados
	if phase == Phase.CHOOSING and not NetManager.is_online():
		var local: ThiefController3D = (
			thief if thief != null and thief.is_locally_controlled else null
		)
		if local != null:
			for action: StringName in VentInput.poll(get_tree()):
				handle(local, action)


func _physics_process(delta: float) -> void:
	if phase == Phase.NONE or not GameManager.is_simulating():
		return
	if not is_instance_valid(thief) or GameManager.is_match_over():
		_reset()
		return
	if phase in [Phase.CHOOSING, Phase.ENTERING] and thief.baton_hits_taken != _hits:
		cancel()  # un golpe cierra el plano (o le impide colarse) y le devuelve el control
	elif phase == Phase.TRAVELING:
		left -= delta
		if left <= 0.0:
			_arrive()


## Autoridad: E en vent abre el plano de su red
func open(who: ThiefController3D, vent: Vent3D) -> void:
	if who == null or phase != Phase.NONE:
		return
	choices.clear()
	for node: Node in get_children():
		var other: Vent3D = node as Vent3D
		if other != null and other != vent and other.network == vent.network:
			choices.append(other)
	if choices.is_empty():
		return
	choices.sort_custom(
		func(a: Vent3D, b: Vent3D) -> bool: return a.global_position.x < b.global_position.x
	)
	thief = who
	entry = vent
	_hits = who.baton_hits_taken
	selected = 0
	for i: int in range(choices.size()):
		if seconds_to(i) < seconds_to(selected):
			selected = i  # al abrirse, la de viaje más corto
	phase = Phase.CHOOSING


## Autoridad: una acción del ladrón con el plano abierto; true si era para el plano
func handle(who: ThiefController3D, action: StringName) -> bool:
	if phase == Phase.ENTERING and who == thief:
		return true  # colándose, la E y la Q no van a lo que tenga al lado
	if phase != Phase.CHOOSING or who != thief:
		return false
	match action:
		PREV:
			selected = wrapi(selected - 1, 0, choices.size())
		NEXT:
			selected = wrapi(selected + 1, 0, choices.size())
		&"interact":
			phase = Phase.ENTERING
			entry.start_entering(thief)
		&"dial_cancel":
			cancel()
		_:
			return false
	return true


func cancel() -> void:
	if phase == Phase.CHOOSING or phase == Phase.ENTERING:
		_reset()


## Autoridad: ya está dentro (Vent3D tras enter_time): viaja hacia la elegida
func enter() -> void:
	if phase != Phase.ENTERING:
		return
	thief.in_vent = true
	entry.mark_open()
	total = seconds_to(selected)
	left = total
	phase = Phase.TRAVELING
	for node: Node in get_children():
		var vent: Vent3D = node as Vent3D
		if vent != null and vent != entry and vent.network == entry.network:
			NoiseEmit.emit(
				vent.global_position, RULES.rumble_radius, &"thief", NoiseEmit.MECHANISM, null
			)


func target() -> Vent3D:
	return choices[clampi(selected, 0, choices.size() - 1)]


## Segundos de viaje hasta la salida index, con el botín que lleva ahora
func seconds_to(index: int) -> float:
	var pieces: int = GameManager.heist.stolen.size() if GameManager.heist != null else 0
	return travel_time(entry.global_position, choices[index].global_position, pieces)


## Lo que enseña el plano: {"from": sala de entrada, "options": [[sala, s]], "sel": int}
func view() -> Dictionary:
	var options: Array = []
	for i: int in range(choices.size()):
		options.append([choices[i].room_name, ceili(seconds_to(i))])
	return {"from": entry.room_name if entry != null else "", "options": options, "sel": selected}


func _arrive() -> void:
	var exit: Vent3D = target()
	thief.global_position = exit.exit_point() + Vector3.UP * 0.1
	thief.velocity = Vector3.ZERO
	thief.in_vent = false
	exit.mark_open()
	NoiseEmit.emit(exit.global_position, RULES.hatch_radius, &"thief", NoiseEmit.MECHANISM, thief)
	print("[VentTravel] El ladrón sale por %s" % exit.vent_id)
	_reset()


func _reset() -> void:
	if is_instance_valid(thief):
		thief.in_vent = false
	if entry != null:
		entry.stop_entering()
	phase = Phase.NONE
	thief = null
	entry = null
	choices.clear()


func get_net_state() -> Dictionary:
	return {}


## Solo al ladrón: fase, rejilla de entrada, salidas, la elegida y el viaje
func get_net_state_private() -> Dictionary:
	var ids: Array[String] = []
	for vent: Vent3D in choices:
		ids.append(vent.vent_id)
	return {
		"phase": int(phase),
		"entry": entry.vent_id if entry != null else "",
		"choices": ids,
		"sel": selected,
		"left": snappedf(left, 0.1),
		"total": snappedf(total, 0.1),
	}


func net_private_audience() -> StringName:
	return &"thief"


func apply_net_state(state: Dictionary) -> void:
	if not state.has("phase"):
		return
	phase = int(state["phase"]) as Phase
	selected = int(state.get("sel", 0))
	left = float(state.get("left", left))
	total = float(state.get("total", total))
	choices.clear()
	for id: Variant in state.get("choices", []):
		var vent: Vent3D = get_node_or_null("Vent_%s" % id) as Vent3D
		if vent != null:
			choices.append(vent)
	entry = get_node_or_null("Vent_%s" % state.get("entry", "")) as Vent3D
	var local_thief: ThiefController3D = (
		get_tree().get_first_node_in_group(&"thief") as ThiefController3D
	)
	if local_thief != null:
		local_thief.in_vent = phase == Phase.TRAVELING
	thief = local_thief if phase != Phase.NONE else null
