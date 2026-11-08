## @file flashlight_cone.gd
## Cono visible del haz de la linterna (#191): una malla que suma luz, hija de la SpotLight3D,
## así que se enciende, se apaga y se oculta (niebla, beam_only) con ella. Solo aspecto: la
## percepción usa el cono de perception_rules, no esta malla. Sustituye a la niebla volumétrica.
class_name FlashlightCone
extends RefCounted

const SHADER: Shader = preload("res://assets/shaders/flashlight_cone.gdshader")
const NODE_NAME: StringName = &"BeamCone"
## Parte del alcance de la linterna que ocupa el cono dibujado
const LENGTH_SHARE: float = 0.7


## Cuelga (o actualiza) el cono de light; alpha 0 lo quita
static func attach(light: SpotLight3D, alpha: float) -> MeshInstance3D:
	var old: Node = light.get_node_or_null(NodePath(NODE_NAME))
	if old != null:
		old.queue_free()
	if alpha <= 0.0:
		return null
	var length: float = light.spot_range * LENGTH_SHARE
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.04
	cone.bottom_radius = tan(deg_to_rad(light.spot_angle)) * length
	cone.height = length
	cone.radial_segments = 24
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter(&"beam_color", light.light_color)
	mat.set_shader_parameter(&"beam_alpha", alpha)
	var inst: MeshInstance3D = MeshInstance3D.new()
	inst.name = NODE_NAME
	inst.mesh = cone
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# El eje del cilindro (+Y) pasa a +Z: la boca junto a la linterna y la punta hacia -Z
	inst.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	inst.position = Vector3(0.0, 0.0, -length * 0.5)
	inst.add_to_group(CelConverter.SKIP_GROUP)
	light.add_child(inst)
	return inst
