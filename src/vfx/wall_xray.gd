## @file wall_xray.gd
## Paredes que dejan ver al jugador local (FEAT-034): los muros, tabiques y muebles altos
## comparten materiales de wall_xray.gdshader, y este nodo les pasa cada frame dónde está el
## jugador local. Sin jugador local (servidor dedicado, cámara libre) no recorta nada.
class_name WallXRay
extends Node

const SHADER: Shader = preload("res://assets/shaders/wall_xray.gdshader")
const OUTLINE_SHADER: Shader = preload("res://assets/shaders/outline.gdshader")
## Distinto de 0 activa el recorte (su forma, una elipse con la silueta, está en el shader) y
## altura del centro sobre los pies
const RADIUS: float = 2.6
const CENTER_HEIGHT: float = 0.85
## Agachado el cuerpo es más bajo: la elipse baja para cubrirle los pies
const CROUCH_CENTER_HEIGHT: float = 0.5

static var _materials: Dictionary = {}
## Contorno de los muros (#181): se recorta como ellos, así que no es el compartido del mapa
static var _outline: ShaderMaterial = null
## El de lo redondo (columnas): sigue la normal en vez de inflarse hacia las esquinas
static var _round_outline: ShaderMaterial = null

var map: HeistMap3D = null


## Material compartido de un color (uno por color: muros, tabiques, muebles); round: columnas
static func material(color: Color, round: bool = false) -> ShaderMaterial:
	var key: String = color.to_html() + (":round" if round else "")
	if not _materials.has(key) or not is_instance_valid(_materials[key]):
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter(&"albedo", color)
		mat.next_pass = _wall_outline(round)
		_materials[key] = mat
	return _materials[key]


## Material de muro propio (kit del museo, #177): recibe el recorte y el contorno de caja
static func register(mat: ShaderMaterial, key: String) -> ShaderMaterial:
	mat.next_pass = _wall_outline(false)
	_materials[key] = mat
	return mat


static func _wall_outline(round: bool) -> ShaderMaterial:
	if _outline == null or not is_instance_valid(_outline):
		_outline = _new_outline(true)  # muros y tabiques son cajas
		_round_outline = _new_outline(false)
	return _round_outline if round else _outline


static func _new_outline(box: bool) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = OUTLINE_SHADER
	mat.set_shader_parameter(&"box_mode", box)
	var shared: ShaderMaterial = CelConverter.outline_material()
	for param: StringName in [&"outline_color", &"outline_width"]:
		var value: Variant = shared.get_shader_parameter(param)
		if value != null:
			mat.set_shader_parameter(param, value)
	return mat


## Grosor y color del contorno de los muros desde el NightLook (se crean antes de aplicarlo)
static func apply_look(look: NightLook) -> void:
	for outline: ShaderMaterial in [_outline, _round_outline]:
		if outline != null and is_instance_valid(outline):
			outline.set_shader_parameter(&"outline_color", look.outline_color)
			outline.set_shader_parameter(&"outline_width", look.outline_width)
	for mat: Variant in _materials.values():
		if is_instance_valid(mat):
			(mat as ShaderMaterial).set_shader_parameter(&"penumbra_tint", look.penumbra_tint)
			(mat as ShaderMaterial).set_shader_parameter(&"band_softness", look.band_softness)


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
	var player: PlayerBase3D = local as PlayerBase3D
	var height: float = (
		CROUCH_CENTER_HEIGHT if player != null and player.is_crouching else CENTER_HEIGHT
	)
	_set_center(local.global_position + Vector3.UP * height, RADIUS)


func _set_center(center: Vector3, radius: float) -> void:
	var all: Array = _materials.values()
	for outline: ShaderMaterial in [_outline, _round_outline]:
		if outline != null and is_instance_valid(outline):
			all.append(outline)
	for mat: Variant in all:
		if is_instance_valid(mat):
			(mat as ShaderMaterial).set_shader_parameter(&"xray_center", center)
			(mat as ShaderMaterial).set_shader_parameter(&"xray_radius", radius)
