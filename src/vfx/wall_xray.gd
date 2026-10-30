## @file wall_xray.gd
## Paredes que dejan ver al jugador local (FEAT-034): los muros, tabiques y muebles altos
## comparten materiales de wall_xray.gdshader, y este nodo les pasa cada frame dónde está el
## jugador local. Sin jugador local (servidor dedicado, cámara libre) no recorta nada.
class_name WallXRay
extends Node

const SHADER: Shader = preload("res://assets/shaders/wall_xray.gdshader")
## Distinto de 0 activa el recorte (su forma, una franja con la silueta, está en el shader) y
## altura del centro sobre los pies
const RADIUS: float = 2.6
const CENTER_HEIGHT: float = 1.0

static var _materials: Dictionary = {}

var map: HeistMap3D = null


## Material compartido de un color (uno por color: muros, tabiques, muebles)
static func material(color: Color) -> ShaderMaterial:
	var key: String = color.to_html()
	if not _materials.has(key) or not is_instance_valid(_materials[key]):
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter(&"albedo", color)
		_materials[key] = mat
	return _materials[key]


func _ready() -> void:
	name = "WallXRay"
	if map == null:
		map = get_parent() as HeistMap3D


func _exit_tree() -> void:
	_set_center(Vector3.ZERO, 0.0)


func _process(_delta: float) -> void:
	var local: Node3D = map.local_player if map != null else null
	if local == null or not is_instance_valid(local):
		_set_center(Vector3.ZERO, 0.0)
		return
	_set_center(local.global_position + Vector3.UP * CENTER_HEIGHT, RADIUS)


func _set_center(center: Vector3, radius: float) -> void:
	for mat: Variant in _materials.values():
		if is_instance_valid(mat):
			(mat as ShaderMaterial).set_shader_parameter(&"xray_center", center)
			(mat as ShaderMaterial).set_shader_parameter(&"xray_radius", radius)
