## @file blueprint_map_props.gd
## Objetos interactivos del plano (#117): cafetera, monitores, cuadros eléctricos,
## interruptores, lámparas, mesa de copias, coche de huida y objetos sueltos.
## Las puertas, las piezas (con su caja fuerte), las cámaras y las rejillas las dibuja
## BlueprintMapOverlay.
## Se buscan una vez al abrir el plano (collect) y cada icono sale con su estado actual.
class_name BlueprintMapProps
extends RefCounted

const ICONS := preload("res://src/ui/blueprint_map_icons.gd")


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
			ICONS.badge(on, pos, ICONS.COLOR_DESK, "TV")
		&"power":
			ICONS.power(on, pos, prop != null and (prop as PowerBox3D).is_cut)
		&"switch":
			ICONS.light_switch(on, pos)
		&"lamp":
			ICONS.lamp(on, pos, prop == null or (prop as Lamp3D).is_lit())
		&"copy":
			ICONS.badge(on, pos, ICONS.COLOR_COPY, "C")
		&"car":
			ICONS.car(on, pos)
		&"loot":
			ICONS.badge(on, pos, ICONS.COLOR_LOOT, "$")
