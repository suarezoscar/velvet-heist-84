## @file team_marker_3d.gd
## Marca de bando a los pies de un personaje (FEAT-027): anillo del color de su bando con una
## flecha hacia donde mira y, encima de la cabeza, su número de guardia o «TÚ» si es el jugador
## local. Cuelga de VisualRoot, así que se oculta y pasa a la capa CCTV con el cuerpo: nunca
## delata a quien no se ve. Deshace el giro de VisualRoot para que la flecha siga el frente
## del personaje (-Z).
class_name TeamMarker3D
extends Node3D

const THIEF_COLOR: Color = Color("ff3d9a")
const GUARD_COLOR: Color = Color("3de0e0")
const RADIUS: float = 0.5
const WIDTH: float = 0.07
const ARROW_LENGTH: float = 0.38
const ARROW_HALF_WIDTH: float = 0.2
const HEIGHT: float = 0.04
const SEGMENTS: int = 40
const LABEL_HEIGHT: float = 2.15

var color: Color = GUARD_COLOR
var label: Label3D = null
var _ring: MeshInstance3D = null
var _material: StandardMaterial3D = null


## Crea la marca bajo el VisualRoot del personaje; tag es «1», «2»… o "" (el ladrón)
static func attach(actor: PlayerBase3D, team_color: Color, tag: String) -> TeamMarker3D:
	var body: Node3D = actor.get_node_or_null("VisualRoot") as Node3D
	if body == null:
		return null
	var marker: TeamMarker3D = TeamMarker3D.new()
	marker.name = "TeamMarker"
	marker.color = team_color
	body.add_child(marker)
	marker.transform = body.transform.affine_inverse()
	marker.set_tag(tag)
	return marker


func _init() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring = MeshInstance3D.new()
	_ring.name = "Ring"
	_ring.mesh = build_mesh()
	_ring.material_override = _material
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	label = Label3D.new()
	label.name = "Tag"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0.0, LABEL_HEIGHT, 0.0)
	label.font = MenuTheme84.FONT_STRONG
	label.font_size = 52
	label.pixel_size = 0.006
	label.outline_size = 10
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(label)


func _ready() -> void:
	set_local(false)


## El jugador local lleva el anillo más intenso y «TÚ» sobre la cabeza
func set_local(is_local: bool) -> void:
	_material.albedo_color = Color(color, 0.95 if is_local else 0.6)
	label.modulate = color
	label.text = "TÚ" if is_local else str(get_meta(&"tag", ""))
	label.visible = label.text != ""


func set_tag(tag: String) -> void:
	set_meta(&"tag", tag)
	set_local(false)


## Anillo en el suelo con una flecha que sale hacia -Z (el frente del personaje)
static func build_mesh() -> ArrayMesh:
	var points: PackedVector3Array = PackedVector3Array()
	var inner: float = RADIUS - WIDTH
	for i: int in range(SEGMENTS):
		var a0: float = TAU * float(i) / float(SEGMENTS)
		var a1: float = TAU * float(i + 1) / float(SEGMENTS)
		var o0: Vector3 = Vector3(cos(a0), 0.0, sin(a0))
		var o1: Vector3 = Vector3(cos(a1), 0.0, sin(a1))
		(
			points
			. append_array(
				[
					o0 * RADIUS + Vector3.UP * HEIGHT,
					o1 * RADIUS + Vector3.UP * HEIGHT,
					o1 * inner + Vector3.UP * HEIGHT,
					o0 * RADIUS + Vector3.UP * HEIGHT,
					o1 * inner + Vector3.UP * HEIGHT,
					o0 * inner + Vector3.UP * HEIGHT,
				]
			)
		)
	var base: float = -(RADIUS - 0.02)
	(
		points
		. append_array(
			[
				Vector3(-ARROW_HALF_WIDTH, HEIGHT, base),
				Vector3(ARROW_HALF_WIDTH, HEIGHT, base),
				Vector3(0.0, HEIGHT, base - ARROW_LENGTH),
			]
		)
	)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
