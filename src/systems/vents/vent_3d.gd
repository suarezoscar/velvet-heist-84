## @file vent_3d.gd
## Rejilla de ventilación (FEAT-034, heist.md R10). Solo el ladrón se cuela (E,
## RULES.enter_time, con un ruido metálico) y elige por dónde salir en VentTravel. Una rejilla
## usada se queda abierta RULES.open_time s: es un rastro que un guardia cierra con E.
## Va pegada a la pared, a ras de suelo; como los cuadros, su frente mira a -Z (hacia la sala).
class_name Vent3D
extends Area3D

const RULES: VentRules = preload("res://data/balance/vent_rules.tres")
const HEIST_RULES: HeistRules = preload("res://data/balance/heist_rules.tres")
const GRILLE_SIZE: Vector3 = Vector3(0.8, 0.5, 0.05)
const WALL_FACE: float = 0.17
## Distancia (m) delante de la rejilla a la que sale el ladrón
const EXIT_DISTANCE: float = 0.8
const CLOSED_COLOR: Color = Color(0.55, 0.57, 0.6)
const OPEN_COLOR: Color = Color(0.05, 0.05, 0.06)

var vent_id: String = ""
var network: String = ""
var room_name: String = ""
## Segundos que le quedan abierta (0: cerrada)
var open_left: float = 0.0
var _grille: MeshInstance3D = null
var _task: TimedTask = null


static func create(id: String, network_id: String, room: String) -> Vent3D:
	var vent: Vent3D = Vent3D.new()
	vent.name = "Vent_%s" % id
	vent.vent_id = id
	vent.network = network_id
	vent.room_name = room
	vent.collision_layer = LevelEntitiesBuilder.INTERACTABLE_LAYER
	vent.collision_mask = LevelEntitiesBuilder.INTERACTOR_MASK
	var reach: BoxShape3D = BoxShape3D.new()
	reach.size = Vector3(1.2, 1.2, 1.4)
	var col: CollisionShape3D = CollisionShape3D.new()
	col.shape = reach
	col.position = Vector3(0.0, 0.6, -0.7)
	vent.add_child(col)
	vent._grille = MeshInstance3D.new()
	vent._grille.name = "Grille"
	var box: BoxMesh = BoxMesh.new()
	box.size = GRILLE_SIZE
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = CLOSED_COLOR
	mat.metallic = 0.6
	mat.roughness = 0.4
	box.material = mat
	vent._grille.mesh = box
	vent._grille.position = Vector3(0.0, GRILLE_SIZE.y * 0.5 + 0.05, -WALL_FACE)
	vent.add_child(vent._grille)
	return vent


func _ready() -> void:
	add_to_group(&"net_state")
	add_to_group(&"vents")


func _physics_process(delta: float) -> void:
	if _task != null and _task.tick(delta):
		_task = null
	if open_left > 0.0 and GameManager.is_simulating():
		open_left = maxf(0.0, open_left - delta)
		_update_look()


## Dónde aparece quien sale por esta rejilla
func exit_point() -> Vector3:
	return global_position + global_transform.basis * Vector3(0.0, 0.0, -EXIT_DISTANCE)


func can_interact(actor: Node3D = null) -> bool:
	if actor is GuardController3D:
		return open_left > 0.0
	var travel: VentTravel = VentTravel.of(get_tree())
	if not (actor is ThiefController3D) or travel == null:
		return false
	if travel.phase == VentTravel.Phase.CHOOSING:
		return travel.entry == self
	return _task == null and travel.phase == VentTravel.Phase.NONE


func get_interaction_text(actor: Node3D = null) -> String:
	if actor is GuardController3D:
		return "Cerrar la rejilla de ventilación [E]"
	var travel: VentTravel = VentTravel.of(get_tree())
	if travel != null and travel.phase == VentTravel.Phase.CHOOSING and travel.entry == self:
		return travel.choice_text()
	if _task != null:
		return "Colándote en el conducto…"
	return "Colarse por la ventilación [E]"


func interact(actor: Node3D) -> void:
	if not can_interact(actor):
		return
	if actor is GuardController3D:
		open_left = 0.0
		_update_look()
		return
	var travel: VentTravel = VentTravel.of(get_tree())
	if travel.phase == VentTravel.Phase.CHOOSING:
		travel.go()
		return
	NoiseEmit.emit(global_position, RULES.hatch_radius, &"thief", NoiseEmit.MECHANISM, actor)
	_task = TimedTask.start(actor, RULES.enter_time, HEIST_RULES.task_leash, _finish_enter)


## Autoridad: la rejilla queda abierta un rato
func mark_open() -> void:
	open_left = RULES.open_time
	_update_look()


func _finish_enter(actor: Node3D) -> void:
	var travel: VentTravel = VentTravel.of(get_tree())
	if travel != null:
		travel.enter(actor as ThiefController3D, self)


func _update_look() -> void:
	if _grille != null:
		var mat: StandardMaterial3D = (_grille.mesh as BoxMesh).material as StandardMaterial3D
		mat.albedo_color = OPEN_COLOR if open_left > 0.0 else CLOSED_COLOR


func get_net_state() -> Dictionary:
	return {"open": open_left > 0.0}


func apply_net_state(state: Dictionary) -> void:
	if state.has("open"):
		open_left = RULES.open_time if bool(state["open"]) else 0.0
		_update_look()
