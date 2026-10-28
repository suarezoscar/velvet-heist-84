## @file heist_builder.gd
## Coloca el golpe de un nivel por datos (heist.md): el HeistDirector, las piezas candidatas
## (sección «targets», con su protección y su variante: pedestal, vitrina o caja fuerte) y las
## salidas exteriores (sección «exits»). Lo llama LevelEntitiesBuilder.
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
	for target: Dictionary in targets:
		_add_target(data, props, target)
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


static func _add_target(data: LevelData, props: Node3D, target: Dictionary) -> void:
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
		return
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
