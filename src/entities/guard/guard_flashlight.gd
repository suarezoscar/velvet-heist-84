## @file guard_flashlight.gd
## Linterna del guardia (#112): solo se enciende mientras se mantiene el clic derecho (acción
## flashlight) y entonces apunta al ratón («barrer»). Aquí está el lado del jugador local (qué
## pedir al pulsar y soltar) y el haz que sigue a look_target_position; las acciones
## flashlight_on y flashlight_off las ejecuta GuardController3D con autoridad.
class_name GuardFlashlight
extends RefCounted

const ACTION: StringName = &"flashlight"
const TURN_ON: StringName = &"flashlight_on"
const TURN_OFF: StringName = &"flashlight_off"

## El jugador local mantiene el botón (para apuntar al ratón sin esperar al servidor)
static var held: bool = false


## Acción a pedir este fotograma: TURN_ON al pulsar, TURN_OFF al soltar (o con la pausa
## abierta), &"" si nada cambia
static func poll() -> StringName:
	var pressed: bool = (
		not LocalInput3D.blocked and InputMap.has_action(ACTION) and Input.is_action_pressed(ACTION)
	)
	return step(pressed)


## Un paso de la regla: devuelve la acción al cambiar de estado
static func step(pressed: bool) -> StringName:
	if pressed == held:
		return &""
	held = pressed
	return TURN_ON if pressed else TURN_OFF


## Orienta el haz hacia el punto mirado
static func orient(light: SpotLight3D, target: Vector3) -> void:
	if light == null:
		return
	var dir: Vector3 = (target - light.global_position).normalized()
	if dir.length_squared() <= 0.01:
		return
	var up_vector: Vector3 = Vector3.FORWARD if absf(dir.dot(Vector3.UP)) > 0.98 else Vector3.UP
	light.look_at(target, up_vector)
