## @file coffee_machine_3d.gd
## La cafetera de la garita (heist.md R5): un guardia humano con E se sirve un café que le
## quita el sueño. Suena (MECHANISM, radio RULES.coffee_radius): el ladrón sabe que alguien ha
## dejado su puesto. El modelo es el carrito de café de Poly Haven (coffee_cart.glb).
class_name CoffeeMachine3D
extends Area3D

const RULES: GuardSleepRules = preload("res://data/balance/guard_sleep.tres")


func _ready() -> void:
	add_to_group(&"coffee_machine")


func can_interact(actor: Node3D = null) -> bool:
	var sleep: GuardSleep = _sleep_of(actor)
	return sleep != null and sleep.drinking_left <= 0.0


func get_interaction_text(actor: Node3D = null) -> String:
	var sleep: GuardSleep = _sleep_of(actor)
	if sleep != null and sleep.drinking_left > 0.0:
		return "Sirviendo café…"
	return "Tomar un café [E]"


func interact(actor: Node3D) -> void:
	var sleep: GuardSleep = _sleep_of(actor)
	if sleep != null and sleep.start_coffee():
		NoiseEmit.emit(global_position, RULES.coffee_radius, &"guard", NoiseEmit.MECHANISM, actor)


static func _sleep_of(actor: Node3D) -> GuardSleep:
	if not (actor is GuardController3D):
		return null
	return actor.get_node_or_null("Sleep") as GuardSleep
