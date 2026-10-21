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
var holder_thief: Node3D = null

func _ready() -> void:
	collision_layer = 4 # Interactuable
	collision_mask = 2  # Ladrón
	monitoring = true

## Solo puede interactuarse si no ha sido asegurado todavía
func can_interact(_actor: Node3D) -> bool:
	return not is_collected

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

	var bus: Node = get_node_or_null("/root/SignalBus")
	if bus != null:
		bus.emit_signal("loot_stolen", loot_value, is_masterpiece)
		bus.emit_signal("noise_emitted_3d", thief.global_position, 2.5, &"thief")

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
	print("[LootItem3D] Objeto pesado '%s' depositado en el maletero del coche." % loot_name)

	var bus: Node = get_node_or_null("/root/SignalBus")
	if bus != null:
		bus.emit_signal("loot_stolen", loot_value, is_masterpiece)
		bus.emit_signal("noise_emitted_3d", car_position, 3.5, &"thief")

	if holder_thief != null and holder_thief is ThiefController3D:
		var thief: ThiefController3D = holder_thief as ThiefController3D
		thief.drop_heavy_loot()

	queue_free()
