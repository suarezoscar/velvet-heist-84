## @file coffee_machine_3d.gd
## La cafetera de la garita (heist.md R5): un guardia humano con E se sirve un café que le
## quita el sueño. Suena (categoría «coffee», radio RULES.coffee_radius): el ladrón sabe que
## alguien ha dejado su puesto. El modelo es el carrito de café de Poly Haven (coffee_cart.glb).
## El ladrón puede echar un somnífero (E, RULES.drug_time s, en silencio): el siguiente guardia
## que se sirva café cae dormido (heist.md R5b). Solo el ladrón sabe si la cafetera está drogada.
class_name CoffeeMachine3D
extends Area3D

const RULES: GuardSleepRules = preload("res://data/balance/guard_sleep.tres")
const HEIST_RULES: HeistRules = preload("res://data/balance/heist_rules.tres")

## El próximo café está drogado
var drugged: bool = false
## Dosis de somnífero que le quedan al ladrón
var doses_left: int = RULES.drug_doses
var _task: TimedTask = null


func _ready() -> void:
	add_to_group(&"coffee_machine")
	add_to_group(&"net_state")


func _physics_process(delta: float) -> void:
	if _task != null and _task.tick(delta):
		_task = null


func can_interact(actor: Node3D = null) -> bool:
	if actor is ThiefController3D:
		return _task == null and not drugged and doses_left > 0
	var sleep: GuardSleep = _sleep_of(actor)
	return sleep != null and sleep.drinking_left <= 0.0


func get_interaction_text(actor: Node3D = null) -> String:
	if actor is ThiefController3D:
		if _task != null:
			return "Echando el somnífero…"
		if drugged:
			return "El café ya lleva somnífero"
		return "Echar somnífero al café [E]" if doses_left > 0 else "No te queda somnífero"
	var sleep: GuardSleep = _sleep_of(actor)
	if sleep != null and sleep.drinking_left > 0.0:
		return "Sirviendo café…"
	return "Tomar un café [E]"


func interact(actor: Node3D) -> void:
	if not can_interact(actor):
		return
	if actor is ThiefController3D:
		_task = TimedTask.start(actor, RULES.drug_time, HEIST_RULES.task_leash, _finish_drug)
		return
	var sleep: GuardSleep = _sleep_of(actor)
	if sleep != null and sleep.start_coffee(self):
		NoiseEmit.emit(global_position, RULES.coffee_radius, &"guard", &"coffee", actor)


## El café de un guardia ha terminado: true si estaba drogado (y la cafetera queda limpia)
func take_cup() -> bool:
	var was_drugged: bool = drugged
	drugged = false
	return was_drugged


func _finish_drug(_actor: Node3D) -> void:
	if drugged or doses_left <= 0:
		return
	doses_left -= 1
	drugged = true
	print("[CoffeeMachine3D] Somnífero en la cafetera")


func get_net_state() -> Dictionary:
	return {}


## Solo al ladrón: si la ha drogado y cuántas dosis le quedan
func get_net_state_private() -> Dictionary:
	return {"drugged": drugged, "doses": doses_left}


func net_private_audience() -> StringName:
	return &"thief"


func apply_net_state(state: Dictionary) -> void:
	drugged = bool(state.get("drugged", drugged))
	doses_left = int(state.get("doses", doses_left))


static func _sleep_of(actor: Node3D) -> GuardSleep:
	if not (actor is GuardController3D):
		return null
	return actor.get_node_or_null("Sleep") as GuardSleep
