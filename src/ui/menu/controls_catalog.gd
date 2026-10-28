## @file controls_catalog.gd
## Catálogo de controles del juego (FEAT-024) para el panel Controles: grupos de filas con su
## descripción y las teclas, leídas del InputMap para que siempre coincidan con el juego. Las
## filas sin acción (ratón, dial, menús) llevan el texto de las teclas fijo.
class_name ControlsCatalog
extends RefCounted

## Nombres de tecla en español, o con flechas, para los que Godot da en inglés
const KEY_NAMES: Dictionary = {
	"Left": "←",
	"Right": "→",
	"Up": "↑",
	"Down": "↓",
	"Shift": "Mayús",
	"Escape": "Esc",
	"Space": "Espacio",
	"Enter": "Intro",
}
const MOUSE_NAMES: Dictionary = {
	MOUSE_BUTTON_LEFT: "Clic izquierdo",
	MOUSE_BUTTON_RIGHT: "Clic derecho",
	MOUSE_BUTTON_MIDDLE: "Clic central",
}


## [{"title": String, "rows": [[descripción, teclas], ...]}, ...]
static func groups() -> Array[Dictionary]:
	return [
		{
			"title": "TODOS",
			"rows":
			[
				["Moverse", combo([&"move_up", &"move_left", &"move_down", &"move_right"])],
				["Mirar", "Ratón"],
				["Correr", keys(&"sprint")],
				["Sigilo", keys(&"sneak")],
				["Interactuar", keys(&"interact")],
				["Plano del museo", keys(&"toggle_blueprint")],
				["Panel de rendimiento y red", keys(&"toggle_perf_overlay")],
			],
		},
		{
			"title": "LADRÓN",
			"rows":
			[
				["Agacharse", keys(&"crouch")],
				["Caja fuerte: girar el dial", "← → / A D  (mantener: gira seguido)"],
				["Caja fuerte: probar número · salir", keys(&"interact") + " · Esc"],
			],
		},
		{
			"title": "GUARDIAS",
			"rows":
			[
				["Linterna", keys(&"toggle_flashlight")],
				["Porra", keys(&"strike")],
				["Mirar los monitores · levantarse", keys(&"interact") + " en la mesa CCTV"],
			],
		},
		{
			"title": "FIN DE LA PARTIDA",
			"rows": [["Revancha", keys(&"rematch")], ["Volver al menú", "Esc"]],
		},
	]


## Teclas de una acción separadas por « / » («M / Tab»); «—» si no tiene
static func keys(action: StringName) -> String:
	var names: Array[String] = key_list(action)
	return " / ".join(PackedStringArray(names)) if not names.is_empty() else "—"


## Varias acciones como un bloque por tecla («W A S D / ↑ ← ↓ →»)
static func combo(actions: Array[StringName]) -> String:
	var slots: Array[String] = []
	var slot: int = 0
	while true:
		var parts: Array[String] = []
		for action: StringName in actions:
			var names: Array[String] = key_list(action)
			if slot < names.size():
				parts.append(names[slot])
		if parts.is_empty():
			break
		slots.append(" ".join(PackedStringArray(parts)))
		slot += 1
	return " / ".join(PackedStringArray(slots))


static func key_list(action: StringName) -> Array[String]:
	var names: Array[String] = []
	if not InputMap.has_action(action):
		return names
	for event: InputEvent in InputMap.action_get_events(action):
		var text: String = event_name(event)
		if text != "" and not names.has(text):
			names.append(text)
	return names


static func event_name(event: InputEvent) -> String:
	var key: InputEventKey = event as InputEventKey
	if key != null:
		var code: Key = key.keycode if key.keycode != KEY_NONE else key.physical_keycode
		var text: String = OS.get_keycode_string(code)
		return KEY_NAMES.get(text, text)
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse != null:
		return MOUSE_NAMES.get(mouse.button_index, "Botón %d" % mouse.button_index)
	return ""
