## @file heist_builder.gd
## Coloca el golpe de un nivel por datos (heist.md): el HeistDirector, las piezas candidatas
## (sección «targets», con su protección y su variante: pedestal, vitrina o caja fuerte), las
## salidas exteriores («exits»), los cuadros eléctricos de cada ala («wings»), la mesa de
## réplicas («replica_table») y el panel de pilotos («pilot_panel»). Lo llama
## LevelEntitiesBuilder.
class_name HeistBuilder
extends RefCounted

const SAFE_MODEL: PackedScene = preload("res://assets/models/safe_box_84.glb")
const CASE_MODEL: PackedScene = preload("res://assets/models/museum_display_case.glb")
const SAFE_SIZE: Vector3 = Vector3(0.8, 1.8, 0.8)
const CASE_SIZE: Vector3 = Vector3(0.9, 1.2, 0.9)
const EXIT_HEIGHT: float = 2.5
const COFFEE_MODEL: PackedScene = preload("res://assets/models/coffee_cart.glb")
## Zona de la cafetera: algo mayor que el carrito (2,17 × 1,07 m) para alcanzarla con E
const COFFEE_AREA: Vector3 = Vector3(2.6, 1.8, 1.6)


static func build(data: LevelData, props: Node3D, targets: Array) -> void:
	var boxes: Array[PowerBox3D] = _add_wings(data, props)
	for target: Dictionary in targets:
		var piece: TargetPiece3D = _add_target(data, props, target)
		for box: PowerBox3D in boxes:
			if piece.protection == &"sensor" and box.contains(piece.position):
				piece.power_box = box
	if not data.entry("replica_table").is_empty():
		var table: ReplicaTable3D = ReplicaTable3D.create()
		table.position = data.to_world(data.entry("replica_table")["pos"])
		props.add_child(table)
	if not data.entry("pilot_panel").is_empty():
		var panel: PilotPanel3D = PilotPanel3D.new()
		panel.position = data.to_world(data.entry("pilot_panel")["pos"])
		props.add_child(panel)
	for exit_data: Dictionary in data.section("exits"):
		var size: Array = exit_data["size"]
		var zone: ExitZone3D = ExitZone3D.create(
			String(exit_data["id"]), Vector3(float(size[0]), EXIT_HEIGHT, float(size[1]))
		)
		zone.position = data.to_world(exit_data["pos"])
		props.add_child(zone)
	var director: HeistDirector = HeistDirector.new()
	props.add_child(director)
	director.add_child(AlertDirector.new())
	props.add_child(HeistInput.new())


## La cafetera de la garita y el sueño de cada guardia de la escena (heist.md R5)
static func build_coffee(data: LevelData, props: Node3D, map: Node3D, coffee: Dictionary) -> void:
	var machine: CoffeeMachine3D = CoffeeMachine3D.new()
	machine.name = "CoffeeMachine"
	machine.position = data.to_world(coffee["pos"])
	machine.rotation.y = deg_to_rad(-float(coffee.get("rot_deg", 0.0)))
	LevelEntitiesBuilder._setup_area(machine, COFFEE_AREA, COFFEE_MODEL)
	props.add_child(machine)
	for child: Node in map.get_children():
		if child is GuardController3D and child.get_node_or_null("Sleep") == null:
			GuardSleep.attach(child as GuardController3D)


## Sala de un punto del nivel (nombre), para que el ladrón sepa dónde buscar
static func room_name_at(data: LevelData, point: Array) -> String:
	for room: Dictionary in data.section("rooms"):
		if data.room_rect(room).has_point(Vector2(float(point[0]), float(point[1]))):
			return String(room.get("name", room.get("id", "")))
	return ""


## Un cuadro eléctrico por ala, con sus circuitos y sus salas
static func _add_wings(data: LevelData, props: Node3D) -> Array[PowerBox3D]:
	var boxes: Array[PowerBox3D] = []
	for wing: Dictionary in data.section("wings"):
		var circuits: Array[int] = []
		circuits.assign(wing.get("circuits", []))
		var box: PowerBox3D = PowerBox3D.create(
			StringName(wing["id"]), String(wing["name"]), circuits
		)
		for room_id: Variant in wing.get("rooms", []):
			var rect: Rect2 = data.room_rect(data.room_by_id(String(room_id)))
			var corner: Vector3 = data.to_world([rect.position.x, rect.position.y])
			box.areas.append(Rect2(Vector2(corner.x, corner.z), rect.size))
		var box_data: Dictionary = wing["box"]
		box.position = data.to_world(box_data["pos"])
		box.rotation.y = deg_to_rad(-float(box_data.get("rot_deg", 0.0)))
		props.add_child(box)
		boxes.append(box)
	return boxes


static func _add_target(data: LevelData, props: Node3D, target: Dictionary) -> TargetPiece3D:
	var variant: StringName = StringName(target.get("variant", "pedestal"))
	var model_path: String = "res://assets/models/%s.glb" % target.get("model", "loot_cash")
	var piece: TargetPiece3D = TargetPiece3D.create(
		StringName(target["id"]),
		String(target["name"]),
		StringName(target.get("protection", "combination")),
		load(model_path) as PackedScene,
		variant
	)
	piece.room_name = room_name_at(data, target["pos"])
	piece.position = data.to_world(target["pos"])
	props.add_child(piece)
	if variant == &"pedestal":
		return piece
	var lock: SafeBox3D = SafeBox3D.new()
	lock.name = "Lock_%s" % target["id"]
	lock.lock_name = "caja fuerte" if variant == &"safe" else "vitrina"
	lock.breakable = variant == &"case"
	var combination: Array[int] = []
	combination.assign(target.get("combination", [30, 65, 15]))
	lock.combination = combination
	lock.contained_target = piece
	lock.position = piece.position
	LevelEntitiesBuilder._setup_area(
		lock,
		SAFE_SIZE if variant == &"safe" else CASE_SIZE,
		SAFE_MODEL if variant == &"safe" else CASE_MODEL
	)
	props.add_child(lock)
	piece.lock = lock
	return piece
