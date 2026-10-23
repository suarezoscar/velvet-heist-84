## Área de interacción física que delega las acciones del jugador en la lámpara asociada.
## Permite enfocar y manipular la bombilla a través del componente Interactor3D.
class_name LampInteractionArea
extends Area3D

## Referencia a la lámpara que gestiona la bombilla.
@export var lamp: Lamp3D


## Determina si el actor puede interactuar con la lámpara.
func can_interact(actor: Node3D) -> bool:
	if lamp == null:
		return false
	return lamp.can_interact(actor)


## Inicia la acción física sobre la bombilla delegando en la lámpara.
func interact(actor: Node3D) -> void:
	if lamp != null:
		lamp.interact(actor)


## Devuelve el texto descriptivo para el HUD delegando en la lámpara.
func get_interaction_text(actor: Node3D = null) -> String:
	if lamp == null:
		return ""
	return lamp.get_interaction_text(actor)
