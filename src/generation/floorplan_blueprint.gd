## @file floorplan_blueprint.gd
## Estructura de datos y generador de Blueprint 2D para Velvet Heist 84.
## Define habitaciones contiguas, muros compartidos, vanos de paso y zonas de exclusión (1.5m).

class_name FloorplanBlueprint
extends RefCounted

enum RoomType {
	ALLEY_EXTERIOR,
	GREAT_GALLERY,
	RELIC_WING,
	SECURITY_LAIR,
	CURATOR_OFFICE,
	RESTORATION_WORKSHOP,
	GENERATOR_ROOM,
	VAULT
}

class RoomData:
	var id: String = ""
	var name: String = ""
	var room_type: RoomType = RoomType.GREAT_GALLERY
	var bounds: Rect2 = Rect2() # X = min_x, Y = min_z, W = width, H = depth
	var elevation_y: float = 0.05
	var floor_material: String = "marble"
	var noise_multiplier: float = 1.0

	func contains_point(pt_xz: Vector2) -> bool:
		return bounds.has_point(pt_xz)

class DoorwayData:
	var id: String = ""
	var room_a_id: String = ""
	var room_b_id: String = ""
	var center: Vector3 = Vector3.ZERO
	var width: float = 1.8
	var wall_axis: int = 0 # 0 = Muro paralelo a X (normal Z), 1 = Muro paralelo a Z (normal X)
	var clearance_box: Rect2 = Rect2() # En coordenadas XZ
	var is_front_facade: bool = false
	var is_reinforced: bool = false

var rooms: Dictionary = {} # String -> RoomData
var doors: Array[DoorwayData] = []
var clearance_zones: Array[Rect2] = []

## Comprueba si un punto XZ o radio invade alguna zona de despeje de puertas (buffer 1.5m).
func is_in_clearance(pos_xz: Vector2, radius: float = 0.4) -> bool:
	for zone: Rect2 in clearance_zones:
		var expanded: Rect2 = zone.grow(radius)
		if expanded.has_point(pos_xz):
			return true
	return false

## Genera el plano ortogonal completo de 8 salas del Museo Metropolitano 1984.
static func generate_museum_1984():
	var bp = load("res://src/generation/floorplan_blueprint.gd").new()

	# --- 1. SALAS Y HABITACIONES ---
	# Callejón Exterior (Asfalto húmedo)
	var alley: RoomData = RoomData.new()
	alley.id = "alley_road"
	alley.name = "Callejón Exterior"
	alley.room_type = RoomType.ALLEY_EXTERIOR
	alley.bounds = Rect2(-15.0, 5.0, 30.0, 7.0)
	alley.elevation_y = -0.10
	alley.floor_material = "asphalt"
	alley.noise_multiplier = 1.0
	bp.rooms[alley.id] = alley

	# Acera Perimetral con Bordillo (+0.15m)
	var sidewalk: RoomData = RoomData.new()
	sidewalk.id = "sidewalk"
	sidewalk.name = "Acera Perimetral"
	sidewalk.room_type = RoomType.ALLEY_EXTERIOR
	sidewalk.bounds = Rect2(-15.0, 3.5, 30.0, 1.5)
	sidewalk.elevation_y = 0.075
	sidewalk.floor_material = "sidewalk"
	sidewalk.noise_multiplier = 1.0
	bp.rooms[sidewalk.id] = sidewalk

	# Gran Galería Central (Mármol Damero)
	var gallery: RoomData = RoomData.new()
	gallery.id = "great_gallery"
	gallery.name = "Gran Galería de Arte"
	gallery.room_type = RoomType.GREAT_GALLERY
	gallery.bounds = Rect2(-6.0, -3.0, 12.0, 6.5)
	gallery.elevation_y = 0.05
	gallery.floor_material = "marble"
	gallery.noise_multiplier = 1.6
	bp.rooms[gallery.id] = gallery

	# Ala de Reliquias (Parqué de Roble)
	var relics: RoomData = RoomData.new()
	relics.id = "relic_wing"
	relics.name = "Ala de Reliquias"
	relics.room_type = RoomType.RELIC_WING
	relics.bounds = Rect2(-15.0, -3.0, 9.0, 6.5)
	relics.elevation_y = 0.05
	relics.floor_material = "parquet"
	relics.noise_multiplier = 1.4
	bp.rooms[relics.id] = relics

	# Garita de Seguridad y CCTV (Linóleo)
	var security: RoomData = RoomData.new()
	security.id = "security_lair"
	security.name = "Garita de Seguridad"
	security.room_type = RoomType.SECURITY_LAIR
	security.bounds = Rect2(6.0, -3.0, 9.0, 6.5)
	security.elevation_y = 0.05
	security.floor_material = "linoleum"
	security.noise_multiplier = 1.2
	bp.rooms[security.id] = security

	# Taller de Restauración y Almacén (Cemento Pulido)
	var workshop: RoomData = RoomData.new()
	workshop.id = "restoration_workshop"
	workshop.name = "Taller de Restauración"
	workshop.room_type = RoomType.RESTORATION_WORKSHOP
	workshop.bounds = Rect2(-15.0, -9.5, 9.0, 6.5)
	workshop.elevation_y = 0.05
	workshop.floor_material = "concrete"
	workshop.noise_multiplier = 1.1
	bp.rooms[workshop.id] = workshop

	# Cámara Acorazada / Bóveda (Terciopelo Carmesí)
	var vault: RoomData = RoomData.new()
	vault.id = "vault"
	vault.name = "Cámara Acorazada"
	vault.room_type = RoomType.VAULT
	vault.bounds = Rect2(-6.0, -9.5, 12.0, 6.5)
	vault.elevation_y = 0.05
	vault.floor_material = "velvet"
	vault.noise_multiplier = 0.4
	bp.rooms[vault.id] = vault

	# Despacho del Conservador (Moqueta Noble)
	var curator: RoomData = RoomData.new()
	curator.id = "curator_office"
	curator.name = "Despacho del Conservador"
	curator.room_type = RoomType.CURATOR_OFFICE
	curator.bounds = Rect2(6.0, -9.5, 5.0, 6.5)
	curator.elevation_y = 0.05
	curator.floor_material = "carpet"
	curator.noise_multiplier = 0.6
	bp.rooms[curator.id] = curator

	# Sala de Generadores / Cuadro Eléctrico (Rejilla Metálica)
	var generators: RoomData = RoomData.new()
	generators.id = "generator_room"
	generators.name = "Sala de Generadores"
	generators.room_type = RoomType.GENERATOR_ROOM
	generators.bounds = Rect2(11.0, -9.5, 4.0, 6.5)
	generators.elevation_y = 0.05
	generators.floor_material = "grate"
	generators.noise_multiplier = 1.5
	bp.rooms[generators.id] = generators

	# --- 2. PUERTAS, VANOS Y ZONAS DE EXCLUSIÓN ---
	bp._add_door("door_service_ext", "sidewalk", "security_lair", Vector3(8.5, 0.0, 3.5), 1.6, 0, true, false)
	bp._add_door("arch_gallery_relics", "great_gallery", "relic_wing", Vector3(-6.0, 0.0, 0.25), 2.4, 1, false, false)
	bp._add_door("door_security_gallery", "great_gallery", "security_lair", Vector3(6.0, 0.0, 1.2), 1.4, 1, false, false)
	bp._add_door("portal_vault", "great_gallery", "vault", Vector3(0.0, 0.0, -3.0), 2.4, 0, false, true)
	bp._add_door("door_relics_workshop", "relic_wing", "restoration_workshop", Vector3(-10.5, 0.0, -3.0), 1.6, 0, false, false)
	bp._add_door("door_security_curator", "security_lair", "curator_office", Vector3(8.5, 0.0, -3.0), 1.4, 0, false, false)
	bp._add_door("door_curator_generators", "curator_office", "generator_room", Vector3(11.0, 0.0, -6.25), 1.3, 1, false, false)
	bp._add_door("door_workshop_vault", "restoration_workshop", "vault", Vector3(-6.0, 0.0, -6.25), 1.4, 1, false, true)

	return bp

func _add_door(id: String, room_a: String, room_b: String, center: Vector3, width: float, wall_axis: int, is_facade: bool, is_reinf: bool) -> void:
	var d: DoorwayData = DoorwayData.new()
	d.id = id
	d.room_a_id = room_a
	d.room_b_id = room_b
	d.center = center
	d.width = width
	d.wall_axis = wall_axis
	d.is_front_facade = is_facade
	d.is_reinforced = is_reinf

	# Buffer de 1.5 metros a ambos lados del vano de paso
	var buffer_depth: float = 1.5
	var clear_w: float = width + 0.4
	if wall_axis == 0: # Muro en X, paso en Z
		d.clearance_box = Rect2(center.x - clear_w * 0.5, center.z - buffer_depth, clear_w, buffer_depth * 2.0)
	else: # Muro en Z, paso en X
		d.clearance_box = Rect2(center.x - buffer_depth, center.z - clear_w * 0.5, buffer_depth * 2.0, clear_w)

	doors.append(d)
	clearance_zones.append(d.clearance_box)
