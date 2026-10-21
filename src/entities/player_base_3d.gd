## @file player_base_3d.gd
## Clase base para personajes 3D (Ladrón y Guardia) en perspectiva isométrica.
## Desacopla Input, Simulación y Presentación para dar soporte a servidor
## autoritativo dedicado headless y predicción local en clientes.
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

## Vector 2D de entrada actual sin transformar
var current_input_dir: Vector2 = Vector2.ZERO

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

## Captura el input del dispositivo local (vector 2D, sprint, sneak y punto objetivo en plano XZ).
## Si no hay cámara o viewport disponible, usa look_target_position sin dependencias visuales.
func gather_input(camera: Camera3D = null) -> Dictionary:
	var left: StringName = &"move_left" if InputMap.has_action("move_left") else &"ui_left"
	var right: StringName = &"move_right" if InputMap.has_action("move_right") else &"ui_right"
	var up: StringName = &"move_up" if InputMap.has_action("move_up") else &"ui_up"
	var down: StringName = &"move_down" if InputMap.has_action("move_down") else &"ui_down"
	var move_vec: Vector2 = Input.get_vector(left, right, up, down)

	var sprint: bool = Input.is_action_pressed("sprint") if InputMap.has_action("sprint") else false
	var sneak: bool = Input.is_action_pressed("sneak") if InputMap.has_action("sneak") else false

	var target_pos: Vector3 = look_target_position
	if camera != null and is_inside_tree():
		var vp: Viewport = get_viewport()
		if vp != null:
			var mouse_screen_pos: Vector2 = vp.get_mouse_position()
			var ground_plane: Plane = Plane(Vector3.UP, global_position.y)
			var ray_origin: Vector3 = camera.project_ray_origin(mouse_screen_pos)
			var ray_dir: Vector3 = camera.project_ray_normal(mouse_screen_pos)
			var hit: Variant = ground_plane.intersects_ray(ray_origin, ray_dir)
			if hit != null:
				target_pos = hit as Vector3

	return {
		"movement_vector": move_vec,
		"is_sprinting": sprint,
		"is_sneaking": sneak,
		"look_target": target_pos,
	}

## Almacena los datos de entrada validados en la entidad para ser usados en la simulación
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

## Ejecuta la simulación física (rotación 45°, aceleración, fricción, gravedad,
## move_and_slide() y cadencia de pasos). NO depende de Viewport, Camera3D ni UI.
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

## Rota la orientación horizontal hacia look_target_position y maneja efectos de presentación.
func update_presentation(_delta: float) -> void:
	var dir: Vector3 = look_target_position - global_position
	dir.y = 0.0
	if dir.length_squared() > 0.01:
		var target_rot_y: float = atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_rot_y, 0.25)

## Compatibilidad hacia atrás: combina captura de objetivo, input, simulación y presentación.
func process_isometric_movement(delta: float, input_dir: Vector2, camera: Camera3D = null) -> void:
	var target_pos: Vector3 = look_target_position
	if camera != null and is_inside_tree():
		var vp: Viewport = get_viewport()
		if vp != null:
			var mouse_screen_pos: Vector2 = vp.get_mouse_position()
			var ground_plane: Plane = Plane(Vector3.UP, global_position.y)
			var ray_origin: Vector3 = camera.project_ray_origin(mouse_screen_pos)
			var ray_dir: Vector3 = camera.project_ray_normal(mouse_screen_pos)
			var hit: Variant = ground_plane.intersects_ray(ray_origin, ray_dir)
			if hit != null:
				target_pos = hit as Vector3

	apply_input({
		"movement_vector": input_dir,
		"is_sprinting": is_sprinting,
		"is_sneaking": is_sneaking,
		"look_target": target_pos,
	})
	simulate_movement(delta)
	update_presentation(delta)

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

## Deprecated: mantenida por compatibilidad hacia atrás
func _update_rotation_towards_mouse(camera: Camera3D) -> void:
	if camera == null or not is_inside_tree():
		return
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var ground_plane: Plane = Plane(Vector3.UP, global_position.y)
	var mouse_screen_pos: Vector2 = vp.get_mouse_position()
	var ray_origin: Vector3 = camera.project_ray_origin(mouse_screen_pos)
	var ray_dir: Vector3 = camera.project_ray_normal(mouse_screen_pos)
	var hit: Variant = ground_plane.intersects_ray(ray_origin, ray_dir)
	if hit != null:
		look_target_position = hit as Vector3
		update_presentation(0.0)

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
