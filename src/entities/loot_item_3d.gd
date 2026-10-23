## @file loot_item_3d.gd
## Representa un objeto de valor (botín ligero o pesado) susceptible de ser robado.
## El botín ligero va directo al maletín del ladrón; el pesado se transporta en brazos
## imponiendo una reducción del 20% en la velocidad de movimiento.
class_name LootItem3D
extends Area3D

## Nombre descriptivo del objeto de valor
@export var loot_name: String = "Fajo de Billetes"

## Valor económico aportado a la cuota del golpe (en $)
@export var loot_value: int = 2500

## Si es verdadero, impone penalización física de movimiento y ocupa las manos
@export var is_heavy: bool = false

## Si es verdadero, corresponde a la Pieza Maestra requerida para ganar
@export var is_masterpiece: bool = false

@export var prompt_message: String = "Recoger Botín"

var is_collected: bool = false
var is_deposited: bool = false
var holder_thief: Node3D = null
var _holder_cached_path: String = ""


func _ready() -> void:
	add_to_group(&"net_state")
	collision_layer = 4  # Interactuable
	collision_mask = 2  # Ladrón
	monitoring = true


## Solo puede interactuarse si no ha sido asegurado todavía y el actor es un ladrón válido
func can_interact(actor: Node3D = null) -> bool:
	if is_collected:
		return false
	if actor != null:
		if not (actor is ThiefController3D):
			return false
		if is_heavy:
			var thief: ThiefController3D = actor as ThiefController3D
			if thief.carried_loot != null:
				return false
	return true


## Devuelve el texto descriptivo para el tooltip del HUD
func get_interaction_text(_actor: Node3D = null) -> String:
	var type_desc: String = "Pesado" if is_heavy else "Ligero"
	return "%s (%s - $%d) [E]" % [loot_name, type_desc, loot_value]


## Ejecuta la recolección o transporte del botín
func interact(actor: Node3D) -> void:
	if is_collected or not (actor is ThiefController3D):
		return

	var thief: ThiefController3D = actor as ThiefController3D
	if is_heavy:
		if thief.carried_loot != null:
			print("[LootItem3D] El ladrón ya está transportando otro objeto pesado.")
			return
		_attach_to_thief_hands(thief)
	else:
		_collect_light_loot(thief)


func _collect_light_loot(thief: ThiefController3D) -> void:
	is_collected = true
	print("[LootItem3D] Botín ligero '%s' guardado en el maletín (+$%d)" % [loot_name, loot_value])
	SignalBus.loot_stolen.emit(loot_value, is_masterpiece)
	NoiseEmit.emit(thief.global_position, 2.5, &"thief", NoiseEmit.IMPACT, thief)
	queue_free()


func _attach_to_thief_hands(thief: ThiefController3D) -> void:
	is_collected = true
	holder_thief = thief
	thief.carry_heavy_loot(self)

	# Desactivar colisiones espaciales mientras se carga en brazos
	monitoring = false
	monitorable = false

	# Reparentar al ancla de las manos del ladrón
	reparent(thief.carry_anchor)
	position = Vector3.ZERO
	rotation = Vector3.ZERO
	print("[LootItem3D] Botín pesado '%s' cargado en brazos. Velocidad reducida -20%%" % loot_name)


## Deposita el botín pesado en el maletero del coche de fuga
func deposit_into_trunk(car_position: Vector3) -> void:
	is_deposited = true
	is_collected = true
	print("[LootItem3D] Objeto pesado '%s' depositado en el maletero del coche." % loot_name)
	SignalBus.loot_stolen.emit(loot_value, is_masterpiece)
	NoiseEmit.emit(car_position, 3.5, &"thief", NoiseEmit.IMPACT, holder_thief)

	if holder_thief != null and holder_thief is ThiefController3D:
		var thief: ThiefController3D = holder_thief as ThiefController3D
		thief.drop_heavy_loot()

	queue_free()


## Devuelve el snapshot de estado del botín para red
func get_net_state() -> Dictionary:
	var holder_path: String = ""
	if holder_thief != null:
		if get_tree() != null and get_tree().current_scene != null:
			holder_path = String(get_tree().current_scene.get_path_to(holder_thief))
		elif not _holder_cached_path.is_empty():
			holder_path = _holder_cached_path
		else:
			holder_path = String(holder_thief.get_path())
	else:
		holder_path = _holder_cached_path

	return {
		"collected": is_collected,
		"holder": holder_path,
		"deposited": is_deposited,
	}


## Aplica el snapshot de estado recibido por red
func apply_net_state(state: Dictionary) -> void:
	is_collected = bool(state.get("collected", false))
	is_deposited = bool(state.get("deposited", false))
	var holder_path: String = String(state.get("holder", ""))
	_holder_cached_path = holder_path

	if (is_collected and holder_path.is_empty()) or is_deposited:
		visible = false
		monitoring = false
		monitorable = false
		if holder_thief != null and holder_thief is ThiefController3D:
			(holder_thief as ThiefController3D).drop_heavy_loot()
			holder_thief = null
	elif not holder_path.is_empty():
		visible = true
		var target_node: Node = null
		if get_tree() != null and get_tree().current_scene != null:
			target_node = get_tree().current_scene.get_node_or_null(NodePath(holder_path))
		if target_node is ThiefController3D:
			var thief: ThiefController3D = target_node as ThiefController3D
			holder_thief = thief
			thief.carry_heavy_loot(self)
			monitoring = false
			monitorable = false
			if thief.carry_anchor != null and get_parent() != thief.carry_anchor:
				reparent(thief.carry_anchor)
				position = Vector3.ZERO
				rotation = Vector3.ZERO
	else:
		visible = true
		monitoring = true
		monitorable = true
