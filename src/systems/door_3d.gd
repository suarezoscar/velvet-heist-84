## @file door_3d.gd
## Puerta con hoja (FEAT-034; de momento solo la de la garita). Cerrada tapa el paso y la vista
## (colisiona en la capa de muros, como un muro). Los guardias la abren con E al momento y la IA
## al acercarse; el ladrón fuerza la cerradura en silencio (E, RULES.pick_time). Al abrirse
## cruje (RULES.creak_radius) y se cierra sola a los RULES.auto_close s, cuando el hueco está
## libre. Tiene un ventanuco de cristal esmerilado: deja pasar la luz, no las figuras.
## El servidor (o la partida sin red) decide; los clientes reciben si está abierta.
class_name Door3D
extends Area3D

const RULES: DoorRules = preload("res://data/balance/door_rules.tres")
const HEIST_RULES: HeistRules = preload("res://data/balance/heist_rules.tres")
const LEAF_HEIGHT: float = 2.3
const LEAF_THICKNESS: float = 0.08
const LEAF_COLOR: Color = Color(0.32, 0.2, 0.12)
const GLASS_COLOR: Color = Color(0.85, 0.9, 0.92, 0.55)
## Distancia (m) al centro del hueco a la que alguien impide que se cierre
const DOORWAY_CLEAR: float = 0.9
const OPEN_ANGLE: float = 100.0
## Altura del muro sobre el hueco (el dintel llega hasta ahí)
const LINTEL_TOP: float = 3.2

var is_open: bool = false
var leaf_pivot: Node3D = null
var _leaf_body: StaticBody3D = null
var _open_left: float = 0.0
var _task: TimedTask = null


## Puerta de ancho width que cierra un hueco a lo largo del eje X local (gira en su extremo)
static func create(door_id: String, width: float) -> Door3D:
	var door: Door3D = Door3D.new()
	door.name = "Door_%s" % door_id
	door.collision_layer = LevelEntitiesBuilder.INTERACTABLE_LAYER
	door.collision_mask = LevelEntitiesBuilder.INTERACTOR_MASK
	var reach: BoxShape3D = BoxShape3D.new()
	reach.size = Vector3(width + 0.4, LEAF_HEIGHT, 2.2)
	var reach_col: CollisionShape3D = CollisionShape3D.new()
	reach_col.shape = reach
	reach_col.position = Vector3(0.0, LEAF_HEIGHT * 0.5, 0.0)
	door.add_child(reach_col)
	door.leaf_pivot = Node3D.new()
	door.leaf_pivot.name = "LeafPivot"
	door.leaf_pivot.position = Vector3(-width * 0.5, 0.0, 0.0)
	door.add_child(door.leaf_pivot)
	door._leaf_body = StaticBody3D.new()
	door._leaf_body.name = "Leaf"
	door._leaf_body.collision_layer = (
		LevelArchitectureBuilder.LAYER_WORLD_SOLID | LevelArchitectureBuilder.LAYER_WALLS
	)
	door._leaf_body.collision_mask = 0
	door._leaf_body.position = Vector3(width * 0.5, 0.0, 0.0)
	door.leaf_pivot.add_child(door._leaf_body)
	var leaf_size: Vector3 = Vector3(width, LEAF_HEIGHT, LEAF_THICKNESS)
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = leaf_size
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "CollisionShape3D"
	col.shape = shape
	col.position = Vector3(0.0, LEAF_HEIGHT * 0.5, 0.0)
	door._leaf_body.add_child(col)
	door._leaf_body.add_child(_mesh(leaf_size, Vector3(0.0, LEAF_HEIGHT * 0.5, 0.0), LEAF_COLOR))
	var glass: MeshInstance3D = _mesh(
		Vector3(width * 0.45, 0.45, LEAF_THICKNESS + 0.02), Vector3(0.0, 1.65, 0.0), GLASS_COLOR
	)
	glass.name = "FrostedGlass"
	door._leaf_body.add_child(glass)
	var lintel: MeshInstance3D = MeshInstance3D.new()
	lintel.name = "Lintel"
	var lintel_box: BoxMesh = BoxMesh.new()
	lintel_box.size = Vector3(width, LINTEL_TOP - LEAF_HEIGHT, 0.3)
	lintel_box.material = WallXRay.material(LevelArchitectureBuilder.WALL_COLOR)
	lintel.mesh = lintel_box
	lintel.position = Vector3(0.0, (LINTEL_TOP + LEAF_HEIGHT) * 0.5, 0.0)
	door.add_child(lintel)
	return door


func _ready() -> void:
	add_to_group(&"net_state")
	add_to_group(&"doors")


func _physics_process(delta: float) -> void:
	if _task != null and _task.tick(delta):
		_task = null
	if not GameManager.is_simulating():
		return
	if not is_open and _ai_guard_near():
		set_open(true)
	if is_open:
		_open_left -= delta
		if _open_left <= 0.0 and not _doorway_busy():
			set_open(false)


func can_interact(actor: Node3D = null) -> bool:
	if _task != null:
		return false
	if actor is GuardController3D:
		return true
	return actor is ThiefController3D and not is_open


func get_interaction_text(actor: Node3D = null) -> String:
	if actor is ThiefController3D:
		return "Forzando la cerradura…" if _task != null else "Forzar la puerta de la garita [E]"
	return "Cerrar la puerta [E]" if is_open else "Abrir la puerta [E]"


func interact(actor: Node3D) -> void:
	if not can_interact(actor):
		return
	if actor is ThiefController3D:
		_task = TimedTask.start(actor, RULES.pick_time, HEIST_RULES.task_leash, _finish_pick)
	else:
		set_open(not is_open)


## Autoridad: abre (cruje y empieza la cuenta para cerrarse) o cierra
func set_open(open: bool) -> void:
	if open == is_open:
		return
	_apply(open)
	if open:
		_open_left = RULES.auto_close
		NoiseEmit.emit(global_position, RULES.creak_radius, &"guard", NoiseEmit.MECHANISM, self)


func _finish_pick(_actor: Node3D) -> void:
	set_open(true)


func _apply(open: bool) -> void:
	is_open = open
	if leaf_pivot != null:
		leaf_pivot.rotation_degrees.y = OPEN_ANGLE if open else 0.0
	if _leaf_body != null:
		(_leaf_body.get_node("CollisionShape3D") as CollisionShape3D).disabled = open


func _ai_guard_near() -> bool:
	for node: Node in get_tree().get_nodes_in_group(&"guards"):
		var guard: GuardController3D = node as GuardController3D
		if guard.is_ai_controlled and _flat_distance(guard) <= RULES.ai_open_distance:
			return true
	return false


func _doorway_busy() -> bool:
	for group: StringName in [&"guards", &"thief"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			if _flat_distance(node as Node3D) <= DOORWAY_CLEAR:
				return true
	return false


func _flat_distance(node: Node3D) -> float:
	var offset: Vector3 = node.global_position - global_position
	return Vector2(offset.x, offset.z).length()


func get_net_state() -> Dictionary:
	return {"open": is_open}


func apply_net_state(state: Dictionary) -> void:
	if state.has("open") and bool(state["open"]) != is_open:
		_apply(bool(state["open"]))


static func _mesh(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.2
	box.material = mat
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = box
	node.position = pos
	return node
