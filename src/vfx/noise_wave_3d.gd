## @file noise_wave_3d.gd
## Una minionda de ruido (#114): un disco plano en el suelo con noise_wave.gdshader que se abre y
## se desvanece en `wave_time`. La reutiliza NoiseWavePool; no se crea una por ruido.
class_name NoiseWave3D
extends MeshInstance3D

const SHADER: Shader = preload("res://assets/shaders/noise_wave.gdshader")
## Altura sobre el suelo, para no pelear con él
const LIFT: float = 0.06

var _material: ShaderMaterial = null
var _tween: Tween = null


func _ready() -> void:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	quad.orientation = PlaneMesh.FACE_Y
	mesh = quad
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.render_priority = Material.RENDER_PRIORITY_MAX  # por encima de la niebla
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	layers = 1 << (FogOfWar3D.FOG_LAYER - 1)  # solo la cámara del mapa, no las CCTV
	visible = false


## Lanza la onda en `pos` con radio final `radius` (m) durante `duration` s
func play(pos: Vector3, radius: float, duration: float) -> void:
	if _tween != null:
		_tween.kill()
	global_position = Vector3(pos.x, pos.y + LIFT, pos.z)
	scale = Vector3(radius, 1.0, radius)
	_material.set_shader_parameter(&"progress", 0.0)
	visible = true
	_tween = create_tween()
	_tween.tween_method(_set_progress, 0.0, 1.0, maxf(duration, 0.05))
	_tween.tween_callback(hide)


## true mientras se ve
func is_playing() -> bool:
	return visible


func _set_progress(value: float) -> void:
	_material.set_shader_parameter(&"progress", value)
