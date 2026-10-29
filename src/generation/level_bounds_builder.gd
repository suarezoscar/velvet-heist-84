## @file level_bounds_builder.gd
## Cierres de las zonas exteriores del nivel (sección "bounds" del JSON): las salas exteriores
## no llevan muros, así que sin esto se podía salir del suelo y caer al vacío. Cada cierre es
## un muro de ladrillo oscuro de from a to con su altura: tapa la vista y para las monedas como
## cualquier muro (capa de muros) y se recorta con WallXRay si tapa al personaje.
class_name LevelBoundsBuilder
extends RefCounted

const BRICK_COLOR: Color = Color(0.29, 0.17, 0.15)


static func build(data: LevelData, root: Node3D) -> void:
	for bound: Dictionary in data.section("bounds"):
		var start: Vector3 = data.to_world(bound["from"])
		var end: Vector3 = data.to_world(bound["to"])
		var height: float = float(bound.get("height", data.wall_height))
		var thickness: float = data.wall_thickness
		var length: float = start.distance_to(end) + thickness
		var along_x: bool = absf(end.x - start.x) >= absf(end.z - start.z)
		var size: Vector3 = (
			Vector3(length, height, thickness) if along_x else Vector3(thickness, height, length)
		)
		var body: StaticBody3D = StaticBody3D.new()
		body.name = "Bound_%s" % bound["id"]
		body.collision_layer = (
			LevelArchitectureBuilder.LAYER_WORLD_SOLID | LevelArchitectureBuilder.LAYER_WALLS
		)
		body.collision_mask = 0
		body.position = (start + end) * 0.5
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = size
		var collision: CollisionShape3D = CollisionShape3D.new()
		collision.shape = shape
		collision.position = Vector3(0.0, height * 0.5, 0.0)
		body.add_child(collision)
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = size
		mesh.material = WallXRay.material(BRICK_COLOR)
		var visual: MeshInstance3D = MeshInstance3D.new()
		visual.name = "Mesh"
		visual.mesh = mesh
		visual.position = collision.position
		body.add_child(visual)
		root.add_child(body)
