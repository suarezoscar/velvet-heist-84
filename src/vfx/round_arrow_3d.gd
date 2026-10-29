## @file round_arrow_3d.gd
## Flecha de la ronda (FEAT-042): solo para el guardia que juegas, una flecha cian en el suelo
## a su lado que apunta por el camino real (por las puertas, como camina la IA) hacia el
## siguiente reloj de su ruta, con «R3 · 18 m». Se esconde con la ronda suspendida por la
## alarma, sin ruta o con la partida acabada.
class_name RoundArrow3D
extends Node3D

const COLOR: Color = Color("3de0e0")
## Separación de la flecha respecto al guardia (m) y su tamaño
const OFFSET: float = 1.1
const LENGTH: float = 0.7
const WIDTH: float = 0.5
const LIFT: float = 0.06
## Cada cuánto se recalcula el camino (s)
const REPATH: float = 0.4
## Distancia a la que un punto del camino ya se da por alcanzado (m)
const REACHED: float = 1.2

var _arrow: MeshInstance3D = null
var _label: Label3D = null
var _path: Array[Vector3] = []
var _repath_left: float = 0.0
var _clock_id: int = -1


func _ready() -> void:
	name = "RoundArrow"
	_arrow = MeshInstance3D.new()
	_arrow.mesh = _arrow_mesh()
	_arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_arrow)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.modulate = COLOR
	_label.outline_modulate = Color(0.0, 0.0, 0.0, 0.8)
	_label.font_size = 40
	_label.pixel_size = 0.006
	add_child(_label)
	visible = false


func _process(delta: float) -> void:
	var guard: GuardController3D = _local_guard()
	var round_node: GuardRound = GuardRound.of(guard)
	var clock: TimeClock3D = _clock(round_node)
	visible = (
		clock != null
		and not round_node.suspended
		and GameManager.current_state == GameManager.MatchState.IN_PROGRESS
	)
	if not visible:
		return
	_repath_left -= delta
	if _repath_left <= 0.0 or clock.clock_id != _clock_id:
		_repath_left = REPATH
		_clock_id = clock.clock_id
		_path = _route(guard.global_position, clock.global_position)
	var here: Vector3 = guard.global_position
	var target: Vector3 = next_point(_path, here)
	var flat: Vector3 = Vector3(target.x - here.x, 0.0, target.z - here.z)
	if flat.length() < 0.05:
		flat = Vector3(clock.global_position.x - here.x, 0.0, clock.global_position.z - here.z)
	var dir: Vector3 = flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
	_arrow.global_position = Vector3(here.x, here.y + LIFT, here.z) + dir * OFFSET
	_arrow.global_rotation = Vector3(0.0, atan2(dir.x, dir.z), 0.0)
	_label.global_position = _arrow.global_position + Vector3(0.0, 0.5, 0.0)
	_label.text = "R%d · %d m" % [clock.clock_id, roundi(path_length(_path, here))]


## Primer punto del camino que aún no se ha alcanzado (el último si ya están todos)
static func next_point(path: Array[Vector3], from: Vector3) -> Vector3:
	for point: Vector3 in path:
		if Vector2(point.x - from.x, point.z - from.z).length() > REACHED:
			return point
	return path[-1] if not path.is_empty() else from


## Metros que quedan por el camino desde from
static func path_length(path: Array[Vector3], from: Vector3) -> float:
	var total: float = 0.0
	var last: Vector3 = from
	var started: bool = false
	for point: Vector3 in path:
		if not started and Vector2(point.x - from.x, point.z - from.z).length() <= REACHED:
			continue
		started = true
		total += Vector2(point.x - last.x, point.z - last.z).length()
		last = point
	return total


func _route(from: Vector3, to: Vector3) -> Array[Vector3]:
	var planner: RoundPlanner = RoundPlanner.of(get_tree())
	var points: Array[Vector3] = planner.walk_between(from, to) if planner != null else []
	points.append(to)
	return points


func _local_guard() -> GuardController3D:
	for node: Node in get_tree().get_nodes_in_group(&"guards"):
		var guard: GuardController3D = node as GuardController3D
		if guard != null and guard.is_locally_controlled:
			return guard
	return null


func _clock(round_node: GuardRound) -> TimeClock3D:
	if round_node == null or round_node.route.is_empty():
		return null
	var wanted: int = round_node.next_clock()
	for node: Node in get_tree().get_nodes_in_group(&"time_clock"):
		var clock: TimeClock3D = node as TimeClock3D
		if clock != null and clock.clock_id == wanted:
			return clock
	return null


## Flecha plana: un triángulo con una cola corta, apuntando a +Z
static func _arrow_mesh() -> ArrayMesh:
	var half: float = WIDTH * 0.5
	var tail: float = WIDTH * 0.18
	var points: PackedVector3Array = [
		Vector3(0.0, 0.0, LENGTH * 0.5),
		Vector3(-half, 0.0, 0.0),
		Vector3(half, 0.0, 0.0),
		Vector3(-tail, 0.0, 0.0),
		Vector3(tail, 0.0, 0.0),
		Vector3(-tail, 0.0, -LENGTH * 0.5),
		Vector3(tail, 0.0, 0.0),
		Vector3(tail, 0.0, -LENGTH * 0.5),
		Vector3(-tail, 0.0, -LENGTH * 0.5),
	]
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(COLOR, 0.85)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	mesh.surface_set_material(0, material)
	return mesh
