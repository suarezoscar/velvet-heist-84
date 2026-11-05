## @file exit_gate_3d.gd
## Reja de barrotes de una salida exterior (heist.md R7b, #120): recogida sobre la puerta desde
## el principio, baja con HeistLockdown.drop_progress() y, en el suelo, tapa el paso (no la
## vista). La mueve cada máquina con el estado de las rejas; no decide nada.
class_name ExitGate3D
extends Node3D

const HEIGHT: float = 2.5
const BAR_GAP: float = 0.22
const BAR_SIZE: Vector3 = Vector3(0.05, HEIGHT, 0.05)
const RAIL_SIZE: float = 0.08
const COLOR: Color = Color("3b3f45")
## Parte de la altura que se ve con la reja recogida
const ROLLED: float = 0.12

var width: float = 3.0
var exit_id: String = ""
var _bars: Node3D = null
var _body: StaticBody3D = null
var _shape: CollisionShape3D = null


static func create(id: String, gate_width: float) -> ExitGate3D:
	var gate: ExitGate3D = ExitGate3D.new()
	gate.name = "Gate_%s" % id
	gate.width = gate_width
	gate.exit_id = id
	return gate


func _ready() -> void:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = COLOR
	material.metallic = 0.8
	material.roughness = 0.4
	_bars = Node3D.new()
	_bars.name = "Bars"
	add_child(_bars)
	var count: int = maxi(2, int(width / BAR_GAP) + 1)
	for i: int in range(count):
		var bar: MeshInstance3D = MeshInstance3D.new()
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = BAR_SIZE
		mesh.material = material
		bar.mesh = mesh
		bar.position = Vector3(lerpf(-width * 0.5, width * 0.5, float(i) / (count - 1)), 0.0, 0.0)
		_bars.add_child(bar)
	for y: float in [-HEIGHT * 0.5 + RAIL_SIZE, HEIGHT * 0.5 - RAIL_SIZE]:
		var rail: MeshInstance3D = MeshInstance3D.new()
		var rail_mesh: BoxMesh = BoxMesh.new()
		rail_mesh.size = Vector3(width, RAIL_SIZE, RAIL_SIZE)
		rail_mesh.material = material
		rail.mesh = rail_mesh
		rail.position = Vector3(0.0, y, 0.0)
		_bars.add_child(rail)
	_body = StaticBody3D.new()
	_body.collision_layer = 1  # como un muro: no se cruza
	_body.collision_mask = 0
	_shape = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(width, HEIGHT, 0.2)
	_shape.shape = box
	_shape.position = Vector3(0.0, HEIGHT * 0.5, 0.0)
	_shape.disabled = true
	_body.add_child(_shape)
	add_child(_body)
	_apply(0.0)


func _process(_delta: float) -> void:
	var lockdown: HeistLockdown = HeistLockdown.of(get_tree())
	_apply(lockdown.gate_progress(exit_id) if lockdown != null else 0.0)


## progress: 0 recogida (enrollada bajo el dintel), 1 en el suelo (cerrada)
func _apply(progress: float) -> void:
	var drop: float = lerpf(ROLLED, 1.0, progress)
	_bars.scale.y = drop
	_bars.position.y = HEIGHT - HEIGHT * 0.5 * drop  # colgada del dintel
	_shape.disabled = progress < 1.0


## true con la reja en el suelo (lo usan los tests)
func is_closed() -> bool:
	return not _shape.disabled
