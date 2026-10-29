## @file painting_art.gd
## Cuadros del museo (FEAT-034): un lienzo con una pintura de dominio público
## (assets/textures/paintings/<slug>.jpg, créditos en su CREDITS.md) y un marco dorado, con la
## proporción de la imagen. El frente mira a -Z y el pivote está abajo, en el centro de la cara
## trasera: colgado en una pared, rot_deg orienta el cuadro hacia la sala como los relojes.
class_name PaintingArt
extends RefCounted

const TEXTURE_DIR: String = "res://assets/textures/paintings/%s.jpg"
const FRAME_COLOR: Color = Color(0.62, 0.47, 0.2)
const FRAME_WIDTH: float = 0.07
const FRAME_DEPTH: float = 0.06
const CANVAS_DEPTH: float = 0.02

static var _frame_material: StandardMaterial3D = null


## Cuadro de altura height (m, con el marco); null si la pintura no existe
static func create(slug: String, height: float) -> Node3D:
	var path: String = TEXTURE_DIR % slug
	if not ResourceLoader.exists(path):
		push_warning("[PaintingArt] Falta la pintura %s" % path)
		return null
	var texture: Texture2D = load(path) as Texture2D
	var aspect: float = float(texture.get_width()) / float(maxi(1, texture.get_height()))
	var canvas_h: float = height - FRAME_WIDTH * 2.0
	var canvas_w: float = canvas_h * aspect
	var root: Node3D = Node3D.new()
	root.name = "Painting_%s" % slug
	var canvas: MeshInstance3D = MeshInstance3D.new()
	canvas.name = "Canvas"
	var quad: BoxMesh = BoxMesh.new()
	quad.size = Vector3(canvas_w, canvas_h, CANVAS_DEPTH)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_texture = texture
	mat.roughness = 0.85
	quad.material = mat
	canvas.mesh = quad
	canvas.position = Vector3(0.0, height * 0.5, -CANVAS_DEPTH * 0.5)
	root.add_child(canvas)
	var outer_w: float = canvas_w + FRAME_WIDTH * 2.0
	var sides: Array = [
		[Vector3(outer_w, FRAME_WIDTH, FRAME_DEPTH), Vector3(0.0, FRAME_WIDTH * 0.5, 0.0)],
		[Vector3(outer_w, FRAME_WIDTH, FRAME_DEPTH), Vector3(0.0, height - FRAME_WIDTH * 0.5, 0.0)],
		[
			Vector3(FRAME_WIDTH, canvas_h, FRAME_DEPTH),
			Vector3(-outer_w * 0.5 + FRAME_WIDTH * 0.5, height * 0.5, 0.0)
		],
		[
			Vector3(FRAME_WIDTH, canvas_h, FRAME_DEPTH),
			Vector3(outer_w * 0.5 - FRAME_WIDTH * 0.5, height * 0.5, 0.0)
		],
	]
	for index: int in range(sides.size()):
		var bar: MeshInstance3D = MeshInstance3D.new()
		bar.name = "Frame_%d" % index
		var box: BoxMesh = BoxMesh.new()
		box.size = sides[index][0]
		box.material = _frame()
		bar.mesh = box
		bar.position = sides[index][1] + Vector3(0.0, 0.0, -FRAME_DEPTH * 0.5)
		root.add_child(bar)
	return root


static func _frame() -> StandardMaterial3D:
	if _frame_material == null:
		_frame_material = StandardMaterial3D.new()
		_frame_material.albedo_color = FRAME_COLOR
		_frame_material.metallic = 0.7
		_frame_material.roughness = 0.35
	return _frame_material
