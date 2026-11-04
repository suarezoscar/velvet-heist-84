## @file blueprint_map_legend.gd
## Leyenda del plano (#117): un recuadro arriba a la derecha, distinto por bando, con los mismos
## iconos que el plano (BlueprintMapIcons y BlueprintMapProps).
class_name BlueprintMapLegend
extends RefCounted

const ICONS := preload("res://src/ui/blueprint_map_icons.gd")
const PROPS := preload("res://src/ui/blueprint_map_props.gd")
const WIDTH: float = 250.0
const ROW: float = 29.0

## Filas por bando: [icono, texto]
const THIEF_ROWS: Array = [
	[&"you", "TÚ"],
	[&"contract", "TU ENCARGO (✔ ROBADA)"],
	[&"vent", "REJILLA (S / O / E)"],
	[&"camera", "CÁMARA"],
	[&"exit", "SALIDA"],
	[&"car", "COCHE DE HUIDA"],
	[&"copy", "MESA DE COPIAS"],
	[&"power", "CUADRO ELÉCTRICO"],
	[&"switch", "INTERRUPTOR"],
	[&"lamp", "LÁMPARA"],
	[&"post", "GARITA"],
	[&"coffee", "CAFETERA"],
	[&"desk", "MONITORES"],
	[&"alarm", "ALARMA (HACE…)"],
]
const GUARD_ROWS: Array = [
	[&"you", "TÚ"],
	[&"mate", "COMPAÑERO"],
	[&"combination", "COMBINACIÓN"],
	[&"pressure", "PRESIÓN"],
	[&"sensor", "SENSOR"],
	[&"trace", "RASTRO (FALTA)"],
	[&"camera", "CÁMARA"],
	[&"exit", "SALIDA"],
	[&"power", "CUADRO ELÉCTRICO"],
	[&"switch", "INTERRUPTOR"],
	[&"lamp", "LÁMPARA"],
	[&"post", "GARITA"],
	[&"coffee", "CAFETERA"],
	[&"desk", "MONITORES"],
	[&"ping", "WALKIE"],
	[&"alarm", "ALARMA (HACE…)"],
]


## Recuadro de la leyenda arriba a la derecha de panel (abajo va el panel de depuración)
static func draw(on: CanvasItem, panel: Rect2, top: float, thief_view: bool) -> void:
	var rows: Array = THIEF_ROWS if thief_view else GUARD_ROWS
	var size: Vector2 = Vector2(WIDTH, 44.0 + rows.size() * ROW)
	var box: Rect2 = Rect2(Vector2(panel.end.x - size.x - 20.0, top), size)
	on.draw_rect(box.grow(3.0), ICONS.COLOR_OUTLINE, true)
	on.draw_rect(box, Color(ICONS.COLOR_BG, 1.0), true)
	on.draw_rect(box, ICONS.COLOR_TEXT, false, 2.0)
	ICONS.text(on, box.position + Vector2(14.0, 30.0), "LEYENDA", 22, ICONS.COLOR_HEADER)
	var y: float = box.position.y + 44.0 + ROW * 0.5
	for row: Array in rows:
		_icon(on, row[0], Vector2(box.position.x + 28.0, y), thief_view)
		ICONS.text(
			on, Vector2(box.position.x + 54.0, y + 7.0), String(row[1]), 18, ICONS.COLOR_TEXT
		)
		y += ROW


static func _icon(on: CanvasItem, kind: StringName, at: Vector2, thief_view: bool) -> void:
	var own: Color = TeamMarker3D.THIEF_COLOR if thief_view else TeamMarker3D.GUARD_COLOR
	match kind:
		&"you":
			ICONS.badge(on, at, own)
			on.draw_circle(at, 4.0, ICONS.COLOR_YOU)
		&"mate":
			ICONS.badge(on, at, TeamMarker3D.GUARD_COLOR)
		&"contract":
			ICONS.glyph(on, at, "◆", 20, TeamMarker3D.THIEF_COLOR)
		&"combination", &"pressure", &"sensor":
			ICONS.glyph(on, at, ICONS.PROTECTION_ICONS[kind], 20, own)
		&"trace":
			ICONS.glyph(on, at, "✘", 20, ICONS.COLOR_ALARM)
		&"vent":
			ICONS.vent(on, at, "")
		&"camera":
			ICONS.camera(on, at)
		&"exit":
			on.draw_line(at - Vector2(11.0, 0.0), at + Vector2(11.0, 0.0), ICONS.COLOR_OUTLINE, 9.0)
			on.draw_line(at - Vector2(10.0, 0.0), at + Vector2(10.0, 0.0), ICONS.COLOR_OK, 5.0)
		&"post":
			var square: Rect2 = Rect2(at - Vector2(11.0, 8.0), Vector2(22.0, 16.0))
			on.draw_rect(square, Color(ICONS.COLOR_POST, 0.35))
			on.draw_rect(square, ICONS.COLOR_POST, false, 2.0)
		&"ping":
			ICONS.ping(on, at)
		&"alarm":
			ICONS.alarm(on, at, -1.0)
		_:
			PROPS.icon(on, kind, at)
