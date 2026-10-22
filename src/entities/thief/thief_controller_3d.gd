## @file thief_controller_3d.gd
## Controlador específico del Ladrón de guante blanco.
## Gestiona la alta movilidad, el transporte de botín pesado, el ancla de manos
## y la interacción física mediante el componente Interactor3D.
class_name ThiefController3D
extends PlayerBase3D

## Factor multiplicador de velocidad al cargar botín pesado (-20% según GSD 4.3)
const HEAVY_LOOT_SPEED_MULTIPLIER: float = 0.8

## Número de impactos de porra necesarios para ser capturado (GSD regla de neutralización)
const REQUIRED_HITS_TO_CAPTURE: int = 2

## Cámara isométrica activa para la proyección del cursor
@export var camera: Camera3D

## Nodo raíz visual del personaje (oculto para guardias fuera de visión)
@export var visual_root: Node3D

## Ancla visual en las manos del ladrón para objetos transportados
var carry_anchor: Node3D = null

## Referencia al botín pesado que actualmente se sostiene
var carried_loot: Node3D = null

## Bandera de penalización por peso (-20% de velocidad)
var is_carrying_heavy_loot: bool = false

## Impactos de porra recibidos
var baton_hits_taken: int = 0

## Estado de detección por parte de guardias
var is_detected_by_guard: bool = false

## Componente modular de interacción
var interactor: Interactor3D = null

func _ready() -> void:
	super._ready()
	team_id = &"thief"
	move_speed = 5.0
	sprint_speed = 7.5
	sneak_speed = 2.4

	_setup_carry_anchor()
	_setup_interactor()

func _setup_carry_anchor() -> void:
	carry_anchor = get_node_or_null("CarryAnchor3D") as Node3D
	if carry_anchor == null:
		carry_anchor = Node3D.new()
		carry_anchor.name = "CarryAnchor3D"
		carry_anchor.position = Vector3(0.0, 0.85, 0.45)
		add_child(carry_anchor)
	else:
		carry_anchor.position = Vector3(0.0, 0.85, 0.45)

func _setup_interactor() -> void:
	interactor = Interactor3D.new()
	interactor.name = "ThiefInteractor"
	interactor.reach_distance = 1.8
	add_child(interactor)

func _physics_process(delta: float) -> void:
	if multiplayer.multiplayer_peer != null and not is_multiplayer_authority():
		update_presentation(delta)
		return

	var input_data: Dictionary = gather_input(camera)
	apply_input(input_data)
	simulate_movement(delta)
	update_presentation(delta)
	_handle_interaction_input()

## Simulación física del ladrón con penalización autoritativa por botín pesado
func simulate_movement(delta: float) -> void:
	super.simulate_movement(delta)
	if is_carrying_heavy_loot:
		velocity.x *= HEAVY_LOOT_SPEED_MULTIPLIER
		velocity.z *= HEAVY_LOOT_SPEED_MULTIPLIER

func _handle_interaction_input() -> void:
	var interact_pressed: bool = Input.is_action_just_pressed("interact") if InputMap.has_action("interact") else false
	if interact_pressed and interactor != null:
		interactor.execute_interaction(self)

## Sujeta físicamente un botín pesado en las manos del ladrón
func carry_heavy_loot(loot: Node3D) -> void:
	carried_loot = loot
	is_carrying_heavy_loot = true

## Suelta o deposita el botín pesado, restaurando la velocidad normal
func drop_heavy_loot() -> void:
	carried_loot = null
	is_carrying_heavy_loot = false

## Determina si el ladrón puede utilizar gadgets (bloqueado mientras carga botín pesado según GSD 4.3)
func can_use_gadgets() -> bool:
	return not is_carrying_heavy_loot

## Registra de forma autoritativa un impacto recibido de porra.
## Devuelve true si el ladrón ha sido neutralizado (2 impactos)
func register_baton_hit() -> bool:
	baton_hits_taken += 1
	return baton_hits_taken >= REQUIRED_HITS_TO_CAPTURE

## Reinicia los impactos de porra acumulados
func reset_baton_hits() -> void:
	baton_hits_taken = 0

## Actualiza la visibilidad autoritativa del ladrón frente a los guardias
func set_stealth_visibility(is_visible_to_guards: bool) -> void:
	is_detected_by_guard = is_visible_to_guards
	# El jugador local siempre ve a su propio ladrón en vista isométrica
	if visual_root != null:
		visual_root.visible = true

## Consulta autoritativa: si un equipo concreto puede ver al ladrón
func is_visible_to_team(team: StringName) -> bool:
	if team == &"thief":
		return true
	return is_detected_by_guard

## Propiedad de conveniencia para que el HUD consulte el interactuable enfocado
var focused_interactive: Node3D:
	get:
		return interactor.current_target if interactor != null else null
