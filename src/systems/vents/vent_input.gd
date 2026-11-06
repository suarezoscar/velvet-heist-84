## @file vent_input.gd
## Teclas y ratón del plano de los conductos (#167, heist.md R10) en la máquina del ladrón:
## ← → o A D cambian de salida, E confirma (llega por la interacción normal) y Esc, W, S, ↑ o
## ↓ cierran el plano. El ratón (VentPanel84) pide una salida con pick: se convierte en los
## pasos y la E que la eligen, para que lleguen al servidor por el mismo canal fiable y en
## orden que las teclas.
class_name VentInput
extends RefCounted

const CLOSE_ACTIONS: Array[StringName] = [
	&"ui_cancel", &"move_up", &"move_down", &"ui_up", &"ui_down"
]

static var _queued: Array[StringName] = []


## Acciones de este fotograma (vacío si no hay plano abierto); sin red las aplica VentTravel,
## con red las manda NetSessionClient
static func poll(tree: SceneTree) -> Array[StringName]:
	var actions: Array[StringName] = []
	if not VentTravel.is_choosing(tree):
		_queued.clear()
		return actions
	actions.append_array(_queued)
	_queued.clear()
	if _pressed([&"ui_left", &"move_left"]):
		actions.append(VentTravel.PREV)
	if _pressed([&"ui_right", &"move_right"]):
		actions.append(VentTravel.NEXT)
	if _pressed(CLOSE_ACTIONS):
		actions.append(&"dial_cancel")
	return actions


## El ratón elige la salida index (con la elegida ahora en current y count salidas) y confirma
static func pick(index: int, current: int, count: int) -> void:
	if count <= 0:
		return
	for i: int in range(wrapi(index - current, 0, count)):
		_queued.append(VentTravel.NEXT)
	_queued.append(&"interact")


static func _pressed(names: Array[StringName]) -> bool:
	for action: StringName in names:
		if InputMap.has_action(action) and Input.is_action_just_pressed(action):
			return true
	return false
