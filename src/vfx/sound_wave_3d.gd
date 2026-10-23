## @file sound_wave_3d.gd
## Instancia visual 3D para la propagación de anillos de ruido "radar de 1984".
## Dibuja anillos horizontales finos con brillo de fósforo visibles a través de paredes y oscuridad
## mediante el shader SDF 'assets/shaders/sound_wave_3d.gdshader'.
class_name SoundWave3D
extends MeshInstance3D

const SHADER: Shader = preload("res://assets/shaders/sound_wave_3d.gdshader")
const DEFAULT_STYLE: NoiseRingStyle = preload("res://assets/ui/noise_ring_style.tres")

## Radio final en metros (solo lectura en tiempo de ejecución; = radius)
var final_radius: float = 0.0

## Radio máximo compatible con código previo
var max_radius: float = 0.0

## Categoría del ruido (&"step", &"impact", &"mechanism")
var category: StringName = &"step"

## Papel del anillo respecto al espectador (&"own", &"guard", &"other")
var role: StringName = &"other"

## Tiempo total de vida en segundos
var lifetime: float = 0.0

## Tiempo de expansión de 0 al radio final en segundos
var grow_time: float = 0.0

## Recurso de estilo visual
var style: NoiseRingStyle = null

## Tiempo restante de vida en segundos
var remaining_lifetime: float = 0.0

var _final_radius: float = 0.0
var _current_radius_m: float = 0.0
var _remaining_lifetime: float = 0.0
var _total_lifetime: float = 0.0
var _elapsed_time: float = 0.0
var _current_fade: float = 1.0
var _base_alpha: float = 0.45
var _base_glow_alpha: float = 0.15

var _shader_mat: ShaderMaterial = null
var _radius_tween: Tween = null
var _fade_tween: Tween = null


func _ready() -> void:
	if style == null:
		style = DEFAULT_STYLE
	_setup_mesh_and_material()
	_start_animations()


func _setup_mesh_and_material() -> void:
	var margin: float = 1.0
	var safe_radius: float = max(_final_radius, 0.1)
	var mesh_size: float = (safe_radius * 2.0) + margin

	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(mesh_size, mesh_size)
	quad.orientation = PlaneMesh.FACE_Y
	mesh = quad

	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = SHADER

	var ring_color: Color = _resolve_color()
	var mode: int = _resolve_category_mode()

	_base_alpha = style.alpha
	_base_glow_alpha = style.glow_alpha
	var stroke: float = style.stroke_px
	var glow: float = style.glow_px
	var gap: float = style.double_gap_px
	var dashes: int = style.dash_segments

	_shader_mat.set_shader_parameter("category_mode", mode)
	_shader_mat.set_shader_parameter("stroke_px", stroke)
	_shader_mat.set_shader_parameter("glow_px", glow)
	_shader_mat.set_shader_parameter("color", ring_color)
	_shader_mat.set_shader_parameter("alpha", _base_alpha)
	_shader_mat.set_shader_parameter("glow_alpha", _base_glow_alpha)
	_shader_mat.set_shader_parameter("double_gap_px", gap)
	_shader_mat.set_shader_parameter("dash_segments", dashes)
	_shader_mat.set_shader_parameter("current_radius_m", 0.0)
	_shader_mat.set_shader_parameter("mesh_size", mesh_size)

	material_override = _shader_mat


func _start_animations() -> void:
	_total_lifetime = lifetime
	_remaining_lifetime = lifetime
	remaining_lifetime = lifetime
	_elapsed_time = 0.0
	_current_fade = 1.0

	if grow_time > 0.0:
		_radius_tween = create_tween()
		var t: MethodTweener = _radius_tween.tween_method(
			_set_radius, 0.0, _final_radius, grow_time
		)
		t.set_trans(Tween.TRANS_QUAD)
		t.set_ease(Tween.EASE_OUT)
	else:
		_set_radius(_final_radius)

	if lifetime > 0.0:
		_fade_tween = create_tween()
		var solid_time: float = lifetime * 0.6
		var fade_time: float = lifetime * 0.4
		if solid_time > 0.0:
			_fade_tween.tween_interval(solid_time)
		_fade_tween.tween_method(_set_fade, 1.0, 0.0, fade_time)
		_fade_tween.tween_callback(queue_free)
	else:
		queue_free()


func _process(delta: float) -> void:
	_elapsed_time += delta
	_remaining_lifetime = max(0.0, _total_lifetime - _elapsed_time)
	remaining_lifetime = _remaining_lifetime
	if _remaining_lifetime <= 0.0 and not is_queued_for_deletion():
		queue_free()


func _set_radius(val: float) -> void:
	_current_radius_m = val
	if _shader_mat != null:
		_shader_mat.set_shader_parameter("current_radius_m", val)


func _set_fade(val: float) -> void:
	_current_fade = val
	if _shader_mat != null:
		_shader_mat.set_shader_parameter("alpha", _base_alpha * val)
		_shader_mat.set_shader_parameter("glow_alpha", _base_glow_alpha * val)


## Acorta la vida restante del anillo (usado al superar max_rings)
func shorten(remaining: float) -> void:
	if remaining <= 0.0:
		queue_free()
		return
	if remaining >= _remaining_lifetime:
		return

	_remaining_lifetime = remaining
	remaining_lifetime = remaining
	_total_lifetime = _elapsed_time + remaining

	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()

	_fade_tween = create_tween()
	_fade_tween.tween_method(_set_fade, _current_fade, 0.0, remaining)
	_fade_tween.tween_callback(queue_free)


func _resolve_category_mode() -> int:
	match category:
		&"impact":
			return 1
		&"mechanism":
			return 2
		_:
			return 0


func _resolve_color() -> Color:
	return style.get_color_for_role(role)


## Factoría estática: añade el nodo al árbol ANTES de fijar su global_position
static func create_at(
	parent: Node,
	pos: Vector3,
	radius: float,
	category: StringName,
	role: StringName,
	lifetime: float,
	grow_time: float,
	style: NoiseRingStyle = null
) -> SoundWave3D:
	var wave: SoundWave3D = SoundWave3D.new()
	wave.final_radius = radius
	wave._final_radius = radius
	wave.max_radius = radius
	wave.category = category
	wave.role = role
	wave.lifetime = lifetime
	wave.grow_time = grow_time
	if style == null:
		style = DEFAULT_STYLE
	wave.style = style

	parent.add_child(wave)
	wave.global_position = Vector3(pos.x, 0.05, pos.z)
	return wave
