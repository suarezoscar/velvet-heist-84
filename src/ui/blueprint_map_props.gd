## @file blueprint_map_props.gd
## Objetos interactivos del plano (#117): cafetera, monitores, cuadros eléctricos,
## interruptores, lámparas, mesa de copias, coche de huida y objetos sueltos.
## Las puertas, las piezas (con su caja fuerte), las cámaras y las rejillas las dibuja
## BlueprintMapOverlay.
## Se buscan una vez al abrir el plano (collect) y cada icono sale con su estado actual; con el
## cursor encima de un interruptor o un cuadro se ven los cables a sus lámparas (draw_wiring).
class_name BlueprintMapProps
extends RefCounted

const ICONS := preload("res://src/ui/blueprint_map_icons.gd")
## Píxeles alrededor de un interruptor o cuadro para enseñar sus cables
const HOVER_RADIUS: float = 18.0


## Los objetos interactivos bajo root (la escena del mapa)
static func collect(root: Node) -> Array[Node3D]:
	var found: Array[Node3D] = []
	if root == null:
		return found
	for node: Node in root.find_children("*", "Node3D", true, false):
		if kind_of(node) != &"":
			found.append(node as Node3D)
	return found


## Qué icono le toca a node (&"" si no es un objeto del plano)
static func kind_of(node: Node) -> StringName:
	if node is CoffeeMachine3D:
		return &"coffee"
	if node is CCTVDesk3D:
		return &"desk"
	if node is PowerBox3D:
		return &"power"
	if node is LightSwitch3D:
		return &"switch"
	if node is Lamp3D:
		return &"lamp"
	if node is ReplicaTable3D:
		return &"copy"
	if node is EscapeCar3D:
		return &"car"
	if node is LootItem3D:
		return &"loot"
	return &""


## true si prop sigue en el mapa (un objeto suelto ya recogido no sale)
static func shown(prop: Node3D) -> bool:
	if not is_instance_valid(prop) or not prop.is_inside_tree():
		return false
	return not (prop is LootItem3D and not prop.visible)


## Un icono suelto (también para la leyenda, con prop null)
static func icon(on: CanvasItem, kind: StringName, pos: Vector2, prop: Node3D = null) -> void:
	match kind:
		&"coffee":
			ICONS.cup(on, pos, ICONS.COLOR_POST)
		&"desk":
			ICONS.badge(on, pos, ICONS.COLOR_DESK, &"tv")
		&"power":
			ICONS.power(on, pos, prop != null and (prop as PowerBox3D).is_cut)
		&"switch":
			ICONS.light_switch(on, pos)
		&"lamp":
			ICONS.lamp(on, pos, prop == null or (prop as Lamp3D).is_lit())
		&"copy":
			ICONS.badge(on, pos, ICONS.COLOR_COPY, &"easel")
		&"car":
			ICONS.car(on, pos)
		&"loot":
			ICONS.badge(on, pos, ICONS.COLOR_LOOT, &"coins")


## Cables: con el cursor sobre un interruptor o un cuadro eléctrico, líneas a sus lámparas
static func draw_wiring(
	on: CanvasItem, props: Array[Node3D], lamps: Array[Lamp3D], mouse: Vector2, to_map: Callable
) -> void:
	ICONS.at(on, Vector2.ZERO, 1.0)
	for prop: Node3D in props:
		if not (prop is LightSwitch3D or prop is PowerBox3D) or not shown(prop):
			continue
		var from: Vector2 = to_map.call(prop.global_position)
		if from.distance_to(mouse) > HOVER_RADIUS:
			continue
		for lamp: Lamp3D in lamps:
			if is_instance_valid(lamp) and _feeds(prop, lamp):
				var to: Vector2 = to_map.call(lamp.global_position)
				on.draw_dashed_line(from, to, Color(ICONS.COLOR_POWER, 0.7), 1.5, 6.0)
				ICONS.lamp(on, to, lamp.is_lit())
				on.draw_arc(to, 6.0, 0.0, TAU, 16, Color(ICONS.COLOR_POWER, 0.9), 1.5)


## true si prop (interruptor o cuadro) alimenta lamp
static func _feeds(prop: Node3D, lamp: Lamp3D) -> bool:
	if prop is LightSwitch3D:
		return (prop as LightSwitch3D).circuit_id == lamp.circuit_id
	return (prop as PowerBox3D).circuits.has(lamp.circuit_id)


## Cámaras con el abanico que cubren al barrer (orientación del nivel, alcance de la cámara),
## recortado a la sala hacia la que miran: no atraviesa paredes. k: escala de la chapa (zoom)
static func draw_cameras(on: CanvasItem, data: LevelData, to_map: Callable, k: float = 1.0) -> void:
	var tree: SceneTree = (on as Node).get_tree()
	var sample: SecurityCamera3D = (
		tree.get_first_node_in_group(&"security_camera") as SecurityCamera3D
	)
	var fov: float = sample.detection_fov_deg if sample != null else 52.0
	var sweep: float = sample.sweep_angle_deg if sample != null else 65.0
	var reach: float = sample.detection_range if sample != null else 9.5
	var half: float = deg_to_rad((fov + sweep) * 0.5)
	for cam: Dictionary in data.section("cameras"):
		var yaw: float = deg_to_rad(float(cam.get("yaw_deg", 0.0)))
		var dir: Vector2 = Vector2(sin(yaw), -cos(yaw))
		var pos: Vector2 = Vector2(float(cam["pos"][0]), float(cam["pos"][1]))
		var room: Rect2 = _room_ahead(data, pos + dir * 0.5)
		var fan: PackedVector2Array = PackedVector2Array([to_map.call(pos)])
		for i: int in range(17):
			var ray: Vector2 = dir.rotated(-half + 2.0 * half * float(i) / 16.0)
			fan.append(to_map.call(pos + ray * _ray_length(room, pos, ray, reach)))
		ICONS.at(on, Vector2.ZERO, 1.0)
		ICONS.camera_fan(on, fan)
		ICONS.camera(on, ICONS.at(on, to_map.call(pos), k))
	ICONS.at(on, Vector2.ZERO, 1.0)


static func _room_ahead(data: LevelData, point: Vector2) -> Rect2:
	for room: Dictionary in data.section("rooms"):
		if data.room_rect(room).has_point(point):
			return data.room_rect(room)
	return Rect2()


## Hasta dónde llega un rayo desde pos sin salirse de room (como mucho reach)
static func _ray_length(room: Rect2, pos: Vector2, ray: Vector2, reach: float) -> float:
	if room.size == Vector2.ZERO:
		return reach
	var length: float = reach
	if ray.x > 0.0001:
		length = minf(length, (room.end.x - pos.x) / ray.x)
	elif ray.x < -0.0001:
		length = minf(length, (room.position.x - pos.x) / ray.x)
	if ray.y > 0.0001:
		length = minf(length, (room.end.y - pos.y) / ray.y)
	elif ray.y < -0.0001:
		length = minf(length, (room.position.y - pos.y) / ray.y)
	return maxf(length, 0.0)
