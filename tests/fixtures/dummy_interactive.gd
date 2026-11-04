## @file dummy_interactive.gd
## Interactuable mínimo para los tests del Interactor3D: un Area3D de la capa 4 que acepta
## cualquier interacción y no hace nada.
class_name DummyInteractive
extends Area3D


func _ready() -> void:
	collision_layer = 4  # Interactuable
	collision_mask = 1


func can_interact(_actor: Node3D = null) -> bool:
	return true


func interact(_actor: Node3D) -> void:
	pass
