## Coloca las entidades de un nivel por datos (FEAT-015): lámparas, interruptores, botín, caja
## fuerte, relojes de fichar, cámaras y monitores, coche de huida, apariciones y patrullas.
## Reutiliza las escenas de scenes/entities y los scripts de src/systems; los nombres de nodo
## salen de los ids del JSON, así que son iguales en servidor y clientes.
class_name LevelEntitiesBuilder
extends RefCounted

const LAMP_SCENE: PackedScene = preload("res://scenes/entities/lamp.tscn")
const SWITCH_SCENE: PackedScene = preload("res://scenes/entities/light_switch.tscn")
const LOOT_LIGHT_SCENE: PackedScene = preload("res://scenes/entities/loot_cash_item.tscn")
const LOOT_HEAVY_SCENE: PackedScene = preload("res://scenes/entities/loot_masterpiece_item.tscn")
const CAMERA_SCENE: PackedScene = preload("res://scenes/entities/security_camera.tscn")
const MONITOR_SCENE: PackedScene = preload("res://scenes/entities/cctv_monitor.tscn")
const SAFE_MODEL: PackedScene = preload("res://assets/models/safe_box_84.glb")
const CLOCK_MODEL: PackedScene = preload("res://assets/models/grandfather_clock.glb")
const CAR_MODEL: PackedScene = preload("res://assets/models/escape_car_84.glb")
const GUARD_AI_SCRIPT: Script = preload("res://src/entities/guard/guard_ai_3d.gd")

## Altura de montaje por tipo de lámpara (m)
const LAMP_HEIGHTS: Dictionary = {"ceiling": 3.0, "desk": 1.0, "street": 3.5}
const SWITCH_HEIGHT: float = 1.2
const CAMERA_HEIGHT: float = 2.9
const CAMERA_PITCH_DEG: float = -15.0
const MONITOR_HEIGHT: float = 0.8
## Mesa de monitores (ejes locales: x a lo largo de la mesa, z hacia el guardia)
const DESK_AREA_SIZE: Vector3 = Vector3(3.6, 1.2, 1.6)
const DESK_TABLE_SIZE: Vector3 = Vector3(3.6, 0.75, 0.7)
## Altura de los actores al aparecer (centro de la cápsula sobre el suelo)
const ACTOR_HEIGHT: float = 0.35
## Capas de interacción que usan los Area3D de sistemas (como en el museo antiguo)
const INTERACTABLE_LAYER: int = 4
const INTERACTOR_MASK: int = 2


## Crea el nodo Props con las entidades y coloca a los actores ya presentes en map
static func build(data: LevelData, map: Node3D) -> Node3D:
	var props: Node3D = Node3D.new()
	props.name = "Props"
	map.add_child(props)
	for lamp: Dictionary in data.section("lamps"):
		_add_lamp(data, props, lamp)
	for switch_data: Dictionary in data.section("switches"):
		var light_switch: LightSwitch3D = SWITCH_SCENE.instantiate() as LightSwitch3D
		light_switch.name = "Switch_%s" % switch_data["id"]
		light_switch.circuit_id = int(switch_data["circuit"])
		light_switch.position = data.to_world(switch_data["pos"], SWITCH_HEIGHT)
		props.add_child(light_switch)
	for loot: Dictionary in data.section("loot"):
		_add_loot(data, props, loot)
	if not data.entry("safe").is_empty():
		_add_safe(data, props, data.entry("safe"))
	for clock: Dictionary in data.section("clocks"):
		_add_clock(data, props, clock)
	var cameras: Dictionary = {}
	for cam: Dictionary in data.section("cameras"):
		cameras[String(cam["id"])] = _add_camera(data, props, cam)
	for monitor: Dictionary in data.section("monitors"):
		_add_monitor(data, props, monitor, cameras)
	if not data.entry("cctv_desk").is_empty():
		_add_desk(data, props, data.entry("cctv_desk"))
	if not data.entry("car").is_empty():
		_add_car(data, props, data.entry("car"))
	_place_actors(data, map)
	return props


static func _add_lamp(data: LevelData, props: Node3D, lamp: Dictionary) -> void:
	var lamp_type: String = String(lamp.get("type", "ceiling"))
	var node: Lamp3D = LAMP_SCENE.instantiate() as Lamp3D
	node.name = "Lamp_%s" % lamp["id"]
	node.profile = load("res://data/balance/lamp_%s.tres" % lamp_type) as LampProfile
	node.circuit_id = int(lamp.get("circuit", 0))
	node.start_on = bool(lamp.get("on", true))
	node.position = data.to_world(lamp["pos"], LAMP_HEIGHTS.get(lamp_type, 3.0))
	props.add_child(node)


static func _add_loot(data: LevelData, props: Node3D, loot: Dictionary) -> void:
	var heavy: bool = bool(loot.get("heavy", false))
	var item: LootItem3D = (
		(LOOT_HEAVY_SCENE if heavy else LOOT_LIGHT_SCENE).instantiate() as LootItem3D
	)
	item.name = "Loot_%s" % loot["id"]
	item.loot_name = String(loot.get("name", item.loot_name))
	item.loot_value = int(loot.get("value", item.loot_value))
	item.is_heavy = heavy
	item.is_masterpiece = bool(loot.get("masterpiece", false))
	item.position = data.to_world(loot["pos"])
	props.add_child(item)


static func _add_safe(data: LevelData, props: Node3D, safe: Dictionary) -> void:
	var node: SafeBox3D = SafeBox3D.new()
	node.name = "SafeBox3D"
	node.loot_inside_scene = LOOT_LIGHT_SCENE
	node.position = data.to_world(safe["pos"])
	_setup_area(node, Vector3(0.8, 1.8, 0.8), SAFE_MODEL)
	props.add_child(node)


static func _add_clock(data: LevelData, props: Node3D, clock: Dictionary) -> void:
	var node: TimeClock3D = TimeClock3D.new()
	node.name = "TimeClock_%02d" % int(clock["id"])
	node.clock_id = int(clock["id"])
	node.position = data.to_world(clock["pos"])
	node.rotation.y = deg_to_rad(-float(clock.get("rot_deg", 0.0)))
	_setup_area(node, Vector3(0.6, 2.0, 0.4), CLOCK_MODEL)
	props.add_child(node)


static func _add_camera(data: LevelData, props: Node3D, cam: Dictionary) -> SecurityCamera3D:
	var node: SecurityCamera3D = CAMERA_SCENE.instantiate() as SecurityCamera3D
	node.name = "Camera_%s" % String(cam["id"]).replace("-", "_")
	node.camera_id = String(cam["id"])
	node.camera_label = String(cam.get("label", cam["id"]))
	node.position = data.to_world(cam["pos"], CAMERA_HEIGHT)
	node.rotation_degrees = Vector3(CAMERA_PITCH_DEG, -float(cam.get("yaw_deg", 0.0)), 0.0)
	props.add_child(node)
	return node


static func _add_monitor(
	data: LevelData, props: Node3D, monitor: Dictionary, cameras: Dictionary
) -> void:
	var node: CCTVMonitor3D = MONITOR_SCENE.instantiate() as CCTVMonitor3D
	var cam_id: String = String(monitor["camera"])
	node.name = "Monitor_%s" % cam_id.replace("-", "_")
	node.monitor_title = cam_id
	node.position = data.to_world(monitor["pos"], MONITOR_HEIGHT)
	node.rotation.y = deg_to_rad(-float(monitor.get("rot_deg", 0.0)))
	props.add_child(node)
	if cameras.has(cam_id):
		node.bind_camera(cameras[cam_id])


## Mesa de monitores: zona interactuable delante de las pantallas y el tablero que las sostiene
static func _add_desk(data: LevelData, props: Node3D, desk: Dictionary) -> void:
	var node: CCTVDesk3D = CCTVDesk3D.new()
	node.name = "CCTVDesk3D"
	node.position = data.to_world(desk["pos"])
	node.rotation.y = deg_to_rad(-float(desk.get("rot_deg", 0.0)))
	_setup_area(node, DESK_AREA_SIZE, null)
	var table: StaticBody3D = StaticBody3D.new()
	table.name = "Table"
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = DESK_TABLE_SIZE
	var col: CollisionShape3D = CollisionShape3D.new()
	col.shape = shape
	table.add_child(col)
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = DESK_TABLE_SIZE
	mesh_instance.mesh = mesh
	table.add_child(mesh_instance)
	table.position = Vector3(0.0, DESK_TABLE_SIZE.y * 0.5, 0.0)
	node.add_child(table)
	props.add_child(node)


static func _add_car(data: LevelData, props: Node3D, car: Dictionary) -> void:
	var node: EscapeCar3D = EscapeCar3D.new()
	node.name = "EscapeCar3D"
	node.position = data.to_world(car["pos"])
	node.rotation.y = deg_to_rad(-float(car.get("rot_deg", 0.0)))
	_setup_area(node, Vector3(2.0, 1.8, 4.2), CAR_MODEL)
	props.add_child(node)


## Área interactuable con su caja de colisión apoyada en el suelo y su modelo
static func _setup_area(area: Area3D, size: Vector3, model: PackedScene) -> void:
	area.collision_layer = INTERACTABLE_LAYER
	area.collision_mask = INTERACTOR_MASK
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "CollisionShape3D"
	col.shape = shape
	col.position = Vector3(0.0, size.y * 0.5, 0.0)
	area.add_child(col)
	if model == null:
		return
	var visual: Node3D = model.instantiate() as Node3D
	visual.name = "Model"
	area.add_child(visual)


## Mueve al ladrón y a los guardias de la escena a sus apariciones y da a cada guardia su
## patrulla (los guardias, en orden de escena)
static func _place_actors(data: LevelData, map: Node3D) -> void:
	var spawns: Dictionary = data.entry("spawns")
	var patrols: Array = data.section("patrols")
	var guard_index: int = 0
	for child: Node in map.get_children():
		if child is ThiefController3D and spawns.has("thief"):
			(child as Node3D).position = data.to_world(spawns["thief"], ACTOR_HEIGHT)
		elif child is GuardController3D:
			var guard_spawns: Array = spawns.get("guards", [])
			if guard_index < guard_spawns.size():
				(child as Node3D).position = data.to_world(guard_spawns[guard_index], ACTOR_HEIGHT)
			if guard_index < patrols.size():
				_add_patrol(data, child as GuardController3D, patrols[guard_index])
			guard_index += 1


static func _add_patrol(data: LevelData, guard: GuardController3D, points: Array) -> void:
	var ai: Node = guard.get_node_or_null("GuardAI")
	if ai == null:
		ai = Node.new()
		ai.name = "GuardAI"
		ai.set_script(GUARD_AI_SCRIPT)
		guard.add_child(ai)
	var waypoints: Array[Vector3] = []
	for point: Array in points:
		waypoints.append(data.to_world(point, ACTOR_HEIGHT))
	ai.set("patrol_waypoints", waypoints)
	guard.is_ai_controlled = true
