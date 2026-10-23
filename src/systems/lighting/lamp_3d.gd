## Entidad de lámpara que ilumina el entorno y permite manipulación de bombilla.
## Soporta conmutación por circuito de interruptores y desenroscado con foco mantenido.
class_name Lamp3D
extends Node3D

signal lit_changed(is_lit: bool)

const LIGHT_RULES_PATH: String = "res://data/balance/light_rules.tres"

@export var profile: LampProfile
@export var circuit_id: int = 0
@export var start_on: bool = true
@export var rules: LightRulesProfile

var is_switched_on: bool = true
var is_unscrewed: bool = false
var bulb: OmniLight3D = null

var _was_lit: bool = false
var _active_actor: PlayerBase3D = null
var _time_left: float = 0.0
var _is_unscrewing: bool = true
var _interaction_area: Area3D = null


func _ready() -> void:
	add_to_group(&"lamps")
	add_to_group(&"net_state")
	if rules == null:
		rules = load(LIGHT_RULES_PATH) as LightRulesProfile
	bulb = get_node_or_null("Visuals/Bulb") as OmniLight3D
	_interaction_area = get_node_or_null("Sensors/InteractionArea") as Area3D
	if _interaction_area != null:
		if profile == null or not profile.unscrewable:
			_interaction_area.collision_layer = 0
		if _interaction_area is LampInteractionArea:
			(_interaction_area as LampInteractionArea).lamp = self

	is_switched_on = start_on
	_was_lit = is_lit()
	_apply_bulb_properties()


func _physics_process(delta: float) -> void:
	if _active_actor != null:
		if not _is_actor_focusing(_active_actor):
			_active_actor = null
			_time_left = 0.0
			return
		_time_left -= delta
		if _time_left <= 0.0:
			_complete_interaction()


## Devuelve true si la lámpara emite luz en este momento
func is_lit() -> bool:
	return is_switched_on and not is_unscrewed


## Conmuta el estado de encendido del circuito para esta lámpara
func set_switched(on: bool) -> void:
	if is_switched_on == on:
		return
	is_switched_on = on
	_update_bulb()


## Devuelve el snapshot de estado de la lámpara para red
func get_net_state() -> Dictionary:
	return {
		"switched_on": is_switched_on,
		"unscrewed": is_unscrewed,
	}


## Aplica el snapshot de estado recibido por red
func apply_net_state(state: Dictionary) -> void:
	if state.has("switched_on"):
		is_switched_on = bool(state["switched_on"])
	if state.has("unscrewed"):
		is_unscrewed = bool(state["unscrewed"])
	_update_bulb()


## Determina si el actor puede desenroscar o enroscar la bombilla
func can_interact(actor: Node3D) -> bool:
	if actor == null or profile == null or not profile.unscrewable:
		return false
	var team: StringName = actor.get("team_id") if "team_id" in actor else &""
	if team == &"thief":
		return not is_unscrewed
	if team == &"guard":
		return is_unscrewed
	return false


## Inicia el proceso de interacción con la bombilla (desenroscar o enroscar)
func interact(actor: Node3D) -> void:
	if not can_interact(actor) or not (actor is PlayerBase3D):
		return
	if rules == null:
		rules = load(LIGHT_RULES_PATH) as LightRulesProfile
	var player: PlayerBase3D = actor as PlayerBase3D
	_active_actor = player
	if player.team_id == &"thief":
		_is_unscrewing = true
		_time_left = rules.unscrew_time
		NoiseEmit.emit(
			global_position, rules.unscrew_noise_radius, player.team_id, NoiseEmit.MECHANISM, player
		)
	else:
		_is_unscrewing = false
		_time_left = rules.rescrew_time


## Texto descriptivo para la acción en el HUD
func get_interaction_text(actor: Node3D = null) -> String:
	var team: StringName = actor.get("team_id") if actor != null and "team_id" in actor else &""
	if team == &"guard":
		return "Enroscar bombilla"
	return "Desenroscar bombilla"


func _is_actor_focusing(actor: PlayerBase3D) -> bool:
	if actor == null:
		return false
	var interactor: Interactor3D = null
	var thief: ThiefController3D = actor as ThiefController3D
	if thief != null:
		interactor = thief.interactor
	else:
		var guard: GuardController3D = actor as GuardController3D
		if guard != null:
			interactor = guard.interactor
	if interactor == null:
		return false
	var target: Node3D = interactor.current_target
	return target == self or target == _interaction_area


func _complete_interaction() -> void:
	if _is_unscrewing:
		is_unscrewed = true
	else:
		is_unscrewed = false
	_update_bulb()
	_active_actor = null
	_time_left = 0.0


func _update_bulb() -> void:
	var currently_lit: bool = is_lit()
	if bulb != null:
		bulb.visible = currently_lit
	if _was_lit != currently_lit:
		_was_lit = currently_lit
		lit_changed.emit(currently_lit)


func _apply_bulb_properties() -> void:
	if bulb != null and profile != null:
		bulb.omni_range = profile.lit_radius
		bulb.light_color = profile.light_color
		bulb.light_energy = profile.light_energy
		bulb.visible = is_lit()
