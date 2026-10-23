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
	if rules == null:
		rules = load(LIGHT_RULES_PATH) as LightRulesProfile
	bulb = get_node_or_null("Visuals/Bulb") as OmniLight3D
	_interaction_area = get_node_or_null("Sensors/InteractionArea") as Area3D
	if _interaction_area != null:
		var script_area: GDScript = GDScript.new()
		script_area.source_code = """@tool
extends Area3D
var lamp: Node3D = null

func can_interact(actor: Node3D) -> bool:
	return lamp.can_interact(actor) if lamp != null else false

func interact(actor: Node3D) -> void:
	if lamp != null:
		lamp.interact(actor)

func get_interaction_text(actor: Node3D = null) -> String:
	return lamp.get_interaction_text(actor) if lamp != null else ""
"""
		script_area.reload()
		_interaction_area.set_script(script_area)
		_interaction_area.set("lamp", self)

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
		SignalBus.noise_emitted_3d.emit(global_position, rules.unscrew_noise_radius, player.team_id)
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
	if actor == null or actor.interactor == null:
		return false
	var target: Node3D = actor.interactor.current_target
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
