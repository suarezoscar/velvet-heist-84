## Clase base para personajes 3D (Ladrón y Guardia) en perspectiva isométrica.
## Desacopla Input, Simulación y Presentación para dar soporte a servidor
## autoritativo dedicado headless, predicción local y modos de movimiento (FEAT-007).
class_name PlayerBase3D
extends CharacterBody3D

signal crouch_changed(is_crouching: bool)
signal stand_up_blocked

const GRAVITY: float = 19.6
const DEFAULT_STEP_NOISE_PATH: String = "res://data/balance/step_noise.tres"
const FACE_MOVEMENT_MIN_SPEED: float = 0.5

@export var movement_profile: MovementProfile
@export var step_noise: StepNoiseProfile
@export var team_id: StringName = &"neutral"
@export var camera: Camera3D

var is_locally_controlled: bool = false:
	set(value):
		is_locally_controlled = value
		if not value:
			_clear_input()

var is_crouching: bool = false
var collision_shape: CollisionShape3D = null
var current_speed: float = 4.5
var is_sprinting: bool = false
var is_sneaking: bool = false
var look_target_position: Vector3 = Vector3.ZERO
var net_target_position: Vector3 = Vector3.ZERO
var net_target_velocity: Vector3 = Vector3.ZERO
var is_net_interpolating: bool = false
var current_input_dir: Vector2 = Vector2.ZERO
var surface_detector: SurfaceDetector3D = null
var _step_timer: float = 0.0


func _ready() -> void:
	floor_snap_length = 0.25
	floor_max_angle = deg_to_rad(48.0)
	floor_stop_on_slope = true
	if movement_profile == null:
		movement_profile = MovementProfile.new()
	if step_noise == null:
		step_noise = load(DEFAULT_STEP_NOISE_PATH) as StepNoiseProfile
	_setup_collision_shape()
	_setup_surface_detector()


## Ciclo por tick ejecutado desde _physics_process del controlador
func run_tick(delta: float) -> void:
	if is_remote_puppet():
		update_presentation(delta)
		return
	if is_locally_controlled:
		apply_input(gather_input(camera))
		_process_local_actions()
	simulate_movement(delta)
	update_presentation(delta)


## Verdadero si hay red real y esta máquina no tiene autoridad sobre el personaje
func is_remote_puppet() -> bool:
	return NetManager.is_online() and not is_multiplayer_authority()


## Mueve al personaje en una dirección del mundo para la IA (deshace rotación de 45°)
func apply_world_move(world_dir: Vector3, sprint: bool = false) -> void:
	var flat: Vector3 = world_dir.slide(Vector3.UP)
	var local_dir: Vector3 = flat.rotated(Vector3.UP, deg_to_rad(-45.0))
	current_input_dir = Vector2(local_dir.x, local_dir.z).limit_length(1.0)
	is_sprinting = sprint
	is_sneaking = false


## Punto del plano horizontal del personaje bajo el cursor
func project_cursor_on_ground(cam: Camera3D) -> Vector3:
	return LocalInput3D.project_cursor(self, cam)


## Captura el input del dispositivo local
func gather_input(cam: Camera3D = null) -> Dictionary:
	return LocalInput3D.read(self, cam)


## Almacena los datos de entrada validados para la simulación
func apply_input(input_data: Dictionary) -> void:
	if input_data.has("movement_vector"):
		current_input_dir = input_data["movement_vector"] as Vector2
	elif input_data.has("input_dir"):
		current_input_dir = input_data["input_dir"] as Vector2
	elif input_data.has("move_vector"):
		current_input_dir = input_data["move_vector"] as Vector2

	if input_data.has("is_sprinting"):
		is_sprinting = bool(input_data["is_sprinting"])
	elif input_data.has("sprint"):
		is_sprinting = bool(input_data["sprint"])

	if input_data.has("is_sneaking"):
		is_sneaking = bool(input_data["is_sneaking"])
	elif input_data.has("sneak"):
		is_sneaking = bool(input_data["sneak"])

	if input_data.has("look_target"):
		look_target_position = input_data["look_target"] as Vector3
	elif input_data.has("look_target_position"):
		look_target_position = input_data["look_target_position"] as Vector3

	if input_data.has("crouching"):
		set_crouching(bool(input_data["crouching"]))
	elif input_data.get("crouch", false):
		set_crouching(not is_crouching)


## Resuelve el modo de movimiento activo: CROUCH > SNEAK > SPRINT > WALK
func get_move_mode() -> MovementProfile.Mode:
	if is_crouching:
		return MovementProfile.Mode.CROUCH
	if is_sneaking:
		return MovementProfile.Mode.SNEAK
	if is_sprinting:
		return MovementProfile.Mode.SPRINT
	return MovementProfile.Mode.WALK


## Cambia el estado de agachado validando permisos y espacio sobre la cabeza
func set_crouching(value: bool) -> bool:
	if value == is_crouching:
		return false
	if value and movement_profile != null and not movement_profile.can_crouch:
		return false
	if not value and not CrouchCollision.has_headroom(self, CrouchCollision.STAND_HEIGHT):
		stand_up_blocked.emit()
		return false

	is_crouching = value
	if collision_shape == null:
		_setup_collision_shape()
	else:
		CrouchCollision.apply(collision_shape, value)
	crouch_changed.emit(value)
	return true


## Calcula el radio acústico del paso según modo, superficie y bando
func compute_step_radius() -> float:
	var s_noise: StepNoiseProfile = step_noise
	if s_noise == null:
		s_noise = load(DEFAULT_STEP_NOISE_PATH) as StepNoiseProfile
		if s_noise == null:
			s_noise = StepNoiseProfile.new()
	var surface_mult: float = (
		surface_detector.get_surface_noise_multiplier() if surface_detector != null else 1.0
	)
	var team_mult: float = movement_profile.team_noise_mult if movement_profile != null else 1.0
	return s_noise.radius_for(get_move_mode(), surface_mult, team_mult)


## Simulación física isométrica de movimiento
func simulate_movement(delta: float) -> void:
	var raw_dir: Vector3 = Vector3(current_input_dir.x, 0.0, current_input_dir.y)
	var move_dir: Vector3 = raw_dir.rotated(Vector3.UP, deg_to_rad(45.0)).normalized()

	if move_dir.length_squared() > 0.001:
		_apply_movement_speed(move_dir, delta)
		_process_footstep_cadence(delta)
	else:
		_apply_friction(delta)
		_step_timer = 0.0

	_apply_gravity(delta)
	move_and_slide()


## Snapshot de posición y velocidad para red
func set_net_transform(pos: Vector3, vel: Vector3) -> void:
	net_target_position = pos
	net_target_velocity = vel
	is_net_interpolating = true


## Snapshot completo para red (posición, velocidad y agachado)
func set_net_state(pos: Vector3, vel: Vector3, crouching: bool) -> void:
	set_net_transform(pos, vel)
	set_crouching(crouching)


## Actualiza rotación e interpolación visual
func update_presentation(delta: float) -> void:
	if is_net_interpolating:
		if global_position.distance_squared_to(net_target_position) > 25.0:
			global_position = net_target_position
		else:
			global_position = global_position.lerp(
				net_target_position, clampf(15.0 * delta, 0.0, 1.0)
			)
		velocity = net_target_velocity

	var horizontal_vel: Vector3 = velocity.slide(Vector3.UP)
	var face_dir: Vector3 = (
		horizontal_vel
		if horizontal_vel.length() >= FACE_MOVEMENT_MIN_SPEED
		else (look_target_position - global_position).slide(Vector3.UP)
	)
	if face_dir.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-face_dir.x, -face_dir.z), 0.25)


## Compatibilidad hacia atrás: combina input, simulación y presentación
func process_isometric_movement(delta: float, input_dir: Vector2, cam: Camera3D = null) -> void:
	var target_pos: Vector3 = project_cursor_on_ground(cam)
	apply_input(
		{
			"movement_vector": input_dir,
			"is_sprinting": is_sprinting,
			"is_sneaking": is_sneaking,
			"look_target": target_pos,
		}
	)
	simulate_movement(delta)
	update_presentation(delta)


func _process_local_actions() -> void:
	pass


func _clear_input() -> void:
	current_input_dir = Vector2.ZERO
	is_sprinting = false
	is_sneaking = false


func _setup_collision_shape() -> void:
	collision_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null:
		collision_shape = find_child("CollisionShape3D", false, false) as CollisionShape3D
	if collision_shape != null:
		CrouchCollision.apply(collision_shape, is_crouching)


func _setup_surface_detector() -> void:
	surface_detector = SurfaceDetector3D.new()
	surface_detector.name = "SurfaceDetector"
	add_child(surface_detector)


func _apply_movement_speed(move_dir: Vector3, delta: float) -> void:
	var mode: MovementProfile.Mode = get_move_mode()
	current_speed = movement_profile.speed_for(mode) if movement_profile != null else 4.5
	var accel: float = movement_profile.acceleration if movement_profile != null else 18.0
	var target_vel: Vector3 = move_dir * current_speed
	velocity.x = move_toward(velocity.x, target_vel.x, accel * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, accel * delta)


func _apply_friction(delta: float) -> void:
	var fric: float = movement_profile.friction if movement_profile != null else 22.0
	velocity.x = move_toward(velocity.x, 0.0, fric * delta)
	velocity.z = move_toward(velocity.z, 0.0, fric * delta)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0


func _process_footstep_cadence(delta: float) -> void:
	_step_timer += delta
	var interval: float = (
		movement_profile.step_interval_for(get_move_mode()) if movement_profile != null else 0.42
	)
	if _step_timer >= interval:
		_step_timer = 0.0
		_emit_step_sound()


func _emit_step_sound() -> void:
	var radius: float = compute_step_radius()
	NoiseEmit.emit(global_position, radius, team_id, NoiseEmit.STEP, self)
	SignalBus.footprint_stepped_3d.emit(global_position, rotation.y)
