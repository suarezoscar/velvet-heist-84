## @file guard_round.gd
## La ronda de fichaje de un guardia (FEAT-034, interaction.md parte R). Hijo «Round» de cada
## guardia. RoundPlanner le da una ruta de relojes en orden y el tiempo de cada tramo; solo
## cuenta fichar en el siguiente de su ruta. Si se le pasa el tiempo, el tramo va con retraso:
## apunta faltas (una por cada tramo entero de retraso) y la campana de ese reloj suena, como
## los relojes vencidos de antes. Al acabar la ruta vuelve a empezar. Decide el servidor (o la
## partida sin red); los guardias reciben las rondas de todo el equipo.
class_name GuardRound
extends Node

const RULES: TimeClockRules = preload("res://data/balance/time_clock_rules.tres")

var guard: GuardController3D = null
## Ids de los relojes de la ruta, en orden
var route: Array[int] = []
## Segundos de cada tramo: legs[i] es el tiempo para llegar a route[i] desde el anterior
var legs: Array[float] = []
var index: int = 0
var time_left: float = 0.0
var faults: int = 0
## El tramo actual va con retraso
var late: bool = false
var _late_time: float = 0.0
var _episode_faults: int = 0
var _bell_timer: float = 0.0


static func attach(target: GuardController3D) -> GuardRound:
	var round_node: GuardRound = GuardRound.new()
	round_node.name = "Round"
	round_node.guard = target
	target.add_child(round_node)
	return round_node


static func of(target: Node) -> GuardRound:
	return target.get_node_or_null("Round") as GuardRound if target != null else null


func _ready() -> void:
	add_to_group(&"net_state")
	add_to_group(&"guard_round")
	if guard == null:
		guard = get_parent() as GuardController3D


## Id del siguiente reloj de la ruta (-1 sin ruta)
func next_clock() -> int:
	return route[index] if not route.is_empty() else -1


## Segundos del tramo actual
func leg_time() -> float:
	return legs[index] if index < legs.size() else RULES.round_duration


## Autoridad: ruta nueva, hoja limpia
func assign(new_route: Array[int], new_legs: Array[float]) -> void:
	route = new_route
	legs = new_legs
	index = 0
	faults = 0
	_start_leg()


func _physics_process(delta: float) -> void:
	if route.is_empty() or not GameManager.is_simulating():
		return
	if GameManager.current_state != GameManager.MatchState.IN_PROGRESS:
		return
	step(delta)


## Un tick de la cuenta atrás del tramo (lo usan los tests)
func step(delta: float) -> void:
	if late:
		_late_time += delta
		var due: int = 1 + int(floor(_late_time / leg_time()))
		if due > _episode_faults:
			faults += due - _episode_faults
			_episode_faults = due
		_bell_timer += delta
		if _bell_timer >= RULES.alarm_pulse_interval:
			_bell_timer = 0.0
			_ring_bell()
		return
	time_left -= delta
	if time_left <= 0.0:
		var overshoot: float = -time_left
		time_left = 0.0
		late = true
		_late_time = 0.0
		_episode_faults = 0
		print("[GuardRound] %s llega tarde al reloj %d" % [guard.name, next_clock()])
		step(overshoot)


## Autoridad: ha fichado en clock_id; true si era el siguiente de su ruta
func punch(clock_id: int) -> bool:
	if route.is_empty() or clock_id != next_clock():
		return false
	index = (index + 1) % route.size()
	_start_leg()
	return true


func _start_leg() -> void:
	time_left = leg_time()
	late = false
	_late_time = 0.0
	_episode_faults = 0
	_bell_timer = 0.0


func _ring_bell() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"time_clock"):
		var clock: TimeClock3D = node as TimeClock3D
		if clock.clock_id == next_clock():
			NoiseEmit.emit(
				clock.global_position,
				RULES.alarm_noise_radius,
				&"guard",
				NoiseEmit.MECHANISM,
				clock
			)


func get_net_state() -> Dictionary:
	return {}


## A los guardias: la ruta, por dónde va, el tiempo del tramo y las faltas
func get_net_state_private() -> Dictionary:
	return {
		"route": route.duplicate(),
		"legs": legs.duplicate(),
		"i": index,
		"left": snappedf(time_left, 0.1),
		"faults": faults,
		"late": late,
	}


func net_private_audience() -> StringName:
	return &"guard"


func apply_net_state(state: Dictionary) -> void:
	if state.has("route"):
		route.assign(state["route"])
	if state.has("legs"):
		legs.assign(state["legs"])
	index = int(state.get("i", index))
	time_left = float(state.get("left", time_left))
	faults = int(state.get("faults", faults))
	late = bool(state.get("late", late))
