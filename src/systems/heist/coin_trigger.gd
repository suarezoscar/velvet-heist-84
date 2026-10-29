## @file coin_trigger.gd
## Cuándo se lanza la moneda del jugador local (FEAT-038): mantener el botón apunta (CoinAim3D
## dibuja la mira mientras aiming), soltarlo la lanza y el clic izquierdo cancela sin gastarla.
## Un clic rápido la lanza al punto del ratón. Lo consultan HeistInput (sin red) y
## NetSessionClient (con red), una vez por fotograma.
class_name CoinTrigger
extends RefCounted

const ACTION: StringName = &"throw_coin"
const CANCEL: StringName = &"strike"

## Apuntando: botón pulsado y sin cancelar
static var aiming: bool = false
static var _cancelled: bool = false


## Lee el ratón y devuelve true en el fotograma en que hay que lanzar
static func poll() -> bool:
	if LocalInput3D.blocked or not InputMap.has_action(ACTION):
		reset()
		return false
	if aiming and not Input.is_action_pressed(ACTION) and not Input.is_action_just_released(ACTION):
		reset()  # se soltó con la pausa abierta: no se lanza
		return false
	return step(
		Input.is_action_just_pressed(ACTION),
		Input.is_action_just_released(ACTION),
		InputMap.has_action(CANCEL) and Input.is_action_just_pressed(CANCEL)
	)


## Un paso de la regla: pulsar empieza a apuntar, cancelar lo anula y soltar lanza si no se
## canceló
static func step(pressed: bool, released: bool, cancel: bool) -> bool:
	if pressed:
		aiming = true
		_cancelled = false
	if aiming and cancel:
		aiming = false
		_cancelled = true
	if not released:
		return false
	var fire: bool = aiming and not _cancelled
	reset()
	return fire


static func reset() -> void:
	aiming = false
	_cancelled = false
