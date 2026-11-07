## @file level_dressing_builder.gd
## Decorado del nivel por datos (FEAT-034), sin reglas de juego: cuadros colgados («art», con
## cartela y cordón de terciopelo), modelos sueltos («decor»), muebles con su modelo según el
## tipo de cobertura, molduras en los muros y suelos con su acabado (#186: sin focos sobre las
## piezas, que parecían luz de sigilo sin serlo). Nada de esto colisiona. Añade también el
## WallXRay que recorta las paredes delante del jugador local.
class_name LevelDressingBuilder
extends RefCounted

const WALL_FACE: float = 0.17
const ART_HEIGHT: float = 1.3
const ART_BOTTOM: float = 0.9
const ROPE_DISTANCE: float = 0.75
const ROPE_COLOR: Color = Color(0.5, 0.04, 0.08)
const BRASS: Color = Color(0.72, 0.56, 0.24)
const BASEBOARD: Vector2 = Vector2(0.16, 0.04)
const CORNICE: Vector2 = Vector2(0.14, 0.06)
const BASEBOARD_COLOR: Color = Color(0.2, 0.12, 0.08)
## La cornisa asoma por encima del muro: con la misma cara de arriba parpadean (z-fighting)
const CORNICE_LIFT: float = 0.02
## Las molduras rodean el extremo del muro (vuelo menos 1 cm): su cara final no coincide con la
## del muro (z-fighting) y en las esquinas queda dentro de la moldura del otro muro
const MOLDING_RETURN_GAP: float = 0.01
const CORNICE_COLOR: Color = Color(0.86, 0.82, 0.72)
## Coberturas que se dibujan con un modelo (encajado en su caja) en vez de la caja gris
const KIND_MODELS: Dictionary = {
	"bench": "museum_bench",
	"screen": "chinese_screen",
	"grandfather_clock": "grandfather_clock",
	"plant": "planter",
	"vitrine": "museum_display_case",
}
## Color de las coberturas que siguen siendo cajas, por tipo
const KIND_COLORS: Dictionary = {
	"column": Color(0.86, 0.84, 0.8),
	"statue": Color(0.82, 0.8, 0.76),
	"jar_pedestal": Color(0.82, 0.8, 0.76),
	"fountain": Color(0.7, 0.72, 0.74),
	"shelf": Color(0.34, 0.2, 0.12),
	"cabinet": Color(0.38, 0.26, 0.16),
	"counter": Color(0.3, 0.17, 0.1),
	"desk": Color(0.34, 0.2, 0.12),
	"table": Color(0.42, 0.28, 0.16),
	"armchair": Color(0.45, 0.08, 0.1),
	"wardrobe": Color(0.3, 0.17, 0.1),
	"easel": Color(0.5, 0.36, 0.2),
	"sarcophagus": Color(0.74, 0.6, 0.3),
	"locker": Color(0.36, 0.42, 0.44),
	"key_cabinet": Color(0.36, 0.42, 0.44),
	"crate": Color(0.55, 0.42, 0.26),
	"pallet": Color(0.55, 0.42, 0.26),
}


static func build(data: LevelData, map: Node3D) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Dressing"
	map.add_child(root)
	var arch: Node = map.get_node_or_null("Architecture")
	if arch != null:
		_dress_architecture(data, arch)
		MuseumKitBuilder.build(data, map)  # #177: marcos, dinteles, pilastras y ventanas
	for art: Dictionary in data.section("art"):
		_add_art(data, root, art)
	for decor: Dictionary in data.section("decor"):
		_add_decor(data, root, decor)
	var xray: WallXRay = WallXRay.new()
	map.add_child(xray)
	return root


static func _dress_architecture(data: LevelData, arch: Node) -> void:
	for child: Node in arch.get_children():
		var body: StaticBody3D = child as StaticBody3D
		if body == null:
			continue
		if body.name.begins_with("Wall_") or body.name.begins_with("Partition_"):
			_add_moldings(body)
		elif body.name.begins_with("Cover_"):
			_dress_cover(body)
	MuseumFinishBuilder.apply(data, arch)  # #177: acabados del kit


static func _add_moldings(body: StaticBody3D) -> void:
	var mesh: BoxMesh = (body.get_node("Mesh") as MeshInstance3D).mesh as BoxMesh
	var along_x: bool = mesh.size.x >= mesh.size.z
	var length: float = maxf(mesh.size.x, mesh.size.z)
	var thick: float = minf(mesh.size.x, mesh.size.z)
	for band: Array in [
		[BASEBOARD, BASEBOARD_COLOR, 0.0, false, MuseumFinishBuilder.Part.BASEBOARD],
		[
			CORNICE,
			CORNICE_COLOR,
			mesh.size.y - CORNICE.x + CORNICE_LIFT,
			true,
			MuseumFinishBuilder.Part.CORNICE
		]
	]:
		var size2: Vector2 = band[0]
		var depth: float = thick + size2.y * 2.0
		var long: float = length + (size2.y - MOLDING_RETURN_GAP) * 2.0
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(long, size2.x, depth) if along_x else Vector3(depth, size2.x, long)
		box.material = WallXRay.material(band[1]) if band[3] else _plain(band[1])
		var strip: MeshInstance3D = MeshInstance3D.new()
		strip.name = "Molding"
		strip.set_meta(MuseumFinishBuilder.PART_META, band[4])
		strip.mesh = box
		strip.position = Vector3(0.0, float(band[2]) + size2.x * 0.5, 0.0)
		body.add_child(strip)


static func _dress_cover(body: StaticBody3D) -> void:
	var kind: String = String(body.get_meta("kind", ""))
	var mesh_node: MeshInstance3D = body.get_node_or_null("Mesh") as MeshInstance3D
	if mesh_node == null:
		return
	var size: Vector3 = (mesh_node.mesh as BoxMesh).size
	if KIND_MODELS.has(kind):
		var scene: PackedScene = (
			load("res://assets/models/%s.glb" % KIND_MODELS[kind]) as PackedScene
		)
		if scene != null:
			mesh_node.visible = false
			body.add_child(_fitted(scene.instantiate() as Node3D, size, "Model"))
			return
	if kind == "column":
		var cylinder: CylinderMesh = CylinderMesh.new()
		cylinder.top_radius = size.x * 0.45
		cylinder.bottom_radius = size.x * 0.5
		cylinder.height = size.y
		cylinder.material = WallXRay.material(KIND_COLORS["column"], true)
		mesh_node.mesh = cylinder
		return
	if KIND_COLORS.has(kind):
		var box: BoxMesh = (mesh_node.mesh as BoxMesh).duplicate() as BoxMesh
		var color: Color = KIND_COLORS[kind]
		box.material = (
			WallXRay.material(color)
			if size.y > LevelArchitectureBuilder.XRAY_FROM
			else _plain(color)
		)
		mesh_node.mesh = box


## Cuadro colgado en la pared (pos sobre la línea del muro, rot_deg hacia la sala)
static func _add_art(data: LevelData, root: Node3D, art: Dictionary) -> void:
	var height: float = float(art.get("height", ART_HEIGHT))
	var painting: Node3D = PaintingArt.create(String(art["painting"]), height)
	if painting == null:
		return
	var holder: Node3D = Node3D.new()
	holder.name = "Art_%s" % art["painting"]
	holder.position = data.to_world(art["pos"])
	holder.rotation.y = deg_to_rad(-float(art.get("rot_deg", 0.0)))
	root.add_child(holder)
	painting.position = Vector3(0.0, float(art.get("y", ART_BOTTOM)), -WALL_FACE)
	holder.add_child(painting)
	var plaque: MeshInstance3D = _box_mesh(Vector3(0.22, 0.08, 0.02), _plain(BRASS))
	plaque.position = Vector3(0.0, float(art.get("y", ART_BOTTOM)) - 0.12, -WALL_FACE - 0.01)
	holder.add_child(plaque)
	if bool(art.get("rope", false)):
		_add_rope(holder, maxf(1.4, height * 1.1), -WALL_FACE - ROPE_DISTANCE)


## Dos postes de latón con un cordón de terciopelo (decorado: no cierra el paso)
static func _add_rope(holder: Node3D, width: float, z: float) -> void:
	for side: float in [-0.5, 0.5]:
		var post: MeshInstance3D = _box_mesh(Vector3(0.06, 0.95, 0.06), _plain(BRASS))
		post.position = Vector3(width * side, 0.475, z)
		holder.add_child(post)
	var rope: MeshInstance3D = _box_mesh(Vector3(width, 0.035, 0.035), _plain(ROPE_COLOR))
	rope.position = Vector3(0.0, 0.82, z)
	holder.add_child(rope)


static func _add_decor(data: LevelData, root: Node3D, decor: Dictionary) -> void:
	var scene: PackedScene = load("res://assets/models/%s.glb" % decor["model"]) as PackedScene
	if scene == null:
		return
	var node: Node3D = scene.instantiate() as Node3D
	node.name = "Decor_%s" % decor.get("id", decor["model"])
	node.position = data.to_world(decor["pos"], float(decor.get("y", 0.0)))
	node.rotation.y = deg_to_rad(-float(decor.get("rot_deg", 0.0)))
	node.scale = Vector3.ONE * float(decor.get("scale", 1.0))
	root.add_child(node)


## Modelo encajado en la caja size (escala uniforme), apoyado en su base
static func _fitted(model: Node3D, size: Vector3, node_name: String) -> Node3D:
	model.name = node_name
	var bounds: AABB = AABB()
	var first: bool = true
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node: MeshInstance3D = node as MeshInstance3D
		var local: AABB = mesh_node.transform * mesh_node.get_aabb()
		bounds = local if first else bounds.merge(local)
		first = false
	if first or bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return model
	var footprint: float = minf(size.x / bounds.size.x, size.z / maxf(0.01, bounds.size.z))
	var factor: float = minf(footprint, size.y / bounds.size.y)
	model.scale = Vector3.ONE * factor
	model.position = Vector3(0.0, -bounds.position.y * factor, 0.0)
	return model


static func _plain(color: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.6
	return mat


static func _box_mesh(size: Vector3, material: Material) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	return node
