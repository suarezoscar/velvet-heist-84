## @file player_base_3d.gd
## Clase base para personajes 3D (Ladrón y Guardia) en perspectiva isométrica.
## Desacopla Input, Simulación y Presentación para dar soporte a servidor
## autoritativo dedicado headless, predicción local y posturas tácticas (FEAT-005).
class_name PlayerBase3D
extends CharacterBody3D

## Posturas tácticas disponibles según FEAT-005
enum Stance {
	STAND = 0,
	TIPTOE = 1,
	CROUCH = 2,
	PRONE = 3,
	WALL_COVER = 4,
}

## Notificación de cambio de postura
signal stance_changed(old_stance: Stance, new_stance: Stance)

## Velocidad horizontal mínima (m/s) para orientar el cuerpo hacia el desplazamiento
const FACE_MOVEMENT_MIN_SPEED: float = 0.5

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

## Cámara isométrica usada para proyectar el cursor (solo la usa el jugador local)
@export var camera: Camera3D

## Indica si este personaje lo controla el teclado y ratón de esta máquina.
## Lo asigna el mapa: como mucho un personaje por cliente. Sin él, el personaje
## no lee Input (lo mueve la IA, la red o queda quieto).
var is_locally_controlled: bool = false:
	set(value):
		is_locally_controlled = value
		if not value:
			_clear_input()

## Postura táctica actual
var current_stance: Stance = Stance.STAND

## Nodo de colisión cacheado
var collision_shape: CollisionShape3D = null

## Indica si el recurso de forma de colision ha sido duplicado localmente
var _is_shape_duplicated: bool = false
var current_wall_normal: Vector3 = Vector3.ZERO
var current_wall_tangent: Vector3 = Vector3.ZERO

var current_speed: float = 4.5
var is_sprinting: bool = false
var is_sneaking: bool = false
var look_target_position: Vector3 = Vector3.ZERO

## Variables de replicación de red continua
var net_target_position: Vector3 = Vector3.ZERO
var net_target_velocity: Vector3 = Vector3.ZERO
var is_net_interpolating: bool = false

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
	_setup_collision_shape()
	_setup_surface_detector()


func _setup_collision_shape() -> void:
	collision_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null:
		collision_shape = find_child("CollisionShape3D", false, false) as CollisionShape3D
	if collision_shape != null:
		_update_collision_for_stance(current_stance)


func _setup_surface_detector() -> void:
	surface_detector = SurfaceDetector3D.new()
	surface_detector.name = "SurfaceDetector"
	add_child(surface_detector)


## Ciclo por tick que invocan los controladores concretos desde su _physics_process (la base
## no se simula sola, para poder usarla en tests). Un personaje remoto en red solo se
## presenta; el local lee Input; el resto (IA o sin dueño) simula con la entrada aplicada.
func run_tick(delta: float) -> void:
	if is_remote_puppet():
		update_presentation(delta)
		return
	if is_locally_controlled:
		apply_input(gather_input(camera))
		_process_local_actions()
	simulate_movement(delta)
	update_presentation(delta)


## Verdadero si hay una sesión de red real y esta máquina no tiene autoridad sobre el personaje.
func is_remote_puppet() -> bool:
	return NetManager.is_online() and not is_multiplayer_authority()


## Acciones de input propias de cada rol (interactuar, gadgets). Solo para el jugador local.
func _process_local_actions() -> void:
	pass


## Mueve al personaje en una dirección del mundo (para la IA), reutilizando la misma
## simulación que el input del jugador: deshace la rotación isométrica de 45°.
func apply_world_move(world_dir: Vector3, sprint: bool = false) -> void:
	var flat: Vector3 = world_dir.slide(Vector3.UP)
	var local_dir: Vector3 = flat.rotated(Vector3.UP, deg_to_rad(-45.0))
	current_input_dir = Vector2(local_dir.x, local_dir.z).limit_length(1.0)
	is_sprinting = sprint
	is_sneaking = false


func _clear_input() -> void:
	current_input_dir = Vector2.ZERO
	is_sprinting = false
	is_sneaking = false


## Punto del plano horizontal del personaje bajo el cursor, o look_target_position si no hay.
func project_cursor_on_ground(cam: Camera3D) -> Vector3:
	if cam == null or not is_inside_tree():
		return look_target_position
	var mouse_screen_pos: Vector2 = get_viewport().get_mouse_position()
	var ground_plane: Plane = Plane(Vector3.UP, global_position.y)
	var hit: Variant = ground_plane.intersects_ray(
		cam.project_ray_origin(mouse_screen_pos), cam.project_ray_normal(mouse_screen_pos)
	)
	return hit as Vector3 if hit != null else look_target_position


## Captura el input del dispositivo local: vector 2D, sprint, sneak, posturas y
## punto objetivo en el plano XZ.
func gather_input(cam: Camera3D = null) -> Dictionary:
	var left: StringName = &"move_left" if InputMap.has_action("move_left") else &"ui_left"
	var right: StringName = &"move_right" if InputMap.has_action("move_right") else &"ui_right"
	var up: StringName = &"move_up" if InputMap.has_action("move_up") else &"ui_up"
	var down: StringName = &"move_down" if InputMap.has_action("move_down") else &"ui_down"
	var move_vec: Vector2 = Input.get_vector(left, right, up, down)

	var sprint: bool = Input.is_action_pressed("sprint") if InputMap.has_action("sprint") else false
	var sneak: bool = Input.is_action_pressed("sneak") if InputMap.has_action("sneak") else false

	var crouch_pressed: bool = (
		Input.is_action_just_pressed("crouch") if InputMap.has_action("crouch") else false
	)
	var prone_pressed: bool = (
		Input.is_action_just_pressed("prone") if InputMap.has_action("prone") else false
	)
	var wall_cover_pressed: bool = false
	if InputMap.has_action("wall_cover"):
		wall_cover_pressed = Input.is_action_just_pressed("wall_cover")
	elif InputMap.has_action("cover"):
		wall_cover_pressed = Input.is_action_just_pressed("cover")

	var target_pos: Vector3 = project_cursor_on_ground(cam)

	return {
		"movement_vector": move_vec,
		"is_sprinting": sprint,
		"is_sneaking": sneak,
		"look_target": target_pos,
		"crouch": crouch_pressed,
		"prone": prone_pressed,
		"wall_cover": wall_cover_pressed,
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

	# Transiciones de postura solicitadas
	if input_data.has("stance"):
		set_stance(input_data["stance"] as Stance)
	elif input_data.has("target_stance"):
		set_stance(input_data["target_stance"] as Stance)
	elif input_data.get("wall_cover", false):
		set_stance(Stance.STAND if current_stance == Stance.WALL_COVER else Stance.WALL_COVER)
	elif input_data.get("prone", false):
		set_stance(Stance.STAND if current_stance == Stance.PRONE else Stance.PRONE)
	elif input_data.get("crouch", false):
		set_stance(Stance.STAND if current_stance == Stance.CROUCH else Stance.CROUCH)
	elif input_data.get("tiptoe", false):
		set_stance(Stance.STAND if current_stance == Stance.TIPTOE else Stance.TIPTOE)


## Consulta la postura actual
func get_stance() -> Stance:
	return current_stance


## Establece una nueva postura si las condiciones espaciales y físicas lo permiten
func set_stance(new_stance: Stance) -> bool:
	if current_stance == new_stance:
		return false
	if not can_enter_stance(new_stance):
		return false

	var old_stance: Stance = current_stance
	current_stance = new_stance

	if current_stance == Stance.WALL_COVER:
		_align_to_wall()
	else:
		current_wall_normal = Vector3.ZERO
		current_wall_tangent = Vector3.ZERO

	_update_collision_for_stance(current_stance)
	stance_changed.emit(old_stance, new_stance)
	return true


## Valida si es físicamente posible adoptar una postura (espacio superior libre
## hacia posturas más altas).
func can_enter_stance(target_stance: Stance) -> bool:
	var target_height: float = 1.6
	match target_stance:
		Stance.CROUCH:
			target_height = 1.0
		Stance.PRONE:
			target_height = 0.4
		_:
			target_height = 1.6

	var current_height: float = 1.6
	match current_stance:
		Stance.CROUCH:
			current_height = 1.0
		Stance.PRONE:
			current_height = 0.4
		_:
			current_height = 1.6

	if target_height > current_height:
		if is_inside_tree() and get_world_3d() != null:
			var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
			if space_state != null:
				var from_pos: Vector3 = global_position + Vector3(0.0, 0.1, 0.0)
				var to_pos: Vector3 = global_position + Vector3(0.0, target_height, 0.0)
				var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
					from_pos, to_pos
				)
				query.collision_mask = 1  # World_Solid
				query.exclude = [get_rid()]
				var hit: Dictionary = space_state.intersect_ray(query)
				if not hit.is_empty():
					return false
	return true


## Devuelve el multiplicador de velocidad según la postura
func get_stance_speed_multiplier() -> float:
	match current_stance:
		Stance.STAND:
			return 1.0
		Stance.TIPTOE:
			return 0.45
		Stance.CROUCH:
			return 0.55
		Stance.PRONE:
			return 0.25
		Stance.WALL_COVER:
			return 0.40
		_:
			return 1.0


## Devuelve el factor multiplicador de ruido acústico según la postura
func get_stance_noise_multiplier() -> float:
	match current_stance:
		Stance.STAND:
			return 1.0
		Stance.TIPTOE:
			return 0.0
		Stance.CROUCH:
			return 0.35
		Stance.PRONE:
			return 0.0
		Stance.WALL_COVER:
			return 0.15
		_:
			return 1.0


## Ajusta dinámicamente las dimensiones de la cápsula de colisión
func _update_collision_for_stance(stance: Stance) -> void:
	if collision_shape == null:
		collision_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
		if collision_shape == null:
			collision_shape = find_child("CollisionShape3D", false, false) as CollisionShape3D

	if collision_shape == null:
		return

	if collision_shape.shape == null:
		collision_shape.shape = CapsuleShape3D.new()
		_is_shape_duplicated = true
	elif not _is_shape_duplicated:
		collision_shape.shape = collision_shape.shape.duplicate()
		_is_shape_duplicated = true

	var capsule: CapsuleShape3D = collision_shape.shape as CapsuleShape3D
	if capsule == null:
		return

	match stance:
		Stance.STAND, Stance.TIPTOE:
			capsule.height = 1.6
			capsule.radius = 0.35
			collision_shape.transform.origin = Vector3(0.0, 0.8, 0.0)
		Stance.CROUCH:
			capsule.height = 1.0
			capsule.radius = 0.35
			collision_shape.transform.origin = Vector3(0.0, 0.5, 0.0)
		Stance.PRONE:
			capsule.radius = 0.20
			capsule.height = 0.40
			collision_shape.transform.origin = Vector3(0.0, 0.2, 0.0)
		Stance.WALL_COVER:
			capsule.height = 1.6
			capsule.radius = 0.25
			collision_shape.transform.origin = Vector3(0.0, 0.8, 0.0)


## Detecta la presencia de un muro cercano (< max_distance) para cobertura
func detect_wall_ahead(max_distance: float = 0.7) -> Dictionary:
	if not is_inside_tree() or get_world_3d() == null:
		return {}
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space_state == null:
		return {}

	var start_pos: Vector3 = global_position + Vector3(0.0, 0.8, 0.0)
	var forward: Vector3 = -global_transform.basis.z.normalized()
	if forward.length_squared() < 0.001:
		forward = Vector3.FORWARD

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		start_pos, start_pos + forward * max_distance
	)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	var hit: Dictionary = space_state.intersect_ray(query)
	if not hit.is_empty():
		return hit

	var look_dir: Vector3 = (look_target_position - global_position).slide(Vector3.UP).normalized()
	if look_dir.length_squared() > 0.01 and look_dir.dot(forward) < 0.95:
		var look_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			start_pos, start_pos + look_dir * max_distance
		)
		look_query.collision_mask = 1
		look_query.exclude = [get_rid()]
		hit = space_state.intersect_ray(look_query)
		if not hit.is_empty():
			return hit

	var directions: Array[Vector3] = [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]
	for dir: Vector3 in directions:
		if dir.dot(forward) > 0.9:
			continue
		var dir_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			start_pos, start_pos + dir * max_distance
		)
		dir_query.collision_mask = 1
		dir_query.exclude = [get_rid()]
		hit = space_state.intersect_ray(dir_query)
		if not hit.is_empty():
			return hit

	return {}


func _align_to_wall() -> void:
	var hit: Dictionary = detect_wall_ahead(0.7)
	if not hit.is_empty():
		current_wall_normal = (hit.normal as Vector3).slide(Vector3.UP).normalized()
		current_wall_tangent = current_wall_normal.cross(Vector3.UP).normalized()
		rotation.y = atan2(-current_wall_normal.x, -current_wall_normal.z)


func get_cover_wall_normal() -> Vector3:
	return current_wall_normal


func get_cover_wall_tangent() -> Vector3:
	return current_wall_tangent


## Ejecuta la simulación física (rotación 45°, aceleración, fricción, gravedad,
## move_and_slide() y cadencia de pasos). NO depende de Viewport, Camera3D ni UI.
func simulate_movement(delta: float) -> void:
	var raw_dir: Vector3 = Vector3(current_input_dir.x, 0.0, current_input_dir.y)
	var move_dir: Vector3 = raw_dir.rotated(Vector3.UP, deg_to_rad(45.0)).normalized()

	if current_stance == Stance.WALL_COVER and current_wall_tangent.length_squared() > 0.01:
		if move_dir.length_squared() > 0.001:
			var lateral_factor: float = move_dir.dot(current_wall_tangent)
			var lateral_dir: Vector3 = current_wall_tangent * lateral_factor
			if lateral_dir.length_squared() > 0.001:
				lateral_dir = lateral_dir.normalized()
				_apply_movement_speed(lateral_dir, delta)
				_process_footstep_cadence(delta)
			else:
				_apply_friction(delta)
				_step_timer = 0.0
		else:
			_apply_friction(delta)
			_step_timer = 0.0
	else:
		if move_dir.length_squared() > 0.001:
			_apply_movement_speed(move_dir, delta)
			_process_footstep_cadence(delta)
		else:
			_apply_friction(delta)
			_step_timer = 0.0

	_apply_gravity(delta)
	move_and_slide()


## Recibe un snapshot de transformación por red para interpolación de presentación
func set_net_transform(pos: Vector3, vel: Vector3) -> void:
	net_target_position = pos
	net_target_velocity = vel
	is_net_interpolating = true


## Recibe un snapshot de estado completo por red (posición, velocidad y postura)
func set_net_state(pos: Vector3, vel: Vector3, stance_val: int) -> void:
	set_net_transform(pos, vel)
	if current_stance != stance_val:
		set_stance(stance_val as Stance)


## Rota la orientación horizontal hacia look_target_position e interpola en red.
func update_presentation(delta: float) -> void:
	if is_net_interpolating:
		if global_position.distance_squared_to(net_target_position) > 25.0:
			global_position = net_target_position
		else:
			global_position = global_position.lerp(
				net_target_position, clampf(15.0 * delta, 0.0, 1.0)
			)
		velocity = net_target_velocity

	# Mirar hacia donde se camina evita el "moonwalk" (solo hay animaciones hacia delante);
	# parado, el cuerpo se gira hacia el cursor. En cobertura, la espalda queda contra el muro.
	var face_dir: Vector3 = Vector3.ZERO
	var horizontal_vel: Vector3 = velocity.slide(Vector3.UP)
	if current_stance == Stance.WALL_COVER and current_wall_normal.length_squared() > 0.01:
		face_dir = current_wall_normal
	elif horizontal_vel.length() >= FACE_MOVEMENT_MIN_SPEED:
		face_dir = horizontal_vel
	else:
		face_dir = (look_target_position - global_position).slide(Vector3.UP)
	if face_dir.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-face_dir.x, -face_dir.z), 0.25)


## Compatibilidad hacia atrás: combina captura de objetivo, input, simulación y presentación.
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


func _apply_movement_speed(move_dir: Vector3, delta: float) -> void:
	var stance_mult: float = get_stance_speed_multiplier()
	if is_sprinting and current_stance == Stance.STAND:
		current_speed = sprint_speed
		_step_interval = 0.28
	elif is_sneaking and current_stance == Stance.STAND:
		current_speed = sneak_speed
		_step_interval = 0.60
	else:
		current_speed = move_speed * stance_mult
		match current_stance:
			Stance.TIPTOE:
				_step_interval = 0.55
			Stance.CROUCH:
				_step_interval = 0.50
			Stance.PRONE:
				_step_interval = 0.70
			Stance.WALL_COVER:
				_step_interval = 0.50
			_:
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


func _process_footstep_cadence(delta: float) -> void:
	_step_timer += delta
	if _step_timer >= _step_interval:
		_step_timer = 0.0
		_emit_step_sound()


func _emit_step_sound() -> void:
	var final_noise_radius: float = 3.5
	if surface_detector != null:
		final_noise_radius = surface_detector.calculate_step_noise_radius(
			3.5, is_sprinting, is_sneaking
		)

	final_noise_radius *= get_stance_noise_multiplier()

	if (
		current_stance == Stance.TIPTOE
		or current_stance == Stance.PRONE
		or final_noise_radius <= 0.001
	):
		final_noise_radius = 0.0

	SignalBus.noise_emitted_3d.emit(global_position, final_noise_radius, team_id)
	SignalBus.footprint_stepped_3d.emit(global_position, rotation.y)
