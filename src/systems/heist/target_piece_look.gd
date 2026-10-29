## @file target_piece_look.gd
## Aspecto de una pieza candidata (heist.md R1 y R9): el área de interacción, el pedestal, el
## modelo escalado sobre él, la marca encima y el fallo de una pieza de pega. Una copia se
## parece al original pero no es igual: FLAWS sortea un fallo que un guardia atento puede ver.
class_name TargetPieceLook
extends RefCounted

## Fallos de una pieza de pega: ninguno, color, tamaño o pose
enum Flaw { NONE, TINT, SIZE, POSE }

const PEDESTAL_SIZE: Vector3 = Vector3(0.7, 1.0, 0.7)
const MODEL_SIZE: float = 0.6
const MARKER_HEIGHT: float = 2.3
const TINT: Color = Color(0.55, 0.85, 0.35, 0.45)
const SMALL: float = 0.75
const DISCOVERED_COLOR: Color = Color("ff4a3d")
const AUTHENTIC_COLOR: Color = Color("4be38a")


## Construye el área, el pedestal (si va sobre uno), el modelo y la marca de la pieza
static func build(piece: TargetPiece3D, model_scene: PackedScene) -> void:
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = PEDESTAL_SIZE + Vector3(0.6, 0.8, 0.6)
	var col: CollisionShape3D = CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0.0, shape.size.y * 0.5, 0.0)
	piece.add_child(col)
	if piece.variant == &"pedestal":
		piece.add_child(_pedestal())
	if model_scene != null:
		attach_model(piece, model_scene.instantiate() as Node3D)
	piece.marker = Label3D.new()
	piece.marker.name = "Marker"
	piece.marker.text = "◆"
	piece.marker.font_size = 48
	piece.marker.pixel_size = 0.006
	piece.marker.no_depth_test = true
	piece.marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	piece.marker.outline_size = 12
	piece.marker.position = Vector3(0.0, MARKER_HEIGHT, 0.0)
	piece.marker.visible = false
	piece.add_child(piece.marker)


## Pone el modelo de la pieza sobre su pedestal: size escala MODEL_SIZE (las estatuas y los
## cuadros son mayores) y tint tiñe sus materiales (un busto de bronce con el modelo de mármol)
static func attach_model(
	piece: TargetPiece3D, node: Node3D, size: float = 1.0, tint: Color = Color.WHITE
) -> void:
	if node == null:
		return
	piece.model = node
	piece.model.name = "Piece"
	piece.add_child(piece.model)
	if tint != Color.WHITE:
		_tint(piece.model, tint)
	_fit(piece.model, MODEL_SIZE * size)
	piece.model.visible = piece.variant != &"safe"


## Aplica el fallo de una pieza de pega al modelo (sobre su escala y giro originales)
static func apply_flaw(model: Node3D, flaw: Flaw) -> void:
	if model == null or flaw == Flaw.NONE:
		return
	match flaw:
		Flaw.TINT:
			var overlay: StandardMaterial3D = StandardMaterial3D.new()
			overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			overlay.albedo_color = TINT
			for node: Node in model.find_children("*", "MeshInstance3D", true, false):
				(node as MeshInstance3D).material_overlay = overlay
		Flaw.SIZE:
			model.scale *= SMALL
		Flaw.POSE:
			model.rotation.y += PI * 0.5


## Marca para el jugador local: rosa al ladrón si es de su encargo y no la tiene; a los
## guardias, ◆ cian si sigue siendo candidata, ✔ verde si la han examinado y es auténtica, y ✘
## roja si saben que se la llevó
static func update_marker(piece: TargetPiece3D) -> void:
	var marker: Label3D = piece.marker
	if marker == null:
		return
	if HeistDirector.local_is_thief(piece.get_tree()):
		marker.visible = piece.in_contract() and not piece.stolen
		marker.text = "◆"
		marker.modulate = TeamMarker3D.THIEF_COLOR
		return
	marker.visible = not NetManager.is_dedicated_server
	if piece.discovered:
		marker.text = "✘"
		marker.modulate = DISCOVERED_COLOR
	elif piece.inspected:
		marker.text = "✔"
		marker.modulate = AUTHENTIC_COLOR
	else:
		marker.text = "◆"
		marker.modulate = TeamMarker3D.GUARD_COLOR


static func _pedestal() -> StaticBody3D:
	var pedestal: StaticBody3D = StaticBody3D.new()
	pedestal.name = "Pedestal"
	var box: BoxShape3D = BoxShape3D.new()
	box.size = PEDESTAL_SIZE
	var body_col: CollisionShape3D = CollisionShape3D.new()
	body_col.shape = box
	pedestal.add_child(body_col)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = PEDESTAL_SIZE
	mesh.mesh = box_mesh
	pedestal.add_child(mesh)
	pedestal.position = Vector3(0.0, PEDESTAL_SIZE.y * 0.5, 0.0)
	return pedestal


static func _tint(model: Node3D, tint: Color) -> void:
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node: MeshInstance3D = node as MeshInstance3D
		for surface: int in range(mesh_node.mesh.get_surface_count()):
			var source: BaseMaterial3D = mesh_node.get_active_material(surface) as BaseMaterial3D
			if source == null:
				continue
			var tinted: BaseMaterial3D = source.duplicate() as BaseMaterial3D
			tinted.albedo_color = source.albedo_color * tint
			mesh_node.set_surface_override_material(surface, tinted)


## Escala el modelo a target_size (su mayor medida) y lo apoya sobre el pedestal
static func _fit(model: Node3D, target_size: float = MODEL_SIZE) -> void:
	var bounds: AABB = AABB()
	var first: bool = true
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node: MeshInstance3D = node as MeshInstance3D
		var local: AABB = mesh_node.transform * mesh_node.get_aabb()
		bounds = local if first else bounds.merge(local)
		first = false
	if first:
		return
	var biggest: float = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	var factor: float = target_size / biggest if biggest > 0.0 else 1.0
	model.scale = Vector3.ONE * factor
	model.position = Vector3(0.0, PEDESTAL_SIZE.y - bounds.position.y * factor, 0.0)
