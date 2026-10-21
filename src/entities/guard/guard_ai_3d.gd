## @file guard_ai_3d.gd
## Componente de Inteligencia Artificial para guardias de seguridad en solitario / coop.
## Gestiona la máquina de estados: PATROL (ronda), INVESTIGATE (ruidos/CCTV) y CHASE (persecución).
class_name GuardAI3D
extends Node

enum AIState { IDLE, PATROL, INVESTIGATE, CHASE }

## Rutas de patrulla configurables
@export var patrol_waypoints: Array[Vector3] = []
@export var is_ai_active: bool = true

var current_state: AIState = AIState.PATROL
var investigation_point: Vector3 = Vector3.ZERO
var _current_waypoint_idx: int = 0
var _investigate_timer: float = 0.0
var _guard: GuardController3D = null
var _thief: ThiefController3D = null
var _nav_agent: NavigationAgent3D = null

func _ready() -> void:
	_guard = get_parent() as GuardController3D
	_nav_agent = get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	if _nav_agent != null:
		_nav_agent.path_desired_distance = 0.6
		_nav_agent.target_desired_distance = 0.8
		_nav_agent.radius = 0.4
	_subscribe_signals()
	call_deferred("_find_thief")

func _subscribe_signals() -> void:
	var bus: Node = get_node_or_null("/root/SignalBus")
	if bus != null:
		if bus.has_signal("noise_emitted_3d"):
			bus.connect("noise_emitted_3d", _on_noise_emitted)
		if bus.has_signal("thief_spotted"):
			bus.connect("thief_spotted", _on_thief_spotted)

func _find_thief() -> void:
	var t = get_tree().get_first_node_in_group("thief")
	if t is ThiefController3D:
		_thief = t

func _physics_process(delta: float) -> void:
	if not is_ai_active or _guard == null:
		return

	# Chequeo prioritario de percepción visual directa
	if _thief != null and _guard.check_detection_on_thief(_thief):
		current_state = AIState.CHASE

	match current_state:
		AIState.IDLE:
			_guard.velocity = Vector3.ZERO
		AIState.PATROL:
			_process_patrol(delta)
		AIState.INVESTIGATE:
			_process_investigate(delta)
		AIState.CHASE:
			_process_chase(delta)

	_guard.move_and_slide()

func _process_patrol(delta: float) -> void:
	if patrol_waypoints.is_empty():
		return
	
	var target: Vector3 = patrol_waypoints[_current_waypoint_idx]
	var steer_target: Vector3 = target

	if _nav_agent != null:
		_nav_agent.target_position = target
		if not _nav_agent.is_target_reached():
			steer_target = _nav_agent.get_next_path_position()

	var to_target: Vector3 = steer_target - _guard.global_position
	to_target.y = 0.0
	
	if target.distance_to(_guard.global_position) < 0.8:
		_current_waypoint_idx = (_current_waypoint_idx + 1) % patrol_waypoints.size()
		return
	
	var move_dir: Vector3 = to_target.normalized()
	_guard.velocity.x = move_dir.x * _guard.move_speed
	_guard.velocity.z = move_dir.z * _guard.move_speed
	_guard.look_target_position = target
	_guard.rotation.y = lerp_angle(_guard.rotation.y, atan2(-move_dir.x, -move_dir.z), 6.0 * delta)

func _process_investigate(delta: float) -> void:
	var steer_point: Vector3 = investigation_point
	if _nav_agent != null:
		_nav_agent.target_position = investigation_point
		if not _nav_agent.is_target_reached():
			steer_point = _nav_agent.get_next_path_position()

	var to_point: Vector3 = steer_point - _guard.global_position
	to_point.y = 0.0
	
	if investigation_point.distance_to(_guard.global_position) > 0.9:
		var dir: Vector3 = to_point.normalized()
		_guard.velocity.x = dir.x * _guard.move_speed
		_guard.velocity.z = dir.z * _guard.move_speed
		_guard.look_target_position = investigation_point
		_guard.rotation.y = lerp_angle(_guard.rotation.y, atan2(-dir.x, -dir.z), 7.0 * delta)
	else:
		_guard.velocity = Vector3.ZERO
		_investigate_timer -= delta
		if _investigate_timer <= 0.0:
			current_state = AIState.PATROL

func _process_chase(delta: float) -> void:
	if _thief == null:
		current_state = AIState.PATROL
		return
	
	var to_thief: Vector3 = _thief.global_position - _guard.global_position
	to_thief.y = 0.0
	var dist: float = to_thief.length()
	
	if dist <= _guard.melee_range:
		_guard.swing_baton(_thief)
		_guard.velocity = Vector3.ZERO
		return
	
	# Sprint hacia el ladrón
	var chase_dir: Vector3 = to_thief.normalized()
	_guard.velocity.x = chase_dir.x * _guard.sprint_speed
	_guard.velocity.z = chase_dir.z * _guard.sprint_speed
	_guard.look_target_position = _thief.global_position
	_guard.rotation.y = lerp_angle(_guard.rotation.y, atan2(-chase_dir.x, -chase_dir.z), 10.0 * delta)

func _on_noise_emitted(pos: Vector3, radius: float, source_team: StringName) -> void:
	if source_team == &"thief" and _guard != null:
		if _guard.global_position.distance_to(pos) <= radius * 1.5:
			investigation_point = pos
			_investigate_timer = 5.0
			current_state = AIState.INVESTIGATE

func _on_thief_spotted(pos: Vector3) -> void:
	if _guard != null and current_state != AIState.CHASE:
		investigation_point = pos
		_investigate_timer = 6.0
		current_state = AIState.INVESTIGATE
