## @file last_seen_marker_3d.gd
## Silueta de última posición vista del ladrón para el guardia local.
## Muestra una cápsula semitransparente con contorno en color_other que se desvanece linealmente.
class_name LastSeenMarker3D
extends Node3D

const CAPSULE_RADIUS: float = 0.4  # Diámetro 0.8 m
const CAPSULE_HEIGHT: float = 1.8  # Altura 1.8 m
const BASE_ALPHA: float = 0.35
const HUD_PALETTE: HudPalette = preload("res://assets/ui/hud_palette.tres")

## Duración total de visibilidad del marcador en segundos
var duration: float = 0.0

## Tiempo restante de vida del marcador en segundos
var time_left: float = 0.0

## Última posición registrada en el mundo
var last_seen_position: Vector3 = Vector3.ZERO

var _mesh_instance: MeshInstance3D = null
var _material: ShaderMaterial = null
var _fade_tween: Tween = null


func _ready() -> void:
	_setup_mesh_and_material()
	visible = false


func _setup_mesh_and_material() -> void:
	if _mesh_instance != null:
		return

	_mesh_instance = MeshInstance3D.new()
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = CAPSULE_RADIUS
	capsule.height = CAPSULE_HEIGHT
	_mesh_instance.mesh = capsule
	_mesh_instance.position = Vector3(0.0, CAPSULE_HEIGHT * 0.5, 0.0)

	_material = ShaderMaterial.new()
	_material.shader = _create_shader()

	_material.set_shader_parameter("outline_color", HUD_PALETTE.color_other)
	_material.set_shader_parameter("base_alpha", BASE_ALPHA)
	_material.set_shader_parameter("fade_alpha", 1.0)

	_mesh_instance.material_override = _material
	add_child(_mesh_instance)


func _create_shader() -> Shader:
	var s: Shader = Shader.new()
	var lines: Array[String] = [
		"shader_type spatial;",
		"render_mode unshaded, blend_mix, depth_test_disabled, cull_disabled;",
		"uniform vec4 outline_color : source_color = vec4(0.721569, 0.901961, 0.756863, 1.0);",
		"uniform float base_alpha : hint_range(0.0, 1.0) = 0.35;",
		"uniform float fade_alpha : hint_range(0.0, 1.0) = 1.0;",
		"void fragment() {",
		"\tfloat fresnel = 1.0 - abs(dot(NORMAL, VIEW));",
		"\tfloat w = max(fwidth(fresnel), 0.0001);",
		"\tfloat edge = clamp((fresnel - (1.0 - 4.0 * w)) / (2.0 * w), 0.0, 1.0);",
		"\tALBEDO = outline_color.rgb;",
		"\tALPHA = mix(base_alpha * 0.35, base_alpha, edge) * fade_alpha * outline_color.a;",
		"}",
	]
	s.code = "\n".join(lines)
	return s


## Muestra la silueta en la posición dada durante la duración especificada
func show_at(pos: Vector3, p_duration: float) -> void:
	if _mesh_instance == null:
		_setup_mesh_and_material()

	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()

	global_position = pos
	last_seen_position = pos
	duration = p_duration
	time_left = p_duration
	_set_fade(1.0)
	visible = true

	if p_duration <= 0.0:
		hide_marker()
		return

	_fade_tween = create_tween()
	_fade_tween.tween_method(_set_fade, 1.0, 0.0, p_duration)
	_fade_tween.tween_callback(hide_marker)


## Oculta inmediatamente la silueta
func hide_marker() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	visible = false
	time_left = 0.0
	duration = 0.0
	_set_fade(0.0)


func _process(delta: float) -> void:
	if not visible:
		return
	if duration > 0.0:
		time_left = maxf(0.0, time_left - delta)


func _set_fade(val: float) -> void:
	if _material != null:
		_material.set_shader_parameter("fade_alpha", val)
