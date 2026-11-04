## @file guard_ai_3d.gd
## Componente de Inteligencia Artificial para guardias de seguridad en solitario / coop.
## Gestiona la máquina de estados: PATROL (salas a su aire, más las que tienen piezas; #116),
## COFFEE (a la cafetera cuando le entra sueño), INVESTIGATE (ruidos/CCTV), CHASE (persecución)
## y COVER (con la cuenta atrás de las rejas, cubre una salida; GuardExitCover, #120).
## Solo decide la intención (dirección, sprint, mirada); el movimiento lo simula
## GuardController3D igual que para un humano. Requiere un GuardController3D como padre.
class_name GuardAI3D
extends Node

enum AIState { IDLE, PATROL, INVESTIGATE, CHASE, COFFEE, COVER }

## Distancia horizontal (m) a la que un punto del camino se da por alcanzado
const WAYPOINT_REACHED_DISTANCE: float = 0.8
## Distancia horizontal (m) a la que el punto investigado se da por alcanzado
const INVESTIGATE_REACHED_DISTANCE: float = 0.9
## Segundos que el guardia inspecciona un ruido antes de volver a patrullar
const NOISE_INVESTIGATE_TIME: float = 5.0
## Segundos que inspecciona la última posición avistada del ladrón
const SPOTTED_INVESTIGATE_TIME: float = 6.0
## Distancia (m) al centro de la cafetera a la que se sirve: por debajo del alcance de la E
const COFFEE_REACH: float = 1.9
const PATROL_RULES: GuardPatrolRules = preload("res://data/balance/guard_patrol.tres")
## Atascado: menos de STUCK_SPEED m/s durante STUCK_TIME s patrullando
const STUCK_SPEED: float = 0.3
const STUCK_TIME: float = 1.5

@export var patrol_waypoints: Array[Vector3] = []
@export var is_ai_active: bool = true

var current_state: AIState = AIState.PATROL
var investigation_point: Vector3 = Vector3.ZERO
var target_room: String = ""
var cover_exit: ExitZone3D = null
var _cover_point: Vector3 = Vector3.ZERO
var _current_waypoint_idx: int = 0
var _investigate_timer: float = 0.0
var _stuck_time: float = 0.0
var _guard: GuardController3D = null
var _thief: ThiefController3D = null
var _nav_agent: NavigationAgent3D = null
var _recent_rooms: Array[String] = []
var _dwell_left: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


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
	_guard.apply_flashlight_state(true)  # la IA lleva la linterna siempre encendida (#112)

	if _thief != null and _guard.check_detection_on_thief(_thief):
		current_state = AIState.CHASE
	if current_state == AIState.PATROL and _wants_coffee():
		current_state = AIState.COFFEE  # perseguir e investigar mandan sobre el café
		_go_to(GuardPatrol.of(get_tree()), _coffee_machine().global_position)
	if current_state == AIState.PATROL or current_state == AIState.COFFEE:
		var point: Variant = (
			_cover_point if cover_exit != null else GuardExitCover.pick(self, _guard)
		)
		if point is Vector3:
			_cover_point = point
			current_state = AIState.COVER
			_go_to(GuardPatrol.of(get_tree()), _cover_point)
	if current_state == AIState.CHASE or current_state == AIState.IDLE:
		_stuck_time = 0.0

	match current_state:
		AIState.IDLE:
			_guard.apply_world_move(Vector3.ZERO)
		AIState.PATROL:
			_process_patrol()
		AIState.INVESTIGATE:
			_process_investigate(_delta)
		AIState.CHASE:
			_process_chase()
		AIState.COFFEE:
			_process_coffee()
		AIState.COVER:
			if _flat_distance(_cover_point, _guard.global_position) > WAYPOINT_REACHED_DISTANCE:
				_follow_path(_cover_point, true)  # con la alarma, corriendo
			else:
				GuardExitCover.watch(_guard, Time.get_ticks_msec() / 1000.0)


## Recorre el camino hasta la sala elegida, se queda ai_room_dwell s y elige otra
func _process_patrol() -> void:
	var delta: float = get_physics_process_delta_time()
	if _current_waypoint_idx >= patrol_waypoints.size():
		_guard.apply_world_move(Vector3.ZERO)
		_dwell_left -= delta
		if _dwell_left <= 0.0:
			_next_room()
		return
	var target: Vector3 = patrol_waypoints[_current_waypoint_idx]
	var stuck: bool = _update_stuck(delta)
	if stuck or _flat_distance(target, _guard.global_position) < WAYPOINT_REACHED_DISTANCE:
		_stuck_time = 0.0
		_current_waypoint_idx += 1
		_dwell_left = PATROL_RULES.ai_room_dwell
		return
	_steer_towards(target, false)


## Elige la siguiente sala (GuardPatrol) y el camino hasta su centro
func _next_room() -> void:
	var patrol: GuardPatrol = GuardPatrol.of(get_tree())
	if patrol == null:
		return
	var avoid: Array[String] = _recent_rooms.duplicate()
	for node: Node in get_tree().get_nodes_in_group(&"guards"):
		var other: GuardAI3D = node.get_node_or_null("GuardAI") as GuardAI3D
		if other != null and other != self and other.target_room != "":
			avoid.append(other.target_room)
	var room_id: String = patrol.pick_room(avoid, _rng)
	if room_id == "":
		return
	target_room = room_id
	_recent_rooms.push_front(room_id)
	_recent_rooms.resize(mini(_recent_rooms.size(), PATROL_RULES.ai_room_memory))
	_go_to(patrol, patrol.room_center(room_id))
	patrol_waypoints.append_array(patrol.piece_stops(room_id))  # pasa junto a cada candidata


func _go_to(patrol: GuardPatrol, target: Vector3) -> void:
	patrol_waypoints = (
		patrol.walk_between(_guard.global_position, target) if patrol != null else [target]
	)
	_current_waypoint_idx = 0
	_stuck_time = 0.0


## true si le ha entrado sueño (ai_coffee_at) y no se está sirviendo ya
func _wants_coffee() -> bool:
	var sleep: GuardSleep = _guard.get_node_or_null("Sleep") as GuardSleep
	return (
		sleep != null
		and sleep.drinking_left <= 0.0
		and sleep.level >= GuardSleep.RULES.ai_coffee_at
		and _coffee_machine() != null
	)


## Va a la cafetera, se sirve con la E y, despejado, vuelve a patrullar
func _process_coffee() -> void:
	var machine: CoffeeMachine3D = _coffee_machine()
	var sleep: GuardSleep = _guard.get_node_or_null("Sleep") as GuardSleep
	if machine == null or sleep == null:
		current_state = AIState.PATROL
		return
	if sleep.drinking_left > 0.0:
		_guard.apply_world_move(Vector3.ZERO)  # quieto mientras se sirve
		return
	if sleep.level < GuardSleep.RULES.ai_coffee_at:
		current_state = AIState.PATROL  # ya despejado: a otra sala
		_next_room()
		return
	if _flat_distance(machine.global_position, _guard.global_position) <= COFFEE_REACH:
		_guard.apply_world_move(Vector3.ZERO)
		_guard.look_target_position = machine.global_position
		if machine.can_interact(_guard):
			machine.interact(_guard)
		return
	_follow_path(machine.global_position)


## Sigue patrol_waypoints (por las puertas) y, acabado el camino, va directo a fallback
func _follow_path(fallback: Vector3, sprint: bool = false) -> void:
	if _current_waypoint_idx >= patrol_waypoints.size():
		_steer_towards(fallback, sprint)
		return
	var target: Vector3 = patrol_waypoints[_current_waypoint_idx]
	var stuck: bool = _update_stuck(get_physics_process_delta_time())
	if stuck or _flat_distance(target, _guard.global_position) < WAYPOINT_REACHED_DISTANCE:
		_stuck_time = 0.0
		_current_waypoint_idx += 1
		return
	_steer_towards(target, sprint)


func _coffee_machine() -> CoffeeMachine3D:
	return get_tree().get_first_node_in_group(&"coffee_machine") as CoffeeMachine3D


## true si lleva STUCK_TIME casi sin moverse yendo a un waypoint (un mueble en medio): pasa al
## siguiente para no quedarse atascado
func _update_stuck(delta: float) -> bool:
	var speed: float = Vector2(_guard.velocity.x, _guard.velocity.z).length()
	_stuck_time = _stuck_time + delta if speed < STUCK_SPEED else 0.0
	return _stuck_time >= STUCK_TIME


func _process_investigate(delta: float) -> void:
	var far: bool = (
		_flat_distance(investigation_point, _guard.global_position) > INVESTIGATE_REACHED_DISTANCE
	)
	if far and not _update_stuck(delta):  # tras un muro: se rinde en vez de empujar la pared
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
	if GuardSleep.sees_nothing(_guard):
		return  # dando una cabezada tampoco atiende ruidos (#116)
	if (
		PerceptionRules.horizontal_distance(_guard.global_position, pos)
		<= radius * _guard.perception.ai_hearing_factor
	):
		investigation_point = pos
		_investigate_timer = NOISE_INVESTIGATE_TIME
		current_state = AIState.INVESTIGATE
		_stuck_time = 0.0


## Aviso de una cámara: solo cuenta si este guardia está mirando los monitores (M7)
func _on_thief_spotted(pos: Vector3) -> void:
	if _guard == null or not _guard.is_watching_monitors():
		return
	if current_state != AIState.CHASE:
		investigation_point = pos
		_investigate_timer = SPOTTED_INVESTIGATE_TIME
		current_state = AIState.INVESTIGATE
		_stuck_time = 0.0


func _on_thief_perceived(_pos: Vector3) -> void:
	current_state = AIState.CHASE
