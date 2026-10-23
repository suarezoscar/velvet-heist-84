## Controlador para los miembros del equipo de seguridad privada (Guardias).
## Controla la linterna Maglite SpotLight3D con sombras dinámicas, gestión de estamina,
## cálculo geométrico de percepción/cono de visión y neutralización con porra.
class_name GuardController3D
extends PlayerBase3D

signal thief_perceived(position: Vector3)

## Ruta del perfil de movimiento del guardia
const MOVEMENT_PROFILE_PATH: String = "res://data/balance/movement_guard.tres"

## Ruta del perfil de percepción del guardia
const PERCEPTION_PROFILE_PATH: String = "res://data/balance/perception_guard.tres"

## Cooldown entre impactos de porra en segundos
const BATON_COOLDOWN_TIME: float = 0.75

## Linterna Maglite asignada al personaje
@export var maglite_light: SpotLight3D

## Perfil de percepción del guardia
@export var perception: PerceptionProfile

## Identificador y modo de control de este guardia
@export var is_ai_controlled: bool = false
@export var guard_id: int = 1

## Estado de la linterna Maglite
var flashlight_on: bool = true:
	get:
		if maglite_light != null:
			return maglite_light.visible
		return _flashlight_on
	set(value):
		_flashlight_on = value
		if maglite_light != null:
			maglite_light.visible = value

## Estado O2 de percepción y última posición conocida
var is_perceiving_thief: bool = false
var last_seen_position: Vector3 = Vector3.ZERO
var last_seen_time_left: float = 0.0

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

var _flashlight_on: bool = true
var _senses: GuardSenses = GuardSenses.new()


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
	interactor.reach_distance = 1.8
	add_child(interactor)

	if maglite_light != null and perception != null:
		maglite_light.spot_range = perception.flashlight_range
		maglite_light.spot_angle = perception.flashlight_half_angle_deg
		maglite_light.position = Vector3(0.0, perception.flashlight_height, -0.4)


## La IA (GuardAI3D) escribe su intención con apply_world_move(); la simulación es la misma
## que para un jugador humano, así que la gravedad, la estamina y los pasos se aplican igual.
func _physics_process(delta: float) -> void:
	run_tick(delta)


func _process_local_actions() -> void:
	_handle_interaction_input()
	if (
		InputMap.has_action("toggle_flashlight")
		and Input.is_action_just_pressed("toggle_flashlight")
	):
		set_flashlight(not flashlight_on)


## Enciende o apaga la linterna Maglite emitiendo ruido sonoro
func set_flashlight(on: bool) -> void:
	if flashlight_on == on:
		return
	flashlight_on = on
	if maglite_light != null:
		maglite_light.visible = on
	if perception == null:
		perception = load(PERCEPTION_PROFILE_PATH) as PerceptionProfile
	NoiseEmit.emit(
		global_position,
		perception.flashlight_toggle_noise_radius,
		&"guard",
		NoiseEmit.MECHANISM,
		self
	)


## Simulación física del guardia: gestiona estamina para sprint, cooldown de porra y movimiento
func simulate_movement(delta: float) -> void:
	if baton_cooldown > 0.0:
		baton_cooldown = maxf(0.0, baton_cooldown - delta)

	_process_stamina_and_sprint(delta, current_input_dir)
	super.simulate_movement(delta)


## Actualiza rotación del guardia orientada a su objetivo de apuntado y la linterna
func update_presentation(delta: float) -> void:
	if is_net_interpolating:
		if global_position.distance_squared_to(net_target_position) > 25.0:
			global_position = net_target_position
		else:
			global_position = global_position.lerp(
				net_target_position, clampf(15.0 * delta, 0.0, 1.0)
			)
		velocity = net_target_velocity

	var to_target: Vector3 = (look_target_position - global_position).slide(Vector3.UP)
	var face_dir: Vector3
	if to_target.length() >= 0.1:
		face_dir = to_target
	else:
		face_dir = velocity.slide(Vector3.UP)

	if face_dir.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-face_dir.x, -face_dir.z), 0.25)

	_update_maglite_orientation()


## Orienta el haz de la linterna Maglite hacia el punto apuntado por el cursor
func _update_maglite_orientation() -> void:
	if maglite_light == null:
		return

	var dir_to_target: Vector3 = (look_target_position - maglite_light.global_position).normalized()
	if dir_to_target.length_squared() > 0.01:
		var up_vector: Vector3 = Vector3.UP
		if absf(dir_to_target.dot(Vector3.UP)) > 0.98:
			up_vector = Vector3.FORWARD
		maglite_light.look_at(look_target_position, up_vector)


## Evalúa si el ladrón es detectable según proximidad, cono de linterna o iluminación
func check_detection_on_thief(thief: ThiefController3D) -> bool:
	if thief == null:
		return false
	var lamps: Array[Lamp3D] = []
	if is_inside_tree():
		for node: Node in get_tree().get_nodes_in_group(&"lamps"):
			if node is Lamp3D:
				lamps.append(node as Lamp3D)
	return _senses.detects(self, thief, lamps) != &""


## Actualiza la percepción sobre el ladrón, emite thief_perceived y gestiona la persistencia O2
func update_perception(thief: ThiefController3D, lamps: Array[Lamp3D], delta: float) -> void:
	if perception == null:
		perception = load(PERCEPTION_PROFILE_PATH) as PerceptionProfile
	var detects_thief: bool = false
	if thief != null:
		detects_thief = _senses.detects(self, thief, lamps) != &""

	if detects_thief:
		is_perceiving_thief = true
		last_seen_position = thief.global_position
		last_seen_time_left = perception.last_seen_linger
		thief_perceived.emit(thief.global_position)
	else:
		is_perceiving_thief = false
		if last_seen_time_left > 0.0:
			last_seen_time_left = maxf(0.0, last_seen_time_left - delta)


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
	if perception == null:
		perception = load(PERCEPTION_PROFILE_PATH) as PerceptionProfile
	NoiseEmit.emit(
		global_position, perception.baton_swing_noise_radius, &"guard", NoiseEmit.IMPACT, self
	)

	if valid_hit:
		var is_captured: bool = true
		if target_thief.has_method("register_baton_hit"):
			is_captured = target_thief.register_baton_hit()
		if is_captured:
			_capture_thief()
		return true

	return false


func _capture_thief() -> void:
	if perception == null:
		perception = load(PERCEPTION_PROFILE_PATH) as PerceptionProfile
	var p_id: int = get_multiplayer_authority()
	SignalBus.thief_captured.emit(p_id)
	NoiseEmit.emit(
		global_position, perception.capture_noise_radius, &"guard", NoiseEmit.IMPACT, self
	)


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
