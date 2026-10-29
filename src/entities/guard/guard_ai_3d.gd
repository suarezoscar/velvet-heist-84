## @file guard_ai_3d.gd
## Componente de Inteligencia Artificial para guardias de seguridad en solitario / coop.
## Gestiona la máquina de estados: PATROL (ronda), INVESTIGATE (ruidos/CCTV) y CHASE (persecución).
## Solo decide la intención (dirección, sprint, mirada); el movimiento lo simula
## GuardController3D igual que para un humano. Requiere un GuardController3D como padre.
class_name GuardAI3D
extends Node

enum AIState { IDLE, PATROL, INVESTIGATE, CHASE }

## Distancia horizontal (m) a la que un waypoint de ronda se da por alcanzado
const WAYPOINT_REACHED_DISTANCE: float = 0.8
## Distancia horizontal (m) a la que el punto investigado se da por alcanzado
const INVESTIGATE_REACHED_DISTANCE: float = 0.9
## Segundos que el guardia inspecciona un ruido antes de volver a la ronda
const NOISE_INVESTIGATE_TIME: float = 5.0
## Segundos que inspecciona la última posición avistada del ladrón
const SPOTTED_INVESTIGATE_TIME: float = 6.0
## Distancia horizontal (m) a la que ficha un reloj de ronda al pasar (alcance del interactor)
const CLOCK_PUNCH_DISTANCE: float = 1.6
## Atascado: menos de STUCK_SPEED m/s durante STUCK_TIME s patrullando
const STUCK_SPEED: float = 0.3
const STUCK_TIME: float = 1.5

## Rutas de patrulla configurables
@export var patrol_waypoints: Array[Vector3] = []
## Al acabar los waypoints vuelve a este (FEAT-034: de la garita a la ronda, y luego en bucle)
@export var patrol_loop_start: int = 0
@export var is_ai_active: bool = true

var current_state: AIState = AIState.PATROL
var investigation_point: Vector3 = Vector3.ZERO
var _current_waypoint_idx: int = 0
var _investigate_timer: float = 0.0
var _stuck_time: float = 0.0
var _guard: GuardController3D = null
var _thief: ThiefController3D = null
var _nav_agent: NavigationAgent3D = null


func _ready() -> void:
	# Decidir antes de que el guardia simule en este mismo tick
	process_physics_priority = -1
	_guard = get_parent() as GuardController3D
	_nav_agent = get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	if _nav_agent != null:
		_nav_agent.path_desired_distance = 0.6
		_nav_agent.target_desired_distance = 0.8
		_nav_agent.radius = 0.4
	SignalBus.noise_emitted_3d.connect(_on_noise_emitted)
	SignalBus.thief_spotted.connect(_on_thief_spotted)
	if _guard != null and _guard.has_signal("thief_perceived"):
		_guard.thief_perceived.connect(_on_thief_perceived)
	_find_thief.call_deferred()


func _find_thief() -> void:
	_thief = get_tree().get_first_node_in_group("thief") as ThiefController3D
	if _thief == null and _guard != null and _guard.get_parent() != null:
		for sibling: Node in _guard.get_parent().get_children():
			if sibling is ThiefController3D:
				_thief = sibling
				break


## La IA solo decide si el guardia es de IA y esta máquina simula el mundo
## (sin red, o en el servidor).
func is_driving() -> bool:
	if not is_ai_active or _guard == null or not _guard.is_ai_controlled:
		return false
	if _guard.is_locally_controlled:
		return false
	return not NetManager.is_online() or multiplayer.is_server()


func _physics_process(_delta: float) -> void:
	if not is_driving():
		return

	if _thief != null and _guard.check_detection_on_thief(_thief):
		current_state = AIState.CHASE
	_punch_nearby_clocks()

	match current_state:
		AIState.IDLE:
			_guard.apply_world_move(Vector3.ZERO)
		AIState.PATROL:
			_process_patrol()
		AIState.INVESTIGATE:
			_process_investigate(_delta)
		AIState.CHASE:
			_process_chase()


## Ficha el siguiente reloj de su ronda cuando lo tiene al alcance (FEAT-034: GuardRound)
func _punch_nearby_clocks() -> void:
	var round_node: GuardRound = GuardRound.of(_guard)
	if round_node == null:
		return
	for node: Node in get_tree().get_nodes_in_group(&"time_clock"):
		var clock: TimeClock3D = node as TimeClock3D
		if clock == null or clock.clock_id != round_node.next_clock():
			continue
		if _flat_distance(clock.global_position, _guard.global_position) < CLOCK_PUNCH_DISTANCE:
			clock.interact(_guard)


func _process_patrol() -> void:
	if patrol_waypoints.is_empty():
		_guard.apply_world_move(Vector3.ZERO)
		return
	var target: Vector3 = patrol_waypoints[_current_waypoint_idx]
	var stuck: bool = _update_stuck(get_physics_process_delta_time())
	if stuck or _flat_distance(target, _guard.global_position) < WAYPOINT_REACHED_DISTANCE:
		_stuck_time = 0.0
		_current_waypoint_idx += 1
		if _current_waypoint_idx >= patrol_waypoints.size():
			_current_waypoint_idx = clampi(patrol_loop_start, 0, patrol_waypoints.size() - 1)
		return
	_steer_towards(target, false)


## true si lleva STUCK_TIME casi sin moverse yendo a un waypoint (un mueble en medio): pasa al
## siguiente para no quedarse atascado
func _update_stuck(delta: float) -> bool:
	var speed: float = Vector2(_guard.velocity.x, _guard.velocity.z).length()
	_stuck_time = _stuck_time + delta if speed < STUCK_SPEED else 0.0
	return _stuck_time >= STUCK_TIME


func _process_investigate(delta: float) -> void:
	if _flat_distance(investigation_point, _guard.global_position) > INVESTIGATE_REACHED_DISTANCE:
		_steer_towards(investigation_point, false)
		return
	_guard.apply_world_move(Vector3.ZERO)
	_investigate_timer -= delta
	if _investigate_timer <= 0.0:
		current_state = AIState.PATROL


func _process_chase() -> void:
	if _thief == null:
		current_state = AIState.PATROL
		return
	if (
		_flat_distance(_thief.global_position, _guard.global_position)
		<= _guard.perception.melee_range
	):
		_guard.apply_world_move(Vector3.ZERO)
		_guard.look_target_position = _thief.global_position
		_guard.swing_baton(_thief)
		return
	_steer_towards(_thief.global_position, true)


## Calcula el siguiente punto (navmesh si existe) y fija dirección y mirada del guardia.
func _steer_towards(target: Vector3, sprint: bool) -> void:
	var steer_point: Vector3 = target
	if _nav_agent != null:
		_nav_agent.target_position = target
		if not _nav_agent.is_target_reached():
			steer_point = _nav_agent.get_next_path_position()
	var to_point: Vector3 = (steer_point - _guard.global_position).slide(Vector3.UP)
	_guard.apply_world_move(to_point.normalized(), sprint)
	_guard.look_target_position = target


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _on_noise_emitted(pos: Vector3, radius: float, source_team: StringName) -> void:
	if source_team != &"thief" or _guard == null or radius <= 0.0:
		return
	if (
		PerceptionRules.horizontal_distance(_guard.global_position, pos)
		<= radius * _guard.perception.ai_hearing_factor
	):
		investigation_point = pos
		_investigate_timer = NOISE_INVESTIGATE_TIME
		current_state = AIState.INVESTIGATE


## Aviso de una cámara: solo cuenta si este guardia está mirando los monitores (M7)
func _on_thief_spotted(pos: Vector3) -> void:
	if _guard == null or not _guard.is_watching_monitors():
		return
	if current_state != AIState.CHASE:
		investigation_point = pos
		_investigate_timer = SPOTTED_INVESTIGATE_TIME
		current_state = AIState.INVESTIGATE


func _on_thief_perceived(_pos: Vector3) -> void:
	current_state = AIState.CHASE
