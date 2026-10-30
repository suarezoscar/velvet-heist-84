## Reglas puras de validación del input que llega al servidor (FEAT-014).
## Recorta vectores, descarta valores no finitos y limita las acciones aceptadas.
## La usa NetSession en el servidor antes de aplicar el input a un actor.
class_name NetInputRules
extends RefCounted


## Devuelve el input saneado del actor: movement_vector con longitud máxima 1,
## look_target recortado a MAX_LOOK_DISTANCE en horizontal desde el actor y,
## ante NaN o infinito, el valor actual del actor.
static func sanitize(
	actor: PlayerBase3D, move: Vector2, sprint: bool, sneak: bool, look: Vector3
) -> Dictionary:
	var current_move: Vector2 = actor.current_input_dir if actor != null else Vector2.ZERO
	var current_look: Vector3 = actor.look_target_position if actor != null else Vector3.ZERO
	var safe_move: Vector2 = move if move.is_finite() else current_move
	var safe_look: Vector3 = look if look.is_finite() else current_look
	return {
		"movement_vector": safe_move.limit_length(1.0),
		"is_sprinting": sprint,
		"is_sneaking": sneak,
		"look_target": _clamp_look(actor, safe_look),
	}


## Sanea el cursor que acompaña a la intención fiable de interactuar (#113)
static func sanitize_interaction_cursor(actor: PlayerBase3D, cursor: Vector3) -> Vector3:
	if not cursor.is_finite():
		return Vector3.INF
	return _clamp_look(actor, cursor)


## Verdadero si la acción está en el catálogo cerrado de NetConfig.ACTIONS
static func is_valid_action(action: StringName) -> bool:
	return NetConfig.ACTIONS.has(action)


## Recorta el punto de mira en horizontal manteniendo su altura
static func _clamp_look(actor: PlayerBase3D, look: Vector3) -> Vector3:
	if actor == null:
		return look
	var origin: Vector3 = actor.global_position
	var offset: Vector3 = Vector3(look.x - origin.x, 0.0, look.z - origin.z)
	if offset.length() <= NetConfig.MAX_LOOK_DISTANCE:
		return look
	var clamped: Vector3 = offset.normalized() * NetConfig.MAX_LOOK_DISTANCE
	return Vector3(origin.x + clamped.x, look.y, origin.z + clamped.z)
