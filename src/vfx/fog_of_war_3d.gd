## @file fog_of_war_3d.gd
## Niebla de guerra (vision.md R1-R2): malla de pantalla completa (fog_of_war.gdshader) hija de
## la cámara del mapa. Calcula la zona visible del jugador local con fog_rays rayos contra la
## capa de muros y se la pasa al shader como distancia por ángulo. Se apaga al acabar la partida.
class_name FogOfWar3D
extends MeshInstance3D

const RULES: VisionProfile = preload("res://data/balance/vision_rules.tres")
const SHADER: Shader = preload("res://assets/shaders/fog_of_war.gdshader")
## Capa de render 19: solo la dibuja la cámara del mapa; las cámaras CCTV la excluyen
const FOG_LAYER: int = 19
## Tamaño del array del shader (fog_rays no puede pasar de aquí)
const MAX_RAYS: int = 256
const UPDATE_INTERVAL: float = 1.0 / 30.0
## Margen (m) tras el choque con un muro para que su cara visible no quede en la niebla
const WALL_MARGIN: float = 0.35

## Personaje desde el que se ve (el jugador local); null apaga la niebla
var viewer: Node3D = null
var distances: PackedFloat32Array = PackedFloat32Array()
var _ray_count: int = 0
var _eye: Vector3 = Vector3.ZERO
var _radius: float = 0.0
var _timer: float = 0.0
var _material: ShaderMaterial = null
var _query: PhysicsRayQueryParameters3D = null


func _ready() -> void:
	name = "FogOfWar"
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	mesh = quad
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	# Lo primero del pase transparente: copia la pantalla opaca y lo transparente (vidrio,
	# siluetas O2, partículas) se dibuja encima sin niebla
	_material.render_priority = Material.RENDER_PRIORITY_MIN
	_material.set_shader_parameter("edge_feather", RULES.fog_edge_feather)
	_material.set_shader_parameter("fog_brightness", RULES.fog_brightness)
	_material.set_shader_parameter("fog_desaturation", RULES.fog_desaturation)
	_material.set_shader_parameter("light_keep", RULES.fog_light_keep)
	material_override = _material
	layers = 1 << (FOG_LAYER - 1)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-1.0e5, -1.0e5, -1.0e5), Vector3(2.0e5, 2.0e5, 2.0e5))
	_ray_count = clampi(RULES.fog_rays, 8, MAX_RAYS)
	distances.resize(MAX_RAYS)
	distances.fill(0.0)
	_query = PhysicsRayQueryParameters3D.new()
	_query.collision_mask = LevelArchitectureBuilder.LAYER_WALLS


func _process(delta: float) -> void:
	visible = is_active()
	if not visible:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = UPDATE_INTERVAL
	# Los muros no se mueven: si los ojos y el radio siguen igual, la zona tampoco cambia
	if VisionLogic.eye(viewer) != _eye or VisionLogic.view_radius(viewer) != _radius:
		recompute()


## true si hay a quién seguir y la partida no ha terminado
func is_active() -> bool:
	return (
		viewer != null
		and is_instance_valid(viewer)
		and viewer.is_inside_tree()
		and not GameManager.is_match_over()
	)


## Recalcula la zona visible desde los ojos del espectador y actualiza el shader
func recompute() -> void:
	_eye = VisionLogic.eye(viewer)
	_radius = VisionLogic.view_radius(viewer)
	var space: PhysicsDirectSpaceState3D = viewer.get_world_3d().direct_space_state
	for i: int in range(MAX_RAYS):
		distances[i] = _radius
	for i: int in range(_ray_count):
		var angle: float = TAU * float(i) / float(_ray_count)
		var target: Vector3 = _eye + Vector3(cos(angle), 0.0, sin(angle)) * _radius
		_query.from = _eye
		_query.to = target
		var hit: Dictionary = space.intersect_ray(_query)
		if not hit.is_empty():
			var at: Vector3 = hit["position"]
			var reach: float = Vector2(at.x - _eye.x, at.z - _eye.z).length() + WALL_MARGIN
			distances[i] = minf(reach, _radius)
	_material.set_shader_parameter("distances", distances)
	_material.set_shader_parameter("ray_count", _ray_count)
	_material.set_shader_parameter("eye_xz", Vector2(_eye.x, _eye.z))
	_material.set_shader_parameter("view_radius", _radius)


## true si el punto queda dentro de la zona visible (la misma cuenta que el shader, sin borde)
func is_point_visible(point: Vector3) -> bool:
	if not is_active() or _ray_count == 0 or _radius <= 0.0:
		return true
	var offset: Vector2 = Vector2(point.x - _eye.x, point.z - _eye.z)
	var radial: float = offset.length()
	if radial > _radius:
		return false
	var slot: float = fposmod(atan2(offset.y, offset.x), TAU) / TAU * float(_ray_count)
	var first: int = int(floor(slot)) % _ray_count
	var second: int = (first + 1) % _ray_count
	return radial <= lerpf(distances[first], distances[second], slot - floor(slot))
