## @file sound_wave_3d.gd
## Instancia visual 3D para la propagación de ondas de sonido audibles.
## Dibuja un anillo horizontal expandible visible a través de paredes y oscuridad
## mediante el shader SDF 'assets/shaders/sound_wave_3d.gdshader'.
class_name SoundWave3D
extends MeshInstance3D

## Radio máximo final que alcanzará el anillo en metros
@export var max_radius: float = 8.0

## Tiempo de vida y expansión de la onda en segundos
@export var wave_duration: float = 0.8

## Color tintado de la onda (oro para ladrón, azul para guardias)
@export var wave_color: Color = Color(0.3, 0.8, 1.0, 0.9)

var _shader_mat: ShaderMaterial = null

func _ready() -> void:
	_setup_mesh_and_material()
	_animate_expansion()

func _setup_mesh_and_material() -> void:
	var quad: QuadMesh = QuadMesh.new()
	var diameter: float = max_radius * 2.0
	quad.size = Vector2(diameter, diameter)
	quad.orientation = PlaneMesh.FACE_Y
	mesh = quad

	var base_shader: Shader = load("res://assets/shaders/sound_wave_3d.gdshader") as Shader
	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = base_shader
	_shader_mat.set_shader_parameter("wave_color", wave_color)
	_shader_mat.set_shader_parameter("current_radius", 0.0)
	_shader_mat.set_shader_parameter("fade_alpha", 1.0)
	material_override = _shader_mat

func _animate_expansion() -> void:
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_method(_set_radius, 0.0, 1.0, wave_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_alpha, 1.0, 0.0, wave_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)

func _set_radius(val: float) -> void:
	if _shader_mat != null:
		_shader_mat.set_shader_parameter("current_radius", val)

func _set_alpha(val: float) -> void:
	if _shader_mat != null:
		_shader_mat.set_shader_parameter("fade_alpha", val)

## Factoría estática segura: añade el nodo al árbol ANTES de fijar su global_position
static func create_at(parent: Node, world_pos: Vector3, radius: float, team: StringName = &"neutral") -> SoundWave3D:
	var wave: SoundWave3D = SoundWave3D.new()
	wave.max_radius = radius

	if team == &"thief":
		wave.wave_color = Color(0.9, 0.7, 0.2, 0.9) # Tono dorado/ámbar analógico
	elif team == &"guard":
		wave.wave_color = Color(0.2, 0.6, 1.0, 0.9) # Azul policía/guardia

	parent.add_child(wave)
	wave.global_position = Vector3(world_pos.x, 0.05, world_pos.z)
	return wave
