## @file museum_level_builder_3d.gd
## Constructor 3D híbrido en Godot para Velvet Heist 84.
## Construye suelos continuos y muros con vanos recortados usando colisionadores BoxShape3D
## (evitando 'ghost collisions') y respetando zonas de despeje de 1.5m para props.

class_name MuseumLevelBuilder3D
extends RefCounted

const FloorplanBlueprint = preload("res://src/generation/floorplan_blueprint.gd")

const MODELS_DIR: String = "res://assets/models/"

# Alturas arquitectónicas
const WALL_H: float = 3.2
const FRONT_WALL_H: float = 1.3
const WALL_THICK: float = 0.30

# Capas físicas de project.godot
const LAYER_WORLD_SOLID: int = 1
const LAYER_CHARACTERS: int = 2
const LAYER_INTERACTIONS: int = 4
const LAYER_VISION: int = 8
const LAYER_ACOUSTICS: int = 16

## Construye la jerarquía 3D completa a partir de un Blueprint 2D.
static func build_level(blueprint, parent_node: Node3D) -> void:
	var builder = load("res://src/generation/museum_level_builder_3d.gd").new()
	var materials: Dictionary = builder._build_materials()

	var arch_root: Node3D = Node3D.new()
	arch_root.name = "Architecture"
	parent_node.add_child(arch_root)
	arch_root.owner = parent_node

	# 1. Suelos continuos con BoxShape3D y metadatos acústicos
	builder._build_floors(blueprint, arch_root, materials, parent_node)

	# 2. Rampa de colisión biselada en el bordillo (+0.15m)
	builder._build_curb_wedge(arch_root, parent_node)

	# 3. Muros y vanos de paso limpios
	builder._build_walls(blueprint, arch_root, materials, parent_node)

	# 4. Mobiliario, sistemas y props respetando buffer de 1.5m
	var props_root: Node3D = Node3D.new()
	props_root.name = "Props"
	parent_node.add_child(props_root)
	props_root.owner = parent_node
	builder._spawn_props(blueprint, props_root, materials, parent_node)

func _build_materials() -> Dictionary:
	var mats: Dictionary = {}

	# Asfalto callejón
	var mat_asphalt: StandardMaterial3D = StandardMaterial3D.new()
	mat_asphalt.albedo_color = Color(0.08, 0.09, 0.11)
	mat_asphalt.roughness = 0.2
	mat_asphalt.metallic = 0.15
	mats["asphalt"] = mat_asphalt

	# Acera hormigón
	var mat_sidewalk: StandardMaterial3D = StandardMaterial3D.new()
	mat_sidewalk.albedo_color = Color(0.44, 0.45, 0.47)
	mat_sidewalk.roughness = 0.75
	mats["sidewalk"] = mat_sidewalk

	# Mármol Damero
	var mat_marble: StandardMaterial3D = StandardMaterial3D.new()
	var tex_marble = load(MODELS_DIR + "floor_marble_floor_tiles_06_Diffuse_1k.jpg")
	if tex_marble:
		mat_marble.albedo_texture = tex_marble
		mat_marble.uv1_scale = Vector3(4.0, 4.0, 1.0)
	else:
		mat_marble.albedo_color = Color(0.85, 0.85, 0.88)
	mat_marble.roughness = 0.20
	mats["marble"] = mat_marble

	# Parqué de roble
	var mat_parquet: StandardMaterial3D = StandardMaterial3D.new()
	var tex_parquet = load(MODELS_DIR + "floor_parquet_wood_floor_Diffuse_1k.jpg")
	if tex_parquet:
		mat_parquet.albedo_texture = tex_parquet
		mat_parquet.uv1_scale = Vector3(3.5, 3.5, 1.0)
	else:
		mat_parquet.albedo_color = Color(0.62, 0.44, 0.28)
	mat_parquet.roughness = 0.35
	mats["parquet"] = mat_parquet

	# Linóleo industrial
	var mat_linoleum: StandardMaterial3D = StandardMaterial3D.new()
	mat_linoleum.albedo_color = Color(0.28, 0.33, 0.38)
	mat_linoleum.roughness = 0.45
	mats["linoleum"] = mat_linoleum

	# Terciopelo carmesí (Velvet)
	var mat_velvet: StandardMaterial3D = StandardMaterial3D.new()
	var tex_velvet = load(MODELS_DIR + "floor_carpet_velour_velvet_Diffuse_1k.jpg")
	if tex_velvet:
		mat_velvet.albedo_texture = tex_velvet
		mat_velvet.uv1_scale = Vector3(3.0, 3.0, 1.0)
	else:
		mat_velvet.albedo_color = Color(0.55, 0.05, 0.12)
	mat_velvet.roughness = 0.85
	mats["velvet"] = mat_velvet

	# Moqueta azul despacho conservador
	var mat_carpet: StandardMaterial3D = StandardMaterial3D.new()
	mat_carpet.albedo_color = Color(0.12, 0.20, 0.32)
	mat_carpet.roughness = 0.75
	mats["carpet"] = mat_carpet

	# Cemento taller restauración
	var mat_concrete: StandardMaterial3D = StandardMaterial3D.new()
	mat_concrete.albedo_color = Color(0.35, 0.35, 0.36)
	mat_concrete.roughness = 0.70
	mats["concrete"] = mat_concrete

	# Rejilla metálica sala generadores
	var mat_grate: StandardMaterial3D = StandardMaterial3D.new()
	mat_grate.albedo_color = Color(0.18, 0.20, 0.22)
	mat_grate.metallic = 0.8
	mat_grate.roughness = 0.35
	mats["grate"] = mat_grate

	# Muro exterior de ladrillo
	var mat_brick: StandardMaterial3D = StandardMaterial3D.new()
	mat_brick.albedo_color = Color(0.30, 0.15, 0.13)
	mat_brick.roughness = 0.80
	mats["brick"] = mat_brick

	# Muro interior de caoba
	var mat_wood_wall: StandardMaterial3D = StandardMaterial3D.new()
	var tex_wood_wall = load(MODELS_DIR + "wall_mahogany_wooden_panels_Diffuse_1k.jpg")
	if tex_wood_wall:
		mat_wood_wall.albedo_texture = tex_wood_wall
		mat_wood_wall.uv1_scale = Vector3(2.0, 2.0, 1.0)
	else:
		mat_wood_wall.albedo_color = Color(0.35, 0.22, 0.14)
	mat_wood_wall.roughness = 0.40
	mats["interior_wall"] = mat_wood_wall

	# Acero reforzado bóveda
	var mat_steel: StandardMaterial3D = StandardMaterial3D.new()
	mat_steel.albedo_color = Color(0.20, 0.22, 0.25)
	mat_steel.metallic = 0.85
	mat_steel.roughness = 0.25
	mats["steel"] = mat_steel

	# Latón pulido
	var mat_brass: StandardMaterial3D = StandardMaterial3D.new()
	mat_brass.albedo_color = Color(0.85, 0.70, 0.25)
	mat_brass.metallic = 0.90
	mat_brass.roughness = 0.25
	mats["brass"] = mat_brass

	# Cristal blindado ventana vigía
	var mat_glass: StandardMaterial3D = StandardMaterial3D.new()
	mat_glass.albedo_color = Color(0.25, 0.38, 0.45, 0.45)
	mat_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_glass.roughness = 0.10
	mats["glass"] = mat_glass

	return mats

func _build_floors(bp: FloorplanBlueprint, parent: Node3D, mats: Dictionary, root: Node3D) -> void:
	for room_id: String in bp.rooms:
		var room: FloorplanBlueprint.RoomData = bp.rooms[room_id]
		var body: StaticBody3D = StaticBody3D.new()
		body.name = "Floor_" + room.id
		body.collision_layer = LAYER_WORLD_SOLID
		body.collision_mask = 0
		body.set_meta("noise_multiplier", room.noise_multiplier)
		parent.add_child(body)
		body.owner = root

		var col: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(room.bounds.size.x, 0.20, room.bounds.size.y)
		col.shape = box
		var center_x: float = room.bounds.position.x + room.bounds.size.x * 0.5
		var center_z: float = room.bounds.position.y + room.bounds.size.y * 0.5
		col.position = Vector3(center_x, room.elevation_y - 0.10, center_z)
		body.add_child(col)
		col.owner = root

		var mesh_inst: MeshInstance3D = MeshInstance3D.new()
		var bmesh: BoxMesh = BoxMesh.new()
		bmesh.size = box.size
		if mats.has(room.floor_material):
			bmesh.material = mats[room.floor_material]
		mesh_inst.mesh = bmesh
		mesh_inst.position = col.position
		body.add_child(mesh_inst)
		mesh_inst.owner = root

func _build_curb_wedge(parent: Node3D, root: Node3D) -> void:
	# Rampa de colisión convexa biselada (27.2°) a lo largo del bordillo de la acera (Z = 5.0)
	# Empieza a ras de calzada (Y = -0.10, Z = 5.30) y asciende hasta la acera (Y = 0.08, Z = 4.95)
	# Eliminando cualquier labio o cara vertical que pueda frenar el step-climbing
	var wedge_body: StaticBody3D = StaticBody3D.new()
	wedge_body.name = "Curb_Bevel_Wedge"
	wedge_body.collision_layer = LAYER_WORLD_SOLID
	wedge_body.collision_mask = 0
	parent.add_child(wedge_body)
	wedge_body.owner = root

	var col: CollisionShape3D = CollisionShape3D.new()
	var prism: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	prism.points = PackedVector3Array([
		Vector3(-15.0, -0.15, 5.35),
		Vector3(15.0, -0.15, 5.35),
		Vector3(-15.0, -0.10, 5.35),
		Vector3(15.0, -0.10, 5.35),
		Vector3(-15.0, 0.08, 4.90),
		Vector3(15.0, 0.08, 4.90),
		Vector3(-15.0, -0.15, 4.90),
		Vector3(15.0, -0.15, 4.90),
	])
	col.shape = prism
	wedge_body.add_child(col)
	col.owner = root

func _build_walls(bp: FloorplanBlueprint, parent: Node3D, mats: Dictionary, root: Node3D) -> void:
	# Muro Frontal Sur (con corte diorama a 1.3m y puerta de servicio)
	# Tramo Izquierdo: X de -15.0 a 7.7 (longitud 22.7m)
	_create_wall_box(parent, root, Vector3(22.7, FRONT_WALL_H, WALL_THICK), Vector3(-3.65, FRONT_WALL_H * 0.5 + 0.15, 3.5), mats["brick"], "Wall_South_L")
	# Tramo Derecho: X de 9.3 a 15.0 (longitud 5.7m)
	_create_wall_box(parent, root, Vector3(5.7, FRONT_WALL_H, WALL_THICK), Vector3(12.15, FRONT_WALL_H * 0.5 + 0.15, 3.5), mats["brick"], "Wall_South_R")
	# Dintel sobre la puerta de servicio (X = 8.5)
	_create_wall_box(parent, root, Vector3(1.6, 0.6, WALL_THICK), Vector3(8.5, 2.3, 3.5), mats["brick"], "Wall_South_Lintel")

	# Muros Exteriores Perimetrales (Altura Completa 3.2m)
	# Muro Oeste Exterior (X = -15.0, Z: -9.5 a 3.5, longitud 13.0m)
	_create_wall_box(parent, root, Vector3(WALL_THICK, WALL_H, 13.0), Vector3(-15.0, WALL_H * 0.5 + 0.15, -3.0), mats["brick"], "Wall_Ext_West")
	# Muro Este Exterior (X = 15.0, Z: -9.5 a 3.5, longitud 13.0m)
	_create_wall_box(parent, root, Vector3(WALL_THICK, WALL_H, 13.0), Vector3(15.0, WALL_H * 0.5 + 0.15, -3.0), mats["brick"], "Wall_Ext_East")
	# Muro Norte Exterior (Z = -9.5, X: -15.0 a 15.0, longitud 30.0m)
	_create_wall_box(parent, root, Vector3(30.0, WALL_H, WALL_THICK), Vector3(0.0, WALL_H * 0.5 + 0.15, -9.5), mats["brick"], "Wall_Ext_North")

	# Muro Divisorio Central Norte-Sur (Z = -3.0)
	# Entre Reliquias y Taller (X: -15.0 a -6.0 con puerta en X = -10.5 de 1.6m)
	_create_wall_box(parent, root, Vector3(3.7, WALL_H, WALL_THICK), Vector3(-13.15, WALL_H * 0.5 + 0.15, -3.0), mats["interior_wall"], "Wall_Relics_Shop_L")
	_create_wall_box(parent, root, Vector3(3.7, WALL_H, WALL_THICK), Vector3(-7.85, WALL_H * 0.5 + 0.15, -3.0), mats["interior_wall"], "Wall_Relics_Shop_R")
	_create_wall_box(parent, root, Vector3(1.6, 0.8, WALL_THICK), Vector3(-10.5, WALL_H - 0.25, -3.0), mats["interior_wall"], "Wall_Relics_Shop_Lintel")

	# Entre Galería y Bóveda (X: -6.0 a 6.0 con portal acorazado en X = 0.0 de 2.4m)
	_create_wall_box(parent, root, Vector3(4.8, WALL_H, WALL_THICK + 0.15), Vector3(-3.6, WALL_H * 0.5 + 0.15, -3.0), mats["steel"], "Wall_Vault_South_L")
	_create_wall_box(parent, root, Vector3(4.8, WALL_H, WALL_THICK + 0.15), Vector3(3.6, WALL_H * 0.5 + 0.15, -3.0), mats["steel"], "Wall_Vault_South_R")
	_create_wall_box(parent, root, Vector3(2.4, 0.8, WALL_THICK + 0.15), Vector3(0.0, WALL_H - 0.25, -3.0), mats["steel"], "Wall_Vault_South_Lintel")
	_create_wall_box(parent, root, Vector3(0.22, 2.5, 0.45), Vector3(-1.25, 1.35, -3.0), mats["brass"], "Vault_Pillar_L")
	_create_wall_box(parent, root, Vector3(0.22, 2.5, 0.45), Vector3(1.25, 1.35, -3.0), mats["brass"], "Vault_Pillar_R")

	# Entre Garita y Despacho Conservador (X: 6.0 a 15.0 con puerta en X = 8.5 de 1.4m)
	_create_wall_box(parent, root, Vector3(1.8, WALL_H, WALL_THICK), Vector3(6.9, WALL_H * 0.5 + 0.15, -3.0), mats["interior_wall"], "Wall_Sec_Curator_L")
	_create_wall_box(parent, root, Vector3(5.8, WALL_H, WALL_THICK), Vector3(12.1, WALL_H * 0.5 + 0.15, -3.0), mats["interior_wall"], "Wall_Sec_Curator_R")
	_create_wall_box(parent, root, Vector3(1.4, 0.8, WALL_THICK), Vector3(8.5, WALL_H - 0.25, -3.0), mats["interior_wall"], "Wall_Sec_Curator_Lintel")

	# Tabique Longitudinal Oeste (X = -6.0)
	# Entre Galería y Reliquias (Z: -3.0 a 3.5 con gran arco en Z = 0.25 de 2.4m)
	_create_wall_box(parent, root, Vector3(WALL_THICK, WALL_H, 2.05), Vector3(-6.0, WALL_H * 0.5 + 0.15, -1.975), mats["interior_wall"], "Wall_Gal_Relics_N")
	_create_wall_box(parent, root, Vector3(WALL_THICK, WALL_H, 2.05), Vector3(-6.0, WALL_H * 0.5 + 0.15, 2.475), mats["interior_wall"], "Wall_Gal_Relics_S")
	_create_wall_box(parent, root, Vector3(WALL_THICK, 0.8, 2.4), Vector3(-6.0, WALL_H - 0.25, 0.25), mats["interior_wall"], "Wall_Gal_Relics_Lintel")

	# Entre Bóveda y Taller (Z: -9.5 a -3.0 con puerta acorazada de servicio en Z = -6.25 de 1.4m)
	_create_wall_box(parent, root, Vector3(WALL_THICK + 0.15, WALL_H, 2.55), Vector3(-6.0, WALL_H * 0.5 + 0.15, -8.225), mats["steel"], "Wall_Vault_Shop_N")
	_create_wall_box(parent, root, Vector3(WALL_THICK + 0.15, WALL_H, 2.55), Vector3(-6.0, WALL_H * 0.5 + 0.15, -4.275), mats["steel"], "Wall_Vault_Shop_S")
	_create_wall_box(parent, root, Vector3(WALL_THICK + 0.15, 0.8, 1.4), Vector3(-6.0, WALL_H - 0.25, -6.25), mats["steel"], "Wall_Vault_Shop_Lintel")

	# Tabique Longitudinal Este (X = 6.0)
	# Entre Galería y Garita (Z: -3.0 a 3.5 con ventana vigía en Z = -0.75 y puerta en Z = 1.2)
	_create_wall_box(parent, root, Vector3(WALL_THICK, WALL_H, 1.2), Vector3(6.0, WALL_H * 0.5 + 0.15, -2.4), mats["interior_wall"], "Wall_Sec_Gal_N")
	_create_wall_box(parent, root, Vector3(WALL_THICK, 1.0, 2.0), Vector3(6.0, 0.65, -0.75), mats["interior_wall"], "Wall_Sec_Sill")
	_create_wall_box(parent, root, Vector3(WALL_THICK, 0.8, 2.0), Vector3(6.0, WALL_H - 0.25, -0.75), mats["interior_wall"], "Wall_Sec_Window_Top")
	_create_wall_box(parent, root, Vector3(0.06, 1.4, 1.96), Vector3(6.0, 1.85, -0.75), mats["glass"], "Window_Security_Glass")
	_create_wall_box(parent, root, Vector3(WALL_THICK, WALL_H, 0.4), Vector3(6.0, WALL_H * 0.5 + 0.15, 0.35), mats["interior_wall"], "Wall_Sec_Mid_Pillar")
	_create_wall_box(parent, root, Vector3(WALL_THICK, 0.8, 1.4), Vector3(6.0, WALL_H - 0.25, 1.2), mats["interior_wall"], "Wall_Sec_Door_Lintel")
	_create_wall_box(parent, root, Vector3(WALL_THICK, WALL_H, 1.5), Vector3(6.0, WALL_H * 0.5 + 0.15, 2.75), mats["interior_wall"], "Wall_Sec_Gal_S")

	# Entre Bóveda y Despacho Conservador (X = 6.0, Z: -9.5 a -3.0, ciego sin paso directo)
	_create_wall_box(parent, root, Vector3(WALL_THICK + 0.15, WALL_H, 6.5), Vector3(6.0, WALL_H * 0.5 + 0.15, -6.25), mats["steel"], "Wall_Vault_Curator")

	# Entre Despacho Conservador y Generadores (X = 11.0, Z: -9.5 a -3.0 con puerta en Z = -6.25 de 1.3m)
	_create_wall_box(parent, root, Vector3(WALL_THICK, WALL_H, 2.6), Vector3(11.0, WALL_H * 0.5 + 0.15, -8.2), mats["interior_wall"], "Wall_Curator_Gen_N")
	_create_wall_box(parent, root, Vector3(WALL_THICK, WALL_H, 2.6), Vector3(11.0, WALL_H * 0.5 + 0.15, -4.3), mats["interior_wall"], "Wall_Curator_Gen_S")
	_create_wall_box(parent, root, Vector3(WALL_THICK, 0.8, 1.3), Vector3(11.0, WALL_H - 0.25, -6.25), mats["interior_wall"], "Wall_Curator_Gen_Lintel")

func _create_wall_box(parent: Node3D, root: Node3D, size: Vector3, pos: Vector3, mat: StandardMaterial3D, name_str: String) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = name_str
	body.collision_layer = LAYER_WORLD_SOLID
	body.collision_mask = 0
	parent.add_child(body)
	body.owner = root

	var col: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position = pos
	body.add_child(col)
	col.owner = root

	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var bmesh: BoxMesh = BoxMesh.new()
	bmesh.size = size
	bmesh.material = mat
	mesh_inst.mesh = bmesh
	mesh_inst.position = pos
	body.add_child(mesh_inst)
	mesh_inst.owner = root

func _spawn_props(bp: FloorplanBlueprint, parent: Node3D, mats: Dictionary, root: Node3D) -> void:
	# --- 1. Callejón Exterior ---
	# Coche de huida aparcado paralelo al bordillo
	var car_scene: PackedScene = load(MODELS_DIR + "escape_car_84.glb")
	if car_scene:
		var car_inst = car_scene.instantiate()
		car_inst.position = Vector3(-2.0, 0.0, 8.0)
		car_inst.rotation_degrees = Vector3(0.0, 90.0, 0.0)
		parent.add_child(car_inst)
		_setup_owner(car_inst, root)

	# Farola de vapor de sodio
	var street_light: OmniLight3D = OmniLight3D.new()
	street_light.name = "StreetLight"
	street_light.light_color = Color(1.0, 0.75, 0.38)
	street_light.light_energy = 2.6
	street_light.omni_range = 11.0
	street_light.shadow_enabled = true
	street_light.position = Vector3(4.0, 3.5, 6.0)
	parent.add_child(street_light)
	street_light.owner = root

	# Lámpara sobre la puerta de servicio
	var door_lamp: OmniLight3D = OmniLight3D.new()
	door_lamp.name = "DoorLamp"
	door_lamp.light_color = Color(1.0, 0.95, 0.8)
	door_lamp.light_energy = 1.4
	door_lamp.omni_range = 4.5
	door_lamp.position = Vector3(8.5, 2.5, 3.9)
	parent.add_child(door_lamp)
	door_lamp.owner = root

	# --- 2. Gran Galería (Columnas respetando buffer de 1.5m) ---
	var marble_mat = mats["marble"]
	var candidate_col_z: Array[float] = [-2.0, 0.0, 2.0]
	for cz: float in candidate_col_z:
		for cx: float in [-5.4, 5.4]:
			# Verificar si invade alguna zona de exclusión de puertas
			if not bp.is_in_clearance(Vector2(cx, cz), 0.6):
				_spawn_column(parent, root, Vector3(cx, 1.75, cz), marble_mat)

	# Candelabros en la Gran Galería
	var chan_model: PackedScene = load(MODELS_DIR + "chandelier.glb")
	if chan_model:
		for cy: float in [-1.5, 1.5]:
			var chan = chan_model.instantiate()
			chan.position = Vector3(0.0, 3.0, cy)
			parent.add_child(chan)
			_setup_owner(chan, root)

			var clight: OmniLight3D = OmniLight3D.new()
			clight.light_color = Color(1.0, 0.88, 0.65)
			clight.light_energy = 1.5
			clight.omni_range = 6.5
			clight.position = Vector3(0.0, 2.6, cy)
			parent.add_child(clight)
			clight.owner = root

	# Reloj de antesala
	var gclock_model: PackedScene = load(MODELS_DIR + "grandfather_clock.glb")
	if gclock_model and not bp.is_in_clearance(Vector2(4.5, 2.8), 0.5):
		var gclock = gclock_model.instantiate()
		gclock.position = Vector3(4.5, 0.15, 2.8)
		gclock.scale = Vector3(0.85, 0.85, 0.85)
		parent.add_child(gclock)
		_setup_owner(gclock, root)

	# --- 3. Garita de Seguridad ---
	var desk_model: PackedScene = load(MODELS_DIR + "metal_office_desk.glb")
	if desk_model:
		var desk = desk_model.instantiate()
		desk.position = Vector3(9.5, 0.15, -0.75)
		desk.rotation_degrees = Vector3(0, -90, 0)
		parent.add_child(desk)
		_setup_owner(desk, root)

	var monitor_scene: PackedScene = load("res://scenes/entities/cctv_monitor.tscn")
	if monitor_scene:
		var mon1 = monitor_scene.instantiate()
		mon1.name = "CCTVMonitor_01"
		mon1.position = Vector3(9.3, 0.89, -1.2)
		mon1.rotation_degrees = Vector3(0, -80, 0)
		parent.add_child(mon1)
		_setup_owner(mon1, root)

		var mon2 = monitor_scene.instantiate()
		mon2.name = "CCTVMonitor_02"
		mon2.position = Vector3(9.3, 0.89, -0.3)
		mon2.rotation_degrees = Vector3(0, -100, 0)
		parent.add_child(mon2)
		_setup_owner(mon2, root)

	var guarida_light: OmniLight3D = OmniLight3D.new()
	guarida_light.light_color = Color(0.85, 0.92, 1.0)
	guarida_light.light_energy = 1.3
	guarida_light.omni_range = 6.0
	guarida_light.position = Vector3(9.5, 2.7, 0.0)
	parent.add_child(guarida_light)
	guarida_light.owner = root

	# --- 4. Ala de Reliquias ---
	var display_model: PackedScene = load(MODELS_DIR + "museum_display_case.glb")
	if display_model:
		for vz: float in [-1.5, 1.5]:
			if not bp.is_in_clearance(Vector2(-10.5, vz), 0.6):
				var dc = display_model.instantiate()
				dc.position = Vector3(-10.5, 0.15, vz)
				parent.add_child(dc)
				_setup_owner(dc, root)

	var relic_light: OmniLight3D = OmniLight3D.new()
	relic_light.light_color = Color(1.0, 0.88, 0.70)
	relic_light.light_energy = 1.4
	relic_light.omni_range = 7.5
	relic_light.position = Vector3(-10.5, 2.7, 0.0)
	parent.add_child(relic_light)
	relic_light.owner = root

	# --- 5. Despacho del Conservador ---
	var curator_desk: PackedScene = load(MODELS_DIR + "metal_office_desk.glb")
	if curator_desk:
		var c_desk = curator_desk.instantiate()
		c_desk.position = Vector3(8.5, 0.15, -6.5)
		parent.add_child(c_desk)
		_setup_owner(c_desk, root)

	var phone_model: PackedScene = load(MODELS_DIR + "rotary_phone_84.glb")
	if phone_model:
		var phone = phone_model.instantiate()
		phone.position = Vector3(8.5, 0.90, -6.5)
		phone.scale = Vector3(0.7, 0.7, 0.7)
		parent.add_child(phone)
		_setup_owner(phone, root)

	var safe_model: PackedScene = load(MODELS_DIR + "safe_box_84.glb")
	if safe_model:
		var wall_safe = safe_model.instantiate()
		wall_safe.name = "CuratorWallSafe"
		wall_safe.position = Vector3(9.5, 0.15, -8.8)
		parent.add_child(wall_safe)
		_setup_owner(wall_safe, root)

	var curator_light: OmniLight3D = OmniLight3D.new()
	curator_light.light_color = Color(1.0, 0.85, 0.60)
	curator_light.light_energy = 1.3
	curator_light.omni_range = 5.5
	curator_light.position = Vector3(8.5, 2.6, -6.25)
	parent.add_child(curator_light)
	curator_light.owner = root

	# --- 6. Taller de Restauración ---
	var vase_model: PackedScene = load(MODELS_DIR + "ceramic_vase.glb")
	if vase_model:
		var vase = vase_model.instantiate()
		vase.position = Vector3(-12.5, 0.15, -6.25)
		parent.add_child(vase)
		_setup_owner(vase, root)

	var frame_model: PackedScene = load(MODELS_DIR + "picture_frame.glb")
	if frame_model:
		var frame = frame_model.instantiate()
		frame.position = Vector3(-10.5, 1.8, -9.3)
		frame.scale = Vector3(0.9, 0.9, 0.9)
		parent.add_child(frame)
		_setup_owner(frame, root)

	var workshop_light: OmniLight3D = OmniLight3D.new()
	workshop_light.light_color = Color(0.90, 0.92, 0.95)
	workshop_light.light_energy = 1.3
	workshop_light.omni_range = 6.0
	workshop_light.position = Vector3(-10.5, 2.6, -6.25)
	parent.add_child(workshop_light)
	workshop_light.owner = root

	# --- 7. Sala de Generadores ---
	var gen_light: OmniLight3D = OmniLight3D.new()
	gen_light.name = "GeneratorLight"
	gen_light.light_color = Color(1.0, 0.60, 0.40)
	gen_light.light_energy = 1.1
	gen_light.omni_range = 5.0
	gen_light.position = Vector3(13.0, 2.5, -6.25)
	parent.add_child(gen_light)
	gen_light.owner = root

	# --- 8. Cámara Acorazada (Bóveda) ---
	if display_model:
		var v_case = display_model.instantiate()
		v_case.position = Vector3(0.0, 0.15, -6.25)
		parent.add_child(v_case)
		_setup_owner(v_case, root)

	var masterpiece_scene: PackedScene = load("res://scenes/entities/loot_masterpiece_item.tscn")
	if masterpiece_scene:
		var mp = masterpiece_scene.instantiate()
		mp.name = "MasterpieceItem"
		mp.position = Vector3(0.0, 1.03, -6.25)
		parent.add_child(mp)
		_setup_owner(mp, root)

	var vault_spot: SpotLight3D = SpotLight3D.new()
	vault_spot.name = "VaultMasterpieceSpot"
	vault_spot.light_color = Color(1.0, 0.82, 0.45)
	vault_spot.light_energy = 2.8
	vault_spot.spot_range = 6.0
	vault_spot.spot_angle = 30.0
	vault_spot.position = Vector3(0.0, 3.2, -6.25)
	vault_spot.rotation_degrees = Vector3(-90, 0, 0)
	vault_spot.shadow_enabled = true
	parent.add_child(vault_spot)
	vault_spot.owner = root

	if safe_model:
		var v_safe = safe_model.instantiate()
		v_safe.name = "VaultSafeBox"
		v_safe.position = Vector3(-3.5, 0.15, -7.5)
		parent.add_child(v_safe)
		_setup_owner(v_safe, root)

func _spawn_column(parent: Node3D, root: Node3D, pos: Vector3, mat: Material) -> void:
	var col_node: StaticBody3D = StaticBody3D.new()
	col_node.name = "Pillar_Column"
	col_node.collision_layer = LAYER_WORLD_SOLID
	col_node.collision_mask = 0
	parent.add_child(col_node)
	col_node.owner = root

	var col_shape: CollisionShape3D = CollisionShape3D.new()
	var cyl_shape: CylinderShape3D = CylinderShape3D.new()
	cyl_shape.radius = 0.22
	cyl_shape.height = WALL_H
	col_shape.shape = cyl_shape
	col_shape.position = pos
	col_node.add_child(col_shape)
	col_shape.owner = root

	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var cyl_mesh: CylinderMesh = CylinderMesh.new()
	cyl_mesh.top_radius = 0.22
	cyl_mesh.bottom_radius = 0.22
	cyl_mesh.height = WALL_H
	cyl_mesh.material = mat
	mesh_inst.mesh = cyl_mesh
	mesh_inst.position = pos
	col_node.add_child(mesh_inst)
	mesh_inst.owner = root

func _setup_owner(node: Node, root_node: Node) -> void:
	node.owner = root_node
