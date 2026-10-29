## @file cctv_desk_3d.gd
## Mesa de monitores de la garita (interaction.md M1 y M4): un guardia que interactúa
## se sienta a mirar las cámaras; solo cabe uno. Mientras está ocupada, las cámaras
## encienden su piloto de grabación (desde que mira, no mientras se sienta). El servidor
## decide quién la ocupa.
class_name CCTVDesk3D
extends Area3D

## Altura (m) del punto al que mira el guardia sentado: las pantallas
const LOOK_HEIGHT: float = 1.0

## Guardia sentado, o null (solo en el servidor o sin red)
var watcher: GuardController3D = null

var _occupied: bool = false


func _ready() -> void:
	add_to_group(&"net_state")
	add_to_group(&"cctv_desk")


## true si un guardia la ocupa (en los clientes, según el estado replicado)
func is_occupied() -> bool:
	return _occupied


## Punto al que mira el guardia sentado
func look_point() -> Vector3:
	return global_position + Vector3(0.0, LOOK_HEIGHT, 0.0)


## Contrato de interacción: solo los guardias
func can_interact(actor: Node3D = null) -> bool:
	return actor is GuardController3D


## Texto del prompt según quién mira
func get_interaction_text(actor: Node3D = null) -> String:
	var guard: GuardController3D = actor as GuardController3D
	if guard != null and guard.is_watching_monitors():
		return "Dejar los monitores [E]"
	if _occupied:
		return "Monitores ocupados"
	return "Mirar los monitores [E]"


## El guardia se sienta si la mesa está libre (el servidor ya validó el alcance)
func interact(actor: Node3D) -> void:
	var guard: GuardController3D = actor as GuardController3D
	if guard == null or (watcher != null and watcher != guard):
		return
	if guard == watcher:
		guard.stop_watching()
		return
	if GameManager.current_state != GameManager.MatchState.IN_PROGRESS:
		return
	watcher = guard
	_set_occupied(true)
	guard.monitor_watch.start(self)


## El guardia ya mira (tras sentarse): las cámaras encienden su piloto (M4)
func notify_watching(guard: GuardController3D) -> void:
	if watcher == guard:
		_set_recording(true)


## El guardia se levanta (lo llama GuardController3D.stop_watching)
func release(guard: GuardController3D) -> void:
	if watcher != guard:
		return
	watcher = null
	_set_occupied(false)
	_set_recording(false)


## Estado público para red
func get_net_state() -> Dictionary:
	return {"occupied": _occupied}


## Aplica el estado replicado
func apply_net_state(state: Dictionary) -> void:
	if state.has("occupied"):
		_set_occupied(bool(state["occupied"]))


func _set_occupied(on: bool) -> void:
	_occupied = on


func _set_recording(on: bool) -> void:
	if not is_inside_tree() or not GameManager.is_simulating():
		return
	for node: Node in get_tree().get_nodes_in_group(&"security_camera"):
		(node as SecurityCamera3D).set_recording(on)
