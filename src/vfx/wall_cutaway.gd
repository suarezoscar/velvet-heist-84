## @file wall_cutaway.gd
## Paredes recortadas por sala (#193): las paredes entre la cámara y la sala del jugador local
## bajan a NightLook.cutaway_height en NightLook.cutaway_time s, con la cara interior como tapa,
## y suben al salir. Sustituye al círculo de WallXRay. Además pone al jugador local una silueta
## (silhouette.gdshader) que se ve cuando algo lo tapa. Solo aspecto: la vista, la niebla y la
## percepción no cambian. Los materiales son los de WallXRay (muros, tabiques, muebles, kit).
class_name WallCutaway
extends Node

const LOOK: NightLook = preload("res://data/visual/night_look.tres")
const SILHOUETTE_SHADER: Shader = preload("res://assets/shaders/silhouette.gdshader")

var map: HeistMap3D = null
var look: NightLook = LOOK
## Sala recortada (rect en mundo: mín x, mín z, máx x, máx z) y la que se está levantando
var _rect_in: Vector4 = Vector4.ZERO
var _rect_out: Vector4 = Vector4.ZERO
var _amount_in: float = 0.0
var _amount_out: float = 0.0
var _room_id: String = ""
var _silhouetted: Node = null
var _silhouette: ShaderMaterial = null


func _ready() -> void:
	name = "WallCutaway"
	if map == null:
		map = get_parent() as HeistMap3D


func _process(delta: float) -> void:
	if not look.occlusion_cutaway:
		return
	var local: Node3D = map.local_player if map != null else null
	if local == null or not is_instance_valid(local):
		return
	var data: LevelData = map.get_meta(&"level_data", null) as LevelData
	if data != null:
		_follow_room(data, Vector2(local.global_position.x, local.global_position.z))
	var step: float = delta / maxf(look.cutaway_time, 0.001)
	_amount_in = minf(_amount_in + step, 1.0)
	_amount_out = maxf(_amount_out - step, 0.0)
	_push()
	# Sin pantalla (tests, servidor) no hay nada que dibujar y el renderizador vacío se queja
	if local != _silhouetted and DisplayServer.get_name() != "headless":
		_add_silhouette(local)


## Cambia de sala cuando el jugador entra en otra (en un paso o pasillo sin sala, sigue la de antes)
func _follow_room(data: LevelData, world_xz: Vector2) -> void:
	var design: Vector2 = world_xz - data.offset
	for room: Dictionary in data.section("rooms"):
		var rect: Rect2 = data.room_rect(room)
		if not rect.has_point(design) or bool(room.get("exterior", false)):
			continue
		var room_id: String = String(room["id"])
		if room_id == _room_id:
			return
		_room_id = room_id
		_rect_out = _rect_in
		_amount_out = _amount_in
		var a: Vector3 = data.to_world([rect.position.x, rect.position.y])
		var b: Vector3 = data.to_world([rect.end.x, rect.end.y])
		_rect_in = Vector4(a.x, a.z, b.x, b.z)
		_amount_in = 0.0
		return


func _push() -> void:
	for mat: ShaderMaterial in WallXRay.materials():
		mat.set_shader_parameter(&"cut_rect_a", _rect_in)
		mat.set_shader_parameter(&"cut_amount_a", _amount_in)
		mat.set_shader_parameter(&"cut_rect_b", _rect_out)
		mat.set_shader_parameter(&"cut_amount_b", _amount_out)
		mat.set_shader_parameter(&"cut_height", look.cutaway_height)
		# Solo muros y tabiques (museum_wall) se cortan por dentro; muebles y columnas, no
		mat.set_shader_parameter(&"cut_interior", mat.shader != WallXRay.SHADER)


func _add_silhouette(local: Node) -> void:
	_silhouetted = local
	if _silhouette == null:
		_silhouette = ShaderMaterial.new()
		_silhouette.shader = SILHOUETTE_SHADER
		_silhouette.set_shader_parameter(&"silhouette_color", look.silhouette_color)
	for node: Node in local.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		if mesh.mesh is PrimitiveMesh or mesh.is_in_group(CelConverter.SKIP_GROUP):
			continue  # anillos y marcadores
		mesh.material_overlay = _silhouette
