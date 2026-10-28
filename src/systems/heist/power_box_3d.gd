## @file power_box_3d.gd
## Cuadro eléctrico de alarma de un ala (heist.md R9). El ladrón corta la corriente (E,
## RULES.cut_time): las piezas de sensor del ala se cogen sin alarma y sus lámparas se apagan.
## En la garita se enciende el piloto del ala (PilotPanel3D). Un guardia la restablece (E,
## RULES.restore_time) y las lámparas vuelven a como estaban.
class_name PowerBox3D
extends Area3D

const RULES: HeistRules = preload("res://data/balance/heist_rules.tres")
const BOX_SIZE: Vector3 = Vector3(0.6, 0.9, 0.25)
const BOX_HEIGHT: float = 1.3

var wing_id: StringName = &""
var wing_name: String = ""
var circuits: Array[int] = []
## Salas del ala en el plano del mundo (x, z)
var areas: Array[Rect2] = []
var is_cut: bool = false
## Los guardias ya saben del corte (cuenta como rastro, AlertDirector)
var noticed: bool = false
var _task: TimedTask = null
var _saved: Dictionary = {}


static func create(id: StringName, display_name: String, wing_circuits: Array[int]) -> PowerBox3D:
	var box: PowerBox3D = PowerBox3D.new()
	box.name = "PowerBox_%s" % id
	box.wing_id = id
	box.wing_name = display_name
	box.circuits = wing_circuits
	box.collision_layer = 4
	box.collision_mask = 2
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = BOX_SIZE + Vector3(0.6, 0.6, 0.8)
	var col: CollisionShape3D = CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0.0, BOX_HEIGHT, 0.0)
	box.add_child(col)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = BOX_SIZE
	mesh.mesh = box_mesh
	mesh.position = Vector3(0.0, BOX_HEIGHT, 0.0)
	box.add_child(mesh)
	return box


func _ready() -> void:
	add_to_group(&"net_state")
	add_to_group(&"power_boxes")


func _physics_process(delta: float) -> void:
	if _task != null and _task.tick(delta):
		_task = null


## true si el punto (x, z) está en alguna sala del ala
func contains(point: Vector3) -> bool:
	for area: Rect2 in areas:
		if area.has_point(Vector2(point.x, point.z)):
			return true
	return false


func can_interact(actor: Node3D = null) -> bool:
	if _task != null:
		return false
	if actor is ThiefController3D:
		return not is_cut
	return actor is GuardController3D and is_cut


func get_interaction_text(actor: Node3D = null) -> String:
	if _task != null:
		return "Cortando la corriente…" if actor is ThiefController3D else "Restableciendo…"
	if actor is ThiefController3D:
		return "Cortar la alarma de %s [E]" % wing_name
	return "Restablecer la corriente de %s [E]" % wing_name


func interact(actor: Node3D) -> void:
	if not can_interact(actor):
		return
	var seconds: float = RULES.cut_time if actor is ThiefController3D else RULES.restore_time
	_task = TimedTask.start(actor, seconds, RULES.task_leash, _finish)


## Autoridad: corta o restablece y apaga o devuelve las lámparas del ala
func set_cut(cut: bool) -> void:
	if cut == is_cut:
		return
	is_cut = cut
	for node: Node in get_tree().get_nodes_in_group(&"lamps"):
		var lamp: Lamp3D = node as Lamp3D
		if lamp == null or not circuits.has(lamp.circuit_id):
			continue
		if cut:
			_saved[lamp] = lamp.is_switched_on
			lamp.set_switched(false)
		elif _saved.has(lamp):
			lamp.set_switched(bool(_saved[lamp]))
	if not cut:
		_saved.clear()  # noticed se queda: los guardias ya saben del corte
	NoiseEmit.emit(global_position, 3.0, &"thief" if cut else &"guard", NoiseEmit.MECHANISM, null)
	print("[PowerBox3D] %s: %s" % [wing_name, "corriente cortada" if cut else "restablecida"])


func _finish(actor: Node3D) -> void:
	set_cut(actor is ThiefController3D)


func get_net_state() -> Dictionary:
	return {"cut": is_cut}


func apply_net_state(state: Dictionary) -> void:
	if state.has("cut"):
		is_cut = bool(state["cut"])
