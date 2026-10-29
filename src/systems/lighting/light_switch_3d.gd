## Interruptor de pared que conmuta el estado de las lámparas asignadas a su circuito.
## Gestiona la interacción física mantenida durante switch_time (data/balance/light_rules.tres).
class_name LightSwitch3D
extends StaticBody3D

const LIGHT_RULES_PATH: String = "res://data/balance/light_rules.tres"

@export var circuit_id: int = 0
@export var rules: LightRulesProfile

var _active_actor: PlayerBase3D = null
var _time_left: float = 0.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	if rules == null:
		rules = load(LIGHT_RULES_PATH) as LightRulesProfile


func _physics_process(delta: float) -> void:
	if _active_actor != null:
		if not _is_actor_focusing(_active_actor):
			_active_actor = null
			_time_left = 0.0
			return
		_time_left -= delta
		if _time_left <= 0.0:
			_complete_switch(_active_actor)
			_active_actor = null
			_time_left = 0.0


## Determina si el actor puede accionar el interruptor
func can_interact(actor: Node3D) -> bool:
	if actor == null:
		return false
	var team: StringName = actor.get("team_id") if "team_id" in actor else &""
	return team == &"thief" or team == &"guard"


## Inicia la acción de pulsar el interruptor
func interact(actor: Node3D) -> void:
	if not can_interact(actor) or not (actor is PlayerBase3D):
		return
	if rules == null:
		rules = load(LIGHT_RULES_PATH) as LightRulesProfile
	_active_actor = actor as PlayerBase3D
	_time_left = rules.switch_time


## Texto descriptivo para la acción en el HUD
func get_interaction_text(_actor: Node3D = null) -> String:
	return "Encender o apagar la luz"


func _complete_switch(actor: PlayerBase3D) -> void:
	if rules == null:
		rules = load(LIGHT_RULES_PATH) as LightRulesProfile
	NoiseEmit.emit(
		global_position, rules.switch_noise_radius, actor.team_id, NoiseEmit.MECHANISM, actor
	)

	var circuit_lamps: Array[Lamp3D] = []
	for node: Node in get_tree().get_nodes_in_group(&"lamps"):
		var lamp: Lamp3D = node as Lamp3D
		if lamp != null and lamp.circuit_id == circuit_id:
			if lamp.profile != null and lamp.profile.has_switch:
				circuit_lamps.append(lamp)

	var any_lit: bool = false
	for lamp: Lamp3D in circuit_lamps:
		if lamp.is_switched_on:
			any_lit = true
			break

	var target_state: bool = not any_lit
	for lamp: Lamp3D in circuit_lamps:
		lamp.set_switched(target_state)


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
	return interactor.current_target == self
