## Controlador para los miembros del equipo de seguridad privada (Guardias).
## Controla la linterna Maglite SpotLight3D con sombras dinámicas, gestión de estamina,
## cálculo geométrico de percepción/cono de visión y neutralización con porra.
class_name GuardController3D
extends PlayerBase3D

## Ruta del perfil de movimiento del guardia
const MOVEMENT_PROFILE_PATH: String = "res://data/balance/movement_guard.tres"

## Ruta del perfil de percepción del guardia
const PERCEPTION_PROFILE_PATH: String = "res://data/balance/perception_guard.tres"

## Cooldown entre impactos de porra en segundos
const BATON_COOLDOWN_TIME: float = 0.75

## Radio (m) del ruido de un golpe de porra y de una captura
const BATON_SWING_NOISE_RADIUS: float = 4.5
const CAPTURE_NOISE_RADIUS: float = 8.0

## Linterna Maglite asignada al personaje
@export var maglite_light: SpotLight3D

## Perfil de percepción del guardia
@export var perception: PerceptionProfile

## Identificador y modo de control de este guardia
@export var is_ai_controlled: bool = false
@export var guard_id: int = 1

## Parámetros de energía / estamina y recarga de porra
var stamina: float = 100.0
var max_stamina: float = 100.0
var stamina_drain_rate: float = 35.0
var stamina_recovery_rate: float = 20.0
var baton_cooldown: float = 0.0

## Componente modular de interacción (para relojes de fichar y puertas)
var interactor: Interactor3D = null

## Propiedad de conveniencia para que el HUD consulte el interactuable enfocado
var focused_interactive: Node3D:
	get:
		return interactor.current_target if interactor != null else null


func _ready() -> void:
	if movement_profile == null:
		movement_profile = load(MOVEMENT_PROFILE_PATH)
	if perception == null:
		perception = load(PERCEPTION_PROFILE_PATH)
	super._ready()
	team_id = &"guard"
	add_to_group(&"guards")
	interactor = Interactor3D.new()
	interactor.name = "GuardInteractor"
	add_child(interactor)


## La IA (GuardAI3D) escribe su intención con apply_world_move(); la simulación es la misma
## que para un jugador humano, así que la gravedad, la estamina y los pasos se aplican igual.
func _physics_process(delta: float) -> void:
	run_tick(delta)


func _process_local_actions() -> void:
	_handle_interaction_input()


## Simulación física del guardia: gestiona estamina para sprint, cooldown de porra y movimiento
func simulate_movement(delta: float) -> void:
	if baton_cooldown > 0.0:
		baton_cooldown = maxf(0.0, baton_cooldown - delta)

	_process_stamina_and_sprint(delta, current_input_dir)
	super.simulate_movement(delta)


## Actualiza la presentación visual del guardia y la orientación del foco Maglite
func update_presentation(delta: float) -> void:
	super.update_presentation(delta)
	_update_maglite_orientation()


## Orienta el haz de la linterna Maglite hacia el punto apuntado por el cursor
func _update_maglite_orientation() -> void:
	if maglite_light == null:
		return

	var dir_to_target: Vector3 = (look_target_position - maglite_light.global_position).normalized()
	if dir_to_target.length_squared() > 0.01:
		var up_vector: Vector3 = Vector3.UP
		if 1.0 - absf(dir_to_target.dot(Vector3.UP)) < 0.02:
			up_vector = Vector3.FORWARD
		maglite_light.look_at(look_target_position, up_vector)


## Evalúa si el ladrón es detectable según:
## 1. Proximidad inmediata y línea de visión (sin estar en arco ciego trasero)
## 2. Cono de la linterna Maglite (ángulo y distancia sin oclusión de muros)
func check_detection_on_thief(thief: ThiefController3D) -> bool:
	if thief == null:
		return false
	if perception == null:
		perception = load(PERCEPTION_PROFILE_PATH)

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var eyes: Vector3 = global_position + Vector3(0.0, perception.eye_height, 0.0)
	var forward: Vector3 = -global_transform.basis.z
	var points: Array[Vector3] = PerceptionRules.visibility_points(thief, perception)

	# 1. Chequeo por radio de proximidad inmediata y arco ciego
	if (
		PerceptionRules.horizontal_distance(global_position, thief.global_position)
		<= perception.proximity_radius
	):
		if not PerceptionRules.is_in_rear_blind_arc(
			global_position, forward, thief.global_position, perception.rear_blind_arc_deg
		):
			for pt: Vector3 in points:
				if _has_line_of_sight(space_state, eyes, pt):
					return true

	# 2. Chequeo dentro del cono de la linterna Maglite
	if maglite_light != null and maglite_light.visible:
		var light_origin: Vector3 = maglite_light.global_position
		var light_forward: Vector3 = -maglite_light.global_transform.basis.z.normalized()
		var spot_range: float = maglite_light.spot_range
		var spot_half_angle: float = deg_to_rad(maglite_light.spot_angle)

		for pt: Vector3 in points:
			var dir_to_point: Vector3 = (pt - light_origin).normalized()
			if light_origin.distance_to(pt) <= spot_range:
				if light_forward.angle_to(dir_to_point) <= spot_half_angle:
					if _has_line_of_sight(space_state, light_origin, pt):
						return true

	return false


## Valida de forma autoritativa en el servidor si un golpe cuerpo a cuerpo es legítimo
func validate_melee_hit(target_thief: ThiefController3D) -> bool:
	if target_thief == null:
		return false
	if perception == null:
		perception = load(PERCEPTION_PROFILE_PATH)
	if (
		PerceptionRules.horizontal_distance(global_position, target_thief.global_position)
		> perception.melee_range
	):
		return false
	if is_inside_tree() and get_world_3d() != null:
		var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
		if space_state != null:
			var guard_torso: Vector3 = global_position + Vector3(0.0, perception.torso_height, 0.0)
			var thief_torso: Vector3 = (
				target_thief.global_position + Vector3(0.0, perception.torso_height, 0.0)
			)
			if not _has_line_of_sight(space_state, guard_torso, thief_torso):
				return false
	return true


## Ejecuta un golpe con la porra de madera validado autoritativamente
func swing_baton(target_thief: ThiefController3D = null) -> bool:
	if baton_cooldown > 0.0:
		return false

	var valid_hit: bool = target_thief != null and validate_melee_hit(target_thief)

	baton_cooldown = BATON_COOLDOWN_TIME
	SignalBus.noise_emitted_3d.emit(global_position, BATON_SWING_NOISE_RADIUS, &"guard")

	if valid_hit:
		var is_captured: bool = true
		if target_thief.has_method("register_baton_hit"):
			is_captured = target_thief.register_baton_hit()
		if is_captured:
			_capture_thief()
		return true

	return false


func _capture_thief() -> void:
	var p_id: int = get_multiplayer_authority()
	SignalBus.thief_captured.emit(p_id)
	SignalBus.noise_emitted_3d.emit(global_position, CAPTURE_NOISE_RADIUS, &"guard")


func _process_stamina_and_sprint(delta: float, input_dir: Vector2) -> void:
	if is_sprinting and (stamina <= 5.0 or input_dir.length_squared() <= 0.01):
		is_sprinting = false

	if is_sprinting:
		stamina = maxf(0.0, stamina - stamina_drain_rate * delta)
	else:
		stamina = minf(max_stamina, stamina + stamina_recovery_rate * delta)


func _handle_interaction_input() -> void:
	var interact_pressed: bool = (
		Input.is_action_just_pressed("interact") if InputMap.has_action("interact") else false
	)
	if interact_pressed and interactor != null:
		interactor.execute_interaction(self)


func _has_line_of_sight(space_state: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1  # Solo colisiona con el entorno
	var result: Dictionary = space_state.intersect_ray(query)
	return result.is_empty()
