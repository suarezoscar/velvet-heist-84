## @file cctv_monitor_3d.gd
## Monitor CRT analógico que proyecta la señal de vídeo de una SecurityCamera3D.
## Aplica un shader de fósforo CRT ochentero y reacciona con destellos rojos ante alertas.
## #118: en la mesa solo se enciende uno (follows_desk), con la cámara que la mesa tiene en
## pantalla; los demás quedan apagados.
class_name CCTVMonitor3D
extends Node3D

const CRTShader = preload("res://assets/shaders/crt_security_feed.gdshader")
## Resplandor de la pantalla en reposo: decorado muy tenue, no cuenta para el sigilo (#186)
const GLOW_ENERGY: float = 0.25

## Cámara de vigilancia asignada a este monitor
@export var linked_camera: Node3D = null

## Título de la señal (ej. "CAM 01 - BÓVEDA")
@export var monitor_title: String = "CAM 01"

## Color de fósforo base (Verde fósforo P1 / Monocromo)
@export var phosphor_color: Color = Color(0.80, 0.95, 0.80, 1.0)

## Enseña la cámara en pantalla de la mesa; si es false (y hay mesa), el monitor está apagado
@export var follows_desk: bool = true

var _screen_mesh: MeshInstance3D = null
var _screen_material: ShaderMaterial = null
var _glow_light: OmniLight3D = null


func _ready() -> void:
	_create_screen_quad()
	_create_ambient_glow()
	if linked_camera != null:
		bind_camera(linked_camera)
	if not follows_desk:
		_screen_mesh.visible = false
		_glow_light.visible = false
	set_process(follows_desk)


func _process(_delta: float) -> void:
	var desk: CCTVDesk3D = CCTVDesk3D.of(get_tree())
	var cam: SecurityCamera3D = desk.on_screen() if desk != null else null
	if cam != null and cam != linked_camera:
		if is_instance_valid(linked_camera):
			linked_camera.target_detected.disconnect(_on_camera_target_detected)
			linked_camera.target_lost.disconnect(_on_camera_target_lost)
			_on_camera_target_lost()
		bind_camera(cam)


func _create_screen_quad() -> void:
	_screen_mesh = MeshInstance3D.new()
	_screen_mesh.name = "CRTScreenQuad"
	var quad = QuadMesh.new()
	quad.size = Vector2(0.44, 0.33)
	_screen_mesh.mesh = quad
	# Posición centrada sobre la pantalla frontal del televisor
	_screen_mesh.position = Vector3(0.0, 0.32, 0.24)

	_screen_material = ShaderMaterial.new()
	_screen_material.shader = CRTShader
	_screen_material.set_shader_parameter("phosphor_tint", phosphor_color)
	_screen_material.set_shader_parameter("scanline_density", 160.0)
	_screen_material.set_shader_parameter("scanline_intensity", 0.35)
	_screen_material.set_shader_parameter("noise_intensity", 0.08)
	_screen_mesh.material_override = _screen_material
	add_child(_screen_mesh)


func _create_ambient_glow() -> void:
	_glow_light = OmniLight3D.new()
	_glow_light.name = "CRTGlowLight"
	_glow_light.light_color = phosphor_color
	_glow_light.light_energy = GLOW_ENERGY
	_glow_light.omni_range = 2.2
	_glow_light.position = Vector3(0.0, 0.32, 0.50)
	add_child(_glow_light)


## Vincula dinámicamente una cámara CCTV a este monitor
func bind_camera(cam: Node3D) -> void:
	linked_camera = cam
	var tex: ViewportTexture = cam.get_viewport_texture()
	if tex != null and _screen_material != null:
		_screen_material.set_shader_parameter("camera_feed", tex)

	if not cam.target_detected.is_connected(_on_camera_target_detected):
		cam.target_detected.connect(_on_camera_target_detected)
	if not cam.target_lost.is_connected(_on_camera_target_lost):
		cam.target_lost.connect(_on_camera_target_lost)


func _on_camera_target_detected(_target: Node3D) -> void:
	if _screen_material:
		_screen_material.set_shader_parameter("is_alert_active", true)
	if _glow_light:
		_glow_light.light_color = Color(1.0, 0.2, 0.15)
		_glow_light.light_energy = 1.6


func _on_camera_target_lost() -> void:
	if _screen_material:
		_screen_material.set_shader_parameter("is_alert_active", false)
	if _glow_light:
		_glow_light.light_color = phosphor_color
		_glow_light.light_energy = GLOW_ENERGY
