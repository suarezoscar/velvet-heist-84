## @file escape_car_3d.gd
## Coche de huida de 1984 que delimita la zona de extracción del Ladrón.
## Permite depositar botín pesado en el maletero y arrancar el motor para ganar
## la partida una vez alcanzada la cuota monetaria ($10.000) y la Pieza Maestra.
class_name EscapeCar3D
extends Area3D

## Emitida cuando el ladrón cumple las condiciones y escapa en el vehículo
signal escape_succeeded

const PROMPT_DEPOSIT: String = "Dejar el botín en el maletero [E]"
const PROMPT_ESCAPE: String = "¡Arrancar y escapar! [E]"
const PROMPT_LOCKED: String = "Escape bloqueado: Requiere $10.000 y Pieza Maestra"

var is_escaped: bool = false


func _ready() -> void:
	add_to_group(&"net_state")
	collision_layer = 4
	collision_mask = 2
	monitoring = true


## Solo el ladrón puede interactuar con el coche de fuga
func can_interact(actor: Node3D = null) -> bool:
	return actor is ThiefController3D


## Devuelve el texto contextual según si el ladrón lleva botín o puede huir
func get_interaction_text(actor: Node3D = null) -> String:
	if actor is ThiefController3D:
		var thief: ThiefController3D = actor as ThiefController3D
		if thief.is_carrying_heavy_loot and thief.carried_loot != null:
			return PROMPT_DEPOSIT
	if GameManager.has_method("can_thief_escape") and GameManager.can_thief_escape():
		return PROMPT_ESCAPE
	return PROMPT_LOCKED


## Procesa la interacción: o deposita botín en maletero o arranca el coche
func interact(actor: Node3D) -> void:
	if not actor is ThiefController3D:
		return
	var thief: ThiefController3D = actor as ThiefController3D
	if thief.is_carrying_heavy_loot and thief.carried_loot != null:
		if thief.carried_loot.has_method("deposit_into_trunk"):
			thief.carried_loot.call("deposit_into_trunk", global_position)
		return
	if GameManager.has_method("can_thief_escape") and GameManager.can_thief_escape():
		_execute_escape()


func _execute_escape() -> void:
	is_escaped = true
	print("[EscapeCar3D] ¡El ladrón ha arrancado el motor y escapa con éxito!")
	escape_succeeded.emit()
	if GameManager.has_method("end_match"):
		GameManager.end_match(GameManager.MatchState.THIEF_ESCAPED)
	NoiseEmit.emit(global_position, 16.0, &"thief", NoiseEmit.MECHANISM, self)


## Devuelve el snapshot de estado del coche de fuga para red
func get_net_state() -> Dictionary:
	return {
		"escaped": is_escaped,
	}


## Aplica el snapshot de estado recibido por red
func apply_net_state(state: Dictionary) -> void:
	if state.has("escaped"):
		is_escaped = bool(state["escaped"])
