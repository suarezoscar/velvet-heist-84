## @file player_base_3d.gd
## Clase base para personajes 3D (Ladrón y Guardia) en perspectiva isométrica.
## Administra el movimiento XZ rotado 45°, aceleración, rotación hacia el cursor
## y cadencia de emisión de pasos acústicos a través de SurfaceDetector3D.
class_name PlayerBase3D
extends CharacterBody3D

## Velocidad de caminata estándar (m/s)
@export var move_speed: float = 4.5

## Velocidad máxima durante el sprint (m/s)
@export var sprint_speed: float = 7.0

## Velocidad en modo sigilo agachado (m/s)
@export var sneak_speed: float = 2.2

## Aceleración de frenado y arranque
@export var acceleration: float = 18.0
@export var friction: float = 22.0

## Equipo al que pertenece la entidad
@export var team_id: StringName = &"neutral"

var current_speed: float = 4.5
var is_sprinting: bool = false
var is_sneaking: bool = false
var look_target_position: Vector3 = Vector3.ZERO

# Pacing de pasos
var _step_timer: float = 0.0
var _step_interval: float = 0.42

## Componente de detección de acústica de suelos
var surface_detector: SurfaceDetector3D = null

func _ready() -> void:
	floor_snap_length = 0.25
	floor_max_angle = deg_to_rad(48.0)
	floor_stop_on_slope = true
	_setup_surface_detector()

func _setup_surface_detector() -> void:
	surface_detector = SurfaceDetector3D.new()
	surface_detector.name = "SurfaceDetector"
	add_child(surface_detector)

## Procesa el movimiento isométrico y rota el vector de entrada 45° alrededor de Y
func process_isometric_movement(delta: float, input_dir: Vector2, camera: Camera3D) -> void:
	# Conversión de vector de entrada a espacio isométrico diagonal
	var raw_dir: Vector3 = Vector3(input_dir.x, 0.0, input_dir.y)
	var move_dir: Vector3 = raw_dir.rotated(Vector3.UP, deg_to_rad(45.0)).normalized()

	if move_dir.length_squared() > 0.001:
		_apply_movement_speed(move_dir, delta)
		_process_footstep_cadence(delta)
	else:
		_apply_friction(delta)
		_step_timer = 0.0

	_apply_gravity(delta)
	move_and_slide()
	_update_rotation_towards_mouse(camera)

func _apply_movement_speed(move_dir: Vector3, delta: float) -> void:
	if is_sprinting:
		current_speed = sprint_speed
		_step_interval = 0.28
	elif is_sneaking:
		current_speed = sneak_speed
		_step_interval = 0.60
	else:
		current_speed = move_speed
		_step_interval = 0.42

	var target_vel: Vector3 = move_dir * current_speed
	velocity.x = move_toward(velocity.x, target_vel.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, acceleration * delta)

func _apply_friction(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	velocity.z = move_toward(velocity.z, 0.0, friction * delta)

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 19.6 * delta
	else:
		velocity.y = 0.0

## Rota la orientación horizontal del personaje hacia el puntero proyectado en el plano Y
func _update_rotation_towards_mouse(camera: Camera3D) -> void:
	if camera == null:
		return

	var ground_plane: Plane = Plane(Vector3.UP, global_position.y)
	var mouse_screen_pos: Vector2 = get_viewport().get_mouse_position()
	var ray_origin: Vector3 = camera.project_ray_origin(mouse_screen_pos)
	var ray_dir: Vector3 = camera.project_ray_normal(mouse_screen_pos)
	var intersection: Variant = ground_plane.intersects_ray(ray_origin, ray_dir)

	if intersection != null:
		var target: Vector3 = intersection as Vector3
		look_target_position = target
		var dir: Vector3 = target - global_position
		dir.y = 0.0
		if dir.length_squared() > 0.01:
			var target_rot_y: float = atan2(-dir.x, -dir.z)
			rotation.y = lerp_angle(rotation.y, target_rot_y, 0.25)

func _process_footstep_cadence(delta: float) -> void:
	_step_timer += delta
	if _step_timer >= _step_interval:
		_step_timer = 0.0
		_emit_step_sound()

func _emit_step_sound() -> void:
	var final_noise_radius: float = 3.5
	if surface_detector != null:
		final_noise_radius = surface_detector.calculate_step_noise_radius(3.5, is_sprinting, is_sneaking)

	var bus: Node = get_node_or_null("/root/SignalBus")
	if bus != null:
		bus.emit_signal("noise_emitted_3d", global_position, final_noise_radius, team_id)
		bus.emit_signal("footprint_stepped_3d", global_position, rotation.y)
