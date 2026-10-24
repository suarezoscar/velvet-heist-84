## @file dial_repeat.gd
## Convierte «tecla mantenida» en pasos del dial: un paso al pulsar y, tras repeat_delay, pasos
## seguidos que se aceleran (safe_dial.tres). Lo usan la caja fuerte sin red y el cliente.
class_name DialRepeat
extends RefCounted

const RULES: SafeDialRules = preload("res://data/balance/safe_dial.tres")

var _direction: int = 0
var _held: float = 0.0
var _next_step: float = 0.0


## Paso del dial en este tick: -1, 0 o 1, según qué tecla se mantiene
func update(left: bool, right: bool, delta: float) -> int:
	var direction: int = (1 if right else 0) - (1 if left else 0)
	if direction == 0:
		_direction = 0
		return 0
	if direction != _direction:
		_direction = direction
		_held = 0.0
		_next_step = RULES.repeat_delay
		return direction
	_held += delta
	if _held < _next_step:
		return 0
	var ramp: float = clampf((_held - RULES.repeat_delay) / RULES.acceleration_time, 0.0, 1.0)
	_next_step += lerpf(RULES.repeat_interval_start, RULES.repeat_interval_min, ramp)
	return direction


## Teclas del dial: flechas o A/D (el ladrón no se mueve mientras gira el dial)
static func left_held() -> bool:
	return _held_any([&"ui_left", &"move_left"])


static func right_held() -> bool:
	return _held_any([&"ui_right", &"move_right"])


static func _held_any(actions: Array[StringName]) -> bool:
	for action: StringName in actions:
		if InputMap.has_action(action) and Input.is_action_pressed(action):
			return true
	return false
