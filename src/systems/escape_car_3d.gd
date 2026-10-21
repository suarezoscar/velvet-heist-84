## @file escape_car_3d.gd
## Coche de huida de 1984 que delimita la zona de extracción del Ladrón.
## Permite depositar botín pesado en el maletero y arrancar el motor para ganar
## la partida una vez alcanzada la cuota monetaria ($10.000) y la Pieza Maestra.
class_name EscapeCar3D
extends Area3D

## Emitida cuando el ladrón cumple las condiciones y escapa en el vehículo
signal escape_succeeded()

const PROMPT_DEPOSIT: String = "Depositar Botin en el Maletero [E]"
const PROMPT_ESCAPE: String = "¡ARRANCAR Y ESCAPAR! [E]"
const PROMPT_LOCKED: String = "Escape bloqueado: Requiere $10.000 y Pieza Maestra"

func _ready() -> void:
	collision_layer = 4 # Interactuable
	collision_mask = 2  # Ladrón
	monitoring = true

## Solo el ladrón puede interactuar con el coche de fuga
func can_interact(actor: Node3D) -> bool:
	return actor is ThiefController3D

## Devuelve el texto contextual según si el ladrón lleva botín o puede huir
func get_interaction_text(actor: Node3D = null) -> String:
	if actor is ThiefController3D:
		var thief: ThiefController3D = actor as ThiefController3D
		if thief.is_carrying_heavy_loot and thief.carried_loot != null:
			return PROMPT_DEPOSIT

	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("can_thief_escape"):
		if bool(gm.call("can_thief_escape")):
			return PROMPT_ESCAPE

	return PROMPT_LOCKED

## Procesa la interacción: o deposita botín en maletero o arranca el coche
func interact(actor: Node3D) -> void:
	if not (actor is ThiefController3D):
		return

	var thief: ThiefController3D = actor as ThiefController3D

	# 1. Si sostiene botín pesado, lo deposita primero en el maletero
	if thief.is_carrying_heavy_loot and thief.carried_loot != null:
		if thief.carried_loot.has_method("deposit_into_trunk"):
			thief.carried_loot.call("deposit_into_trunk", global_position)
		return

	# 2. Si las manos están libres, comprueba si puede escapar
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("can_thief_escape"):
		if bool(gm.call("can_thief_escape")):
			_execute_escape(gm)

func _execute_escape(gm: Node) -> void:
	print("[EscapeCar3D] ¡El ladrón ha arrancado el motor y escapa con éxito!")
	escape_succeeded.emit()

	if gm.has_method("end_match"):
		gm.call("end_match", 2) # 2 = MatchState.THIEF_ESCAPED

	var bus: Node = get_node_or_null("/root/SignalBus")
	if bus != null:
		# Ruido estridente del motor acelerando y chirrido de neumáticos
		bus.emit_signal("noise_emitted_3d", global_position, 16.0, &"thief")
