## @file hud_header_84.gd
## Objetivo en la barra superior del HUD. Con encargo (heist.md): «ENCARGO 1 / 3» y, completo,
## «¡A LA SALIDA!». Sin encargo (mapas antiguos): botín frente a la cuota y la Pieza Maestra.
class_name HudHeader84
extends RefCounted

const DONE_COLOR: Color = Color(0.3, 1.0, 0.4)
const PENDING_COLOR: Color = Color(1.0, 0.85, 0.3)
const DIM_COLOR: Color = Color(0.6, 0.6, 0.6)


static func update_goal(goal_label: Label, detail_label: Label) -> void:
	var heist: HeistDirector = GameManager.heist
	if heist != null and not HeistDirector.local_is_thief(Engine.get_main_loop() as SceneTree):
		_paint(goal_label, "LA CARTA: SE LLEVARÁ %d PIEZAS" % heist.contract_size, PENDING_COLOR)
		_paint(detail_label, "SALIDAS: TODAS LAS PUERTAS EXTERIORES", DIM_COLOR)
		return
	if heist != null:
		_paint(
			goal_label,
			"ENCARGO: %d / %d" % [heist.stolen.size(), heist.contract_size],
			DONE_COLOR if heist.is_complete() else PENDING_COLOR
		)
		_paint(
			detail_label,
			"¡A LA SALIDA!" if heist.is_complete() else "SALIDA: CUALQUIER PUERTA EXTERIOR",
			DONE_COLOR if heist.is_complete() else DIM_COLOR
		)
		return
	var cur: int = GameManager.current_loot_value
	var target: int = GameManager.quota_target
	_paint(
		goal_label,
		"BOTIN: $%d / $%d" % [cur, target],
		DONE_COLOR if cur >= target else PENDING_COLOR
	)
	if GameManager.has_masterpiece:
		_paint(detail_label, "[★] PIEZA MAESTRA: ASEGURADA", Color(1.0, 0.84, 0.0))
	else:
		_paint(detail_label, "[ ] PIEZA MAESTRA: PENDIENTE", DIM_COLOR)


static func _paint(label: Label, text: String, color: Color) -> void:
	if label != null:
		label.text = text
		label.modulate = color
