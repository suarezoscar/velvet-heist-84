## @file cctv_desk_3d.gd
## Mesa de monitores de la garita (interaction.md M1, M2b, M4 y M5): un guardia (o el ladrón)
## que interactúa se sienta a mirar las cámaras; solo cabe uno. Se ve una cámara cada vez, que
## se pasa con ← → (step) y se queda donde la dejan (#118). Solo la cámara en pantalla enciende
## su piloto (desde que mira, no mientras se sienta) y solo ella detecta, y solo si mira un
## guardia despierto y ya pasó la nieve del cambio. El servidor decide quién la ocupa y qué
## cámara sale; los clientes reciben el índice.
class_name CCTVDesk3D
extends Area3D

## Altura (m) del punto al que mira el guardia sentado: las pantallas
const LOOK_HEIGHT: float = 1.0
const RULES: CCTVRules = preload("res://data/balance/cctv_rules.tres")

## Guardia sentado, o null (solo en el servidor o sin red)
var watcher: PlayerBase3D = null

## Cámara en pantalla: índice en cameras() (orden de camera_id); CAM 01 al empezar
var current: int = 0

var _occupied: bool = false
var _switch_left: float = 0.0
var _cameras: Array[SecurityCamera3D] = []


func _ready() -> void:
	add_to_group(&"net_state")
	add_to_group(&"cctv_desk")


## La mesa del mapa de tree (hay una), o null
static func of(tree: SceneTree) -> CCTVDesk3D:
	return tree.get_first_node_in_group(&"cctv_desk") as CCTVDesk3D if tree != null else null


## Las cámaras del nivel en el orden en que se pasan (por camera_id: CAM-01, CAM-02…)
func cameras() -> Array[SecurityCamera3D]:
	if _cameras.is_empty() and is_inside_tree():
		_cameras.assign(get_tree().get_nodes_in_group(&"security_camera"))
		_cameras.sort_custom(
			func(a: SecurityCamera3D, b: SecurityCamera3D) -> bool:
				return a.camera_id.naturalnocasecmp_to(b.camera_id) < 0
		)
	return _cameras


## La cámara en pantalla (aunque no haya nadie sentado), o null si el nivel no tiene
func on_screen() -> SecurityCamera3D:
	var list: Array[SecurityCamera3D] = cameras()
	return list[current] if current < list.size() else null


## Pasa a la cámara anterior (dir -1) o a la siguiente (+1), en bucle (M2b). Solo el servidor
## y solo con alguien sentado; la nueva no detecta durante switch_time (nieve)
func step(dir: int) -> void:
	var count: int = cameras().size()
	if watcher == null or count == 0 or dir == 0 or not GameManager.is_simulating():
		return
	current = posmod(current + signi(dir), count)
	_switch_left = RULES.switch_time
	_sync_cameras()


func _physics_process(delta: float) -> void:
	if not GameManager.is_simulating():
		return
	_switch_left = maxf(0.0, _switch_left - delta)
	_sync_cameras()


## true si un guardia la ocupa (en los clientes, según el estado replicado)
func is_occupied() -> bool:
	return _occupied


## Punto al que mira el guardia sentado
func look_point() -> Vector3:
	return global_position + Vector3(0.0, LOOK_HEIGHT, 0.0)


## Contrato de interacción: los guardias y el ladrón (FEAT-042)
func can_interact(actor: Node3D = null) -> bool:
	return actor is GuardController3D or actor is ThiefController3D


## Texto del prompt según quién mira
func get_interaction_text(actor: Node3D = null) -> String:
	var viewer: PlayerBase3D = actor as PlayerBase3D
	if viewer != null and viewer.call(&"is_watching_monitors"):
		return "Dejar los monitores [E]"
	if _occupied:
		return "Monitores ocupados"
	return "Mirar los monitores [E]"


## El guardia se sienta si la mesa está libre (el servidor ya validó el alcance)
func interact(actor: Node3D) -> void:
	var guard: PlayerBase3D = actor as PlayerBase3D
	if not can_interact(actor) or guard == null or (watcher != null and watcher != guard):
		return
	if guard == watcher:
		guard.call(&"stop_watching")
		return
	if GameManager.current_state != GameManager.MatchState.IN_PROGRESS:
		return
	watcher = guard
	_set_occupied(true)
	(guard.get(&"monitor_watch") as GuardMonitorWatch).start(self)


## Ya mira (tras sentarse): la cámara en pantalla enciende su piloto (M4)
func notify_watching(guard: PlayerBase3D) -> void:
	if watcher == guard:
		_sync_cameras()


## El guardia se levanta (lo llama GuardController3D.stop_watching)
func release(guard: PlayerBase3D) -> void:
	if watcher != guard:
		return
	watcher = null
	_set_occupied(false)
	_sync_cameras()


## Estado público para red
func get_net_state() -> Dictionary:
	return {"occupied": _occupied, "cam": current}


## Aplica el estado replicado
func apply_net_state(state: Dictionary) -> void:
	if state.has("occupied"):
		_set_occupied(bool(state["occupied"]))
	if state.has("cam"):
		current = int(state["cam"])


func _set_occupied(on: bool) -> void:
	_occupied = on


## Servidor: piloto solo en la cámara en pantalla con alguien mirando (M4); detecta solo ella,
## pasada la nieve y con un guardia despierto mirando (M5: el ladrón sentado no da parte)
func _sync_cameras() -> void:
	if not is_inside_tree() or not GameManager.is_simulating():
		return
	var watching: bool = watcher != null and bool(watcher.call(&"is_watching_monitors"))
	var clear: bool = watching and _switch_left <= 0.0
	var guard_eyes: bool = GuardSleep.sees_cameras(watcher as GuardController3D)
	var list: Array[SecurityCamera3D] = cameras()
	for i: int in range(list.size()):
		var shown: bool = watching and i == current
		if list[i].is_recording != shown:
			list[i].set_recording(shown)
		list[i].on_screen = shown and clear
		list[i].is_live = shown and clear and guard_eyes
