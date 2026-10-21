## @file guard_controller_3d.gd
## Controlador para los miembros del equipo de seguridad privada (Guardias).
## Controla la linterna Maglite SpotLight3D con sombras dinámicas, gestión de estamina,
## cálculo geométrico de percepción/cono de visión y neutralización con porra.
class_name GuardController3D
extends PlayerBase3D

## Cámara isométrica activa
@export var camera: Camera3D

## Linterna Maglite asignada al personaje
@export var maglite_light: SpotLight3D

## Cooldown entre impactos de porra en segundos
const BATON_COOLDOWN_TIME: float = 0.75

## Alcance del golpe cuerpo a cuerpo con la porra en metros
@export var melee_range: float = 1.6

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

func _ready() -> void:
	super._ready()
	team_id = &"guard"
	move_speed = 4.2
	sprint_speed = 6.2
	sneak_speed = 2.0
	interactor = Interactor3D.new()
	interactor.name = "GuardInteractor"
	interactor.reach_distance = 1.8
	add_child(interactor)

func _physics_process(delta: float) -> void:
	if baton_cooldown > 0.0:
		baton_cooldown -= delta

	if is_ai_controlled:
		_update_maglite_orientation()
		return

	var input_dir: Vector2 = Input.get_vector(
		&"move_left" if InputMap.has_action("move_left") else &"ui_left",
		&"move_right" if InputMap.has_action("move_right") else &"ui_right",
		&"move_up" if InputMap.has_action("move_up") else &"ui_up",
		&"move_down" if InputMap.has_action("move_down") else &"ui_down"
	)
	_process_stamina_and_sprint(delta, input_dir)
	process_isometric_movement(delta, input_dir, camera)
	_update_maglite_orientation()
	_handle_interaction_input()

func _process_stamina_and_sprint(delta: float, input_dir: Vector2) -> void:
	var sprint_requested: bool = Input.is_action_pressed("sprint") if InputMap.has_action("sprint") else false
	if sprint_requested and stamina > 5.0 and input_dir.length_squared() > 0.01:
		is_sprinting = true
		stamina = maxf(0.0, stamina - stamina_drain_rate * delta)
	else:
		is_sprinting = false
		stamina = minf(max_stamina, stamina + stamina_recovery_rate * delta)

func _handle_interaction_input() -> void:
	var interact_pressed: bool = Input.is_action_just_pressed("interact") if InputMap.has_action("interact") else false
	if interact_pressed and interactor != null:
		interactor.execute_interaction(self)

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

## Evalúa si el ladrón es detectable según:
## 1. Proximidad inmediata (1.8m sin obstáculos)
## 2. Cono de la linterna Maglite (ángulo y distancia sin oclusión de muros)
func check_detection_on_thief(thief: ThiefController3D) -> bool:
	if thief == null:
		return false

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var thief_torso: Vector3 = thief.global_position + Vector3(0.0, 0.9, 0.0)
	var guard_eyes: Vector3 = global_position + Vector3(0.0, 1.5, 0.0)

	# 1. Chequeo por radio de proximidad inmediata (1.8m)
	if guard_eyes.distance_to(thief_torso) <= 1.8:
		if _has_line_of_sight(space_state, guard_eyes, thief_torso):
			return true

	# 2. Chequeo dentro del cono de la linterna Maglite
	if maglite_light != null and maglite_light.visible:
		var light_origin: Vector3 = maglite_light.global_position
		var light_forward: Vector3 = -maglite_light.global_transform.basis.z.normalized()
		var dir_to_thief: Vector3 = (thief_torso - light_origin).normalized()
		var spot_range: float = maglite_light.spot_range
		var spot_half_angle: float = deg_to_rad(maglite_light.spot_angle)

		if light_origin.distance_to(thief_torso) <= spot_range:
			if light_forward.angle_to(dir_to_thief) <= spot_half_angle:
				if _has_line_of_sight(space_state, light_origin, thief_torso):
					return true

	return false

func _has_line_of_sight(space_state: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1 # Solo colisiona con el entorno
	var result: Dictionary = space_state.intersect_ray(query)
	return result.is_empty()

## Ejecuta un golpe con la porra de madera
func swing_baton(target_thief: ThiefController3D = null) -> bool:
	if baton_cooldown > 0.0:
		return false

	baton_cooldown = BATON_COOLDOWN_TIME
	var bus: Node = get_node_or_null("/root/SignalBus")
	if bus != null:
		bus.emit_signal("noise_emitted_3d", global_position, 4.5, &"guard")

	if target_thief != null and global_position.distance_to(target_thief.global_position) <= melee_range:
		var is_captured: bool = true
		if target_thief.has_method("register_baton_hit"):
			is_captured = target_thief.register_baton_hit()
		if is_captured:
			_capture_thief()
		return true

	return false

func _capture_thief() -> void:
	var bus: Node = get_node_or_null("/root/SignalBus")
	if bus != null:
		var p_id: int = 1
		if multiplayer != null and multiplayer.has_multiplayer_peer():
			p_id = multiplayer.get_unique_id()
		bus.emit_signal("thief_captured", p_id)
		bus.emit_signal("noise_emitted_3d", global_position, 8.0, &"guard")

## Propiedad de conveniencia para que el HUD consulte el interactuable enfocado
var focused_interactive: Node3D:
	get:
		return interactor.current_target if interactor != null else null
