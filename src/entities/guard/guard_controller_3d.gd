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

## Estado «mirando monitores» de la garita (interaction.md M1/M3)
var monitor_watch: GuardMonitorWatch = GuardMonitorWatch.new()

var _flashlight_on: bool = true
var _senses: GuardSenses = GuardSenses.new()


func _ready() -> void:
	movement_profile = (
		movement_profile if movement_profile != null else load(MOVEMENT_PROFILE_PATH)
	)
	perception = perception if perception != null else load(PERCEPTION_PROFILE_PATH)
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
	if InputMap.has_action("interact") and Input.is_action_just_pressed("interact"):
		perform_action(&"interact")
	if (
		InputMap.has_action("toggle_flashlight")
		and Input.is_action_just_pressed("toggle_flashlight")
	):
		perform_action(&"toggle_flashlight")


## Cambia el estado de la linterna sin emitir ruido (para sincronización de red)
func apply_flashlight_state(on: bool) -> void:
	if flashlight_on == on:
		return
	flashlight_on = on
	if maglite_light != null:
		maglite_light.visible = on


## Ejecuta una acción discreta sobre el guardia. Devuelve true si la ejecutó
func perform_action(action: StringName) -> bool:
	var result: bool = false
	match action:
		&"interact":
			if monitor_watch.is_active():
				stop_watching()
				result = true
			elif interactor != null:
				result = interactor.execute_interaction(self)
		&"toggle_flashlight":
			set_flashlight(not flashlight_on)
			result = true
		&"strike":
			var target_thief: ThiefController3D = null
			if is_inside_tree():
				target_thief = get_tree().get_first_node_in_group(&"thief") as ThiefController3D
			result = swing_baton(target_thief)
		_:
			result = super.perform_action(action)
	return result


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

	monitor_watch.tick(self, delta)
	_process_stamina_and_sprint(delta, current_input_dir)
	super.simulate_movement(delta)


## Sentado ante los monitores no se mueve y mira a la mesa; un movimiento lo levanta
func apply_input(input_data: Dictionary) -> void:
	super.apply_input(monitor_watch.filter_input(self, input_data))


## true si está sentado mirando los monitores (no mientras se sienta)
func is_watching_monitors() -> bool:
	return monitor_watch.state == GuardMonitorWatch.State.WATCHING


## Se levanta de los monitores y libera la mesa
func stop_watching() -> void:
	monitor_watch.stop(self)


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
	var face_dir: Vector3 = to_target if to_target.length() >= 0.1 else velocity.slide(Vector3.UP)

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
		lamps.assign(get_tree().get_nodes_in_group(&"lamps"))
	return _senses.detects(self, thief, lamps) != &""


## Actualiza la percepción sobre el ladrón, emite thief_perceived y gestiona la persistencia O2
func update_perception(thief: ThiefController3D, lamps: Array[Lamp3D], delta: float) -> void:
	if perception == null:
		perception = load(PERCEPTION_PROFILE_PATH) as PerceptionProfile
	var detects_thief: bool = thief != null and _senses.detects(self, thief, lamps) != &""

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
	var dist: float = PerceptionRules.horizontal_distance(
		global_position, target_thief.global_position
	)
	if dist > perception.melee_range:
		return false
	if is_inside_tree() and get_world_3d() != null:
		var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
		if space_state != null:
			var offset: Vector3 = Vector3(0.0, perception.torso_height, 0.0)
			var from_pos: Vector3 = global_position + offset
			var to_pos: Vector3 = target_thief.global_position + offset
			if not GuardSenses._has_line_of_sight(space_state, from_pos, to_pos):
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
	SignalBus.thief_captured.emit(get_multiplayer_authority())
	if perception == null:
		perception = load(PERCEPTION_PROFILE_PATH) as PerceptionProfile
	NoiseEmit.emit(
		global_position, perception.capture_noise_radius, &"guard", NoiseEmit.IMPACT, self
	)


func _process_stamina_and_sprint(delta: float, input_dir: Vector2) -> void:
	if is_sprinting and (stamina <= 5.0 or input_dir.length_squared() <= 0.01):
		is_sprinting = false
	var rate: float = -stamina_drain_rate if is_sprinting else stamina_recovery_rate
	stamina = clampf(stamina + rate * delta, 0.0, max_stamina)
