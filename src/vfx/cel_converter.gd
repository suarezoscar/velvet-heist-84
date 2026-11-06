## @file cel_converter.gd
## Pasa el mapa a cel-shading (#181, fase 1): cambia cada StandardMaterial3D de las mallas por un
## cel_toon.gdshader con su color, texturas y rugosidad, y le cuelga el contorno de malla
## invertida (outline.gdshader) como next_pass. Así ningún .glb se reexporta. Lo transparente,
## lo que no recibe luz (efectos, marcadores) y los ShaderMaterial propios se quedan como están;
## los muros (WallXRay) ya traen la luz cel y su contorno. Ladrón y guardias llevan luz de borde.
class_name CelConverter
extends RefCounted

const CEL_SHADER: Shader = preload("res://assets/shaders/cel_toon.gdshader")
const OUTLINE_SHADER: Shader = preload("res://assets/shaders/outline.gdshader")
## Grupo de los nodos que no se convierten (efectos que se ven igual con o sin cel-shading)
const SKIP_GROUP: StringName = &"no_cel"

static var _outline: ShaderMaterial = null
static var _box_outline: ShaderMaterial = null

var look: NightLook = null
## Material original → su versión cel, para no duplicar los compartidos
var _converted: Dictionary = {}


## Convierte todo lo que cuelga de root. rim: color de la luz de borde (alfa 0: sin borde)
func convert_tree(root: Node, rim: Color = Color(0, 0, 0, 0)) -> int:
	var count: int = 0
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		if _skipped(node, root):
			continue
		count += _convert_mesh(node as MeshInstance3D, rim)
	return count


## Contorno compartido por todo el mapa; box: el de las cajas (se infla hacia las esquinas)
static func outline_material(look: NightLook = null, box: bool = false) -> ShaderMaterial:
	if _outline == null:
		_outline = _new_outline(false)
		_box_outline = _new_outline(true)
	if look != null:
		for mat: ShaderMaterial in [_outline, _box_outline]:
			mat.set_shader_parameter(&"outline_color", look.outline_color)
			mat.set_shader_parameter(&"outline_width", look.outline_width)
	return _box_outline if box else _outline


static func _new_outline(box: bool) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = OUTLINE_SHADER
	mat.set_shader_parameter(&"box_mode", box)
	return mat


## Pone en to los materiales activos de from, malla a malla por su ruta relativa (fantasmas
## de FogMemory: se ven igual que el objeto real, convertido o no)
static func copy_look(from: Node, to: Node) -> void:
	for node: Node in to.find_children("*", "MeshInstance3D", true, false):
		var target: MeshInstance3D = node as MeshInstance3D
		var source: MeshInstance3D = from.get_node_or_null(to.get_path_to(target)) as MeshInstance3D
		if source == null or source.mesh == null or target.mesh == null:
			continue
		target.material_override = source.material_override
		for surface: int in range(
			mini(source.mesh.get_surface_count(), target.mesh.get_surface_count())
		):
			target.set_surface_override_material(surface, source.get_active_material(surface))


## Color base de una malla, convertida o no (rejillas de ventilación que cambian en juego)
static func set_albedo(mesh: MeshInstance3D, color: Color) -> void:
	for surface: int in range(mesh.mesh.get_surface_count()):
		var mat: Material = mesh.get_active_material(surface)
		if mat is ShaderMaterial:
			(mat as ShaderMaterial).set_shader_parameter(&"albedo", color)
		elif mat is BaseMaterial3D:
			(mat as BaseMaterial3D).albedo_color = color


## Color base de un material, convertido o no
static func albedo_of(mat: Material) -> Color:
	if mat is ShaderMaterial:
		var value: Variant = (mat as ShaderMaterial).get_shader_parameter(&"albedo")
		return value if value is Color else Color.WHITE
	if mat is BaseMaterial3D:
		return (mat as BaseMaterial3D).albedo_color
	return Color.WHITE


func _skipped(node: Node, root: Node) -> bool:
	var current: Node = node
	while current != null and current != root.get_parent():
		if current.is_in_group(SKIP_GROUP):
			return true
		current = current.get_parent()
	return false


func _convert_mesh(mesh: MeshInstance3D, rim: Color) -> int:
	if mesh.mesh == null:
		return 0
	var whole: BaseMaterial3D = mesh.material_override as BaseMaterial3D
	if whole != null:  # material_override manda sobre los de cada superficie
		if not _convertible(whole):
			return 0
		mesh.material_override = _cel_for(whole, rim, mesh.mesh is BoxMesh)
		return 1
	var count: int = 0
	for surface: int in range(mesh.mesh.get_surface_count()):
		var source: BaseMaterial3D = mesh.get_active_material(surface) as BaseMaterial3D
		if source == null or not _convertible(source):
			continue
		mesh.set_surface_override_material(surface, _cel_for(source, rim, mesh.mesh is BoxMesh))
		count += 1
	return count


func _convertible(source: BaseMaterial3D) -> bool:
	if source.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		return false
	if source.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return false
	return not source.no_depth_test and source.billboard_mode == BaseMaterial3D.BILLBOARD_DISABLED


func _cel_for(source: BaseMaterial3D, rim: Color, box: bool = false) -> ShaderMaterial:
	var key: String = "%d:%s:%s" % [source.get_instance_id(), rim.to_html(), box]
	if _converted.has(key):
		return _converted[key]
	var cel: ShaderMaterial = ShaderMaterial.new()
	cel.shader = CEL_SHADER
	cel.set_shader_parameter(&"albedo", source.albedo_color)
	if source.albedo_texture != null:
		cel.set_shader_parameter(&"albedo_texture", source.albedo_texture)
	var nearest: bool = (
		source.texture_filter
		in [
			BaseMaterial3D.TEXTURE_FILTER_NEAREST,
			BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		]
	)
	cel.set_shader_parameter(&"texture_nearest", nearest)
	var planar: bool = source.uv1_triplanar and source.uv1_world_triplanar
	cel.set_shader_parameter(&"world_planar", planar)
	var scale: Vector3 = source.uv1_scale
	cel.set_shader_parameter(&"uv_scale", Vector2(scale.x, scale.z if planar else scale.y))
	if source.normal_enabled and source.normal_texture != null:
		cel.set_shader_parameter(&"use_normal_map", true)
		cel.set_shader_parameter(&"normal_map", source.normal_texture)
		cel.set_shader_parameter(&"normal_strength", source.normal_scale)
	var floor_like: bool = planar and look != null
	cel.set_shader_parameter(&"roughness", look.floor_roughness if floor_like else source.roughness)
	cel.set_shader_parameter(&"metallic", source.metallic)
	if source.emission_enabled:
		cel.set_shader_parameter(&"emission", source.emission)
		cel.set_shader_parameter(&"emission_energy", source.emission_energy_multiplier)
		if source.emission_texture != null:
			cel.set_shader_parameter(&"emission_texture", source.emission_texture)
	if look != null:
		cel.set_shader_parameter(&"penumbra_tint", look.penumbra_tint)
	if rim.a > 0.0:
		cel.set_shader_parameter(&"rim_color", rim)
		cel.set_shader_parameter(&"rim_strength", look.rim_strength if look != null else 0.8)
	# Sin contorno: los suelos y los pilotos (emisivos; el trazo los taparía y son luz, D5)
	var pilot: bool = source.emission_enabled and source.emission_texture == null
	if not planar and not pilot:
		cel.next_pass = outline_material(look, box)
	_converted[key] = cel
	return cel
