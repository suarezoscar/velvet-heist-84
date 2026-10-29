## @file fall_guard.gd
## Red de seguridad bajo el nivel: si un personaje (ladrón o guardia) cae más de FALL_LIMIT
## metros por debajo del suelo por un hueco del mapa, vuelve al último punto en el que estaba
## apoyado y se queda quieto. Así una partida nunca se queda atascada con alguien cayendo sin
## fin. Lo decide quien tiene la autoridad (el servidor o la partida sin red); los clientes
## reciben la posición como siempre.
class_name FallGuard
extends Node

## Metros por debajo del suelo (y = 0) a partir de los que se considera caído
const FALL_LIMIT: float = 5.0
const SAFE_META: StringName = &"fall_guard_safe"


func _ready() -> void:
	name = "FallGuard"


func _physics_process(_delta: float) -> void:
	if NetManager.is_online() and not multiplayer.is_server():
		return
	for group: StringName in [&"thief", &"guards"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			var actor: CharacterBody3D = node as CharacterBody3D
			if actor != null:
				check(actor)


## Recuerda dónde pisa actor y lo devuelve ahí si ha caído
static func check(actor: CharacterBody3D) -> void:
	if actor.is_on_floor() or not actor.has_meta(SAFE_META):
		actor.set_meta(SAFE_META, actor.global_position)  # al principio, donde aparece
	elif actor.global_position.y < -FALL_LIMIT:
		var safe: Vector3 = actor.get_meta(SAFE_META)
		actor.global_position = safe
		actor.velocity = Vector3.ZERO
		push_warning("[FallGuard] %s ha caído fuera del nivel: vuelve a %s" % [actor.name, safe])
