## @file vent_travel.gd
## El ladrón dentro de la ventilación (FEAT-034, heist.md R10). Nodo «Vents», padre de las
## rejillas. Tras colarse por una (Vent3D), el ladrón elige la salida entre las rejillas de la
## misma red con izquierda y derecha y va con E; elegir la de entrada es volver a salir por ahí.
## El viaje dura la distancia en línea recta entre las dos rejillas a RULES.travel_speed, más
## lento con botín (HeistRules.loot_slow por pieza), y hace retumbar las rejillas de la red.
## Mientras está dentro, nadie lo ve ni lo toca (ThiefController3D.in_vent). Decide el servidor
## (o la partida sin red); solo el ladrón recibe su estado.
class_name VentTravel
extends Node

enum Phase { NONE, CHOOSING, TRAVELING }

const RULES: VentRules = preload("res://data/balance/vent_rules.tres")
const HEIST_RULES: HeistRules = preload("res://data/balance/heist_rules.tres")
## Umbral del eje horizontal para cambiar de salida (un cambio por pulsación)
const AXIS_THRESHOLD: float = 0.5

var phase: Phase = Phase.NONE
var thief: ThiefController3D = null
var entry: Vent3D = null
var choices: Array[Vent3D] = []
var selected: int = 0
## Segundos que quedan de viaje
var left: float = 0.0
var _last_axis: float = 0.0


static func of(tree: SceneTree) -> VentTravel:
	return tree.get_first_node_in_group(&"vent_travel") as VentTravel if tree != null else null


func _ready() -> void:
	name = "Vents"
	add_to_group(&"vent_travel")
	add_to_group(&"net_state")


func _physics_process(delta: float) -> void:
	if phase == Phase.NONE or not GameManager.is_simulating():
		return
	if not is_instance_valid(thief) or GameManager.is_match_over():
		_reset()
		return
	if phase == Phase.CHOOSING:
		var axis: float = thief.current_input_dir.x
		if absf(axis) > AXIS_THRESHOLD and absf(_last_axis) <= AXIS_THRESHOLD:
			selected = wrapi(selected + (1 if axis > 0.0 else -1), 0, choices.size())
		_last_axis = axis
	elif phase == Phase.TRAVELING:
		left -= delta
		if left <= 0.0:
			_arrive()


## Autoridad: el ladrón acaba de colarse por vent
func enter(who: ThiefController3D, vent: Vent3D) -> void:
	if who == null or phase != Phase.NONE:
		return
	thief = who
	entry = vent
	choices.clear()
	for node: Node in get_children():
		var other: Vent3D = node as Vent3D
		if other != null and other.network == vent.network:
			choices.append(other)
	selected = wrapi(choices.find(vent) + 1, 0, choices.size())
	_last_axis = thief.current_input_dir.x
	thief.in_vent = true
	vent.mark_open()
	phase = Phase.CHOOSING


## Autoridad: va hacia la salida elegida (si es la de entrada, sale ya)
func go() -> void:
	if phase != Phase.CHOOSING:
		return
	var target: Vent3D = choices[selected]
	if target == entry:
		_arrive()
		return
	var distance: float = entry.global_position.distance_to(target.global_position)
	var pieces: int = GameManager.heist.stolen.size() if GameManager.heist != null else 0
	left = distance / RULES.travel_speed * (1.0 + HEIST_RULES.loot_slow * pieces)
	phase = Phase.TRAVELING
	for vent: Vent3D in choices:
		if vent != entry:
			NoiseEmit.emit(
				vent.global_position, RULES.rumble_radius, &"thief", NoiseEmit.MECHANISM, null
			)


## Texto de la rejilla mientras elige: la sala de la salida elegida
func choice_text() -> String:
	if choices.is_empty():
		return ""
	var target: Vent3D = choices[selected]
	var where: String = "volver a salir aquí" if target == entry else target.room_name
	return "Conducto: ◀ %s ▶ · ir [E]" % where


func _arrive() -> void:
	var target: Vent3D = choices[selected]
	thief.global_position = target.exit_point() + Vector3.UP * 0.1
	thief.velocity = Vector3.ZERO
	thief.in_vent = false
	target.mark_open()
	NoiseEmit.emit(target.global_position, RULES.hatch_radius, &"thief", NoiseEmit.MECHANISM, thief)
	print("[VentTravel] El ladrón sale por %s" % target.vent_id)
	_reset()


func _reset() -> void:
	if is_instance_valid(thief):
		thief.in_vent = false
	phase = Phase.NONE
	thief = null
	entry = null
	choices.clear()


func get_net_state() -> Dictionary:
	return {}


## Solo al ladrón: si va por dentro, por qué rejilla entró, las salidas y la elegida
func get_net_state_private() -> Dictionary:
	var ids: Array[String] = []
	for vent: Vent3D in choices:
		ids.append(vent.vent_id)
	return {
		"phase": int(phase),
		"entry": entry.vent_id if entry != null else "",
		"choices": ids,
		"sel": selected,
	}


func net_private_audience() -> StringName:
	return &"thief"


func apply_net_state(state: Dictionary) -> void:
	if not state.has("phase"):
		return
	phase = int(state["phase"]) as Phase
	selected = int(state.get("sel", 0))
	choices.clear()
	entry = null
	for id: Variant in state.get("choices", []):
		var vent: Vent3D = get_node_or_null("Vent_%s" % id) as Vent3D
		if vent != null:
			choices.append(vent)
	entry = get_node_or_null("Vent_%s" % state.get("entry", "")) as Vent3D
	var local_thief: ThiefController3D = (
		get_tree().get_first_node_in_group(&"thief") as ThiefController3D
	)
	if local_thief != null:
		local_thief.in_vent = phase != Phase.NONE
