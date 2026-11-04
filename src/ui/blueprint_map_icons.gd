## @file blueprint_map_icons.gd
## Iconos del plano (#117) y su leyenda: el mismo dibujo en el plano y en el recuadro, para que
## cada icono se lea igual en los dos sitios. Dibuja sobre el Control que se le pasa.
class_name BlueprintMapIcons
extends RefCounted

const COLOR_BG: Color = Color(0.04, 0.10, 0.18, 0.99)
const COLOR_TEXT: Color = Color(0.70, 0.88, 1.0, 0.95)
const COLOR_HEADER: Color = Color(1.0, 0.82, 0.40, 1.0)
const COLOR_ALARM: Color = Color("ff4a3d")
const COLOR_OK: Color = Color("4be38a")
const COLOR_VENT: Color = Color(0.6, 0.62, 0.68, 0.9)
const COLOR_POST: Color = Color(1.0, 0.72, 0.25)
const COLOR_YOU: Color = Color(1.0, 1.0, 1.0, 0.95)
const LEGEND_WIDTH: float = 230.0
const LEGEND_ROW: float = 26.0
## Icono de cada protección en las fichas de los guardias
const PROTECTION_ICONS: Dictionary = {&"combination": "◎", &"pressure": "▣", &"sensor": "ϟ"}

## Filas de la leyenda por bando: [icono, texto]
const THIEF_LEGEND: Array = [
	["you", "TÚ"],
	["contract", "TU ENCARGO (✔ ROBADA)"],
	["vent", "REJILLA (S / O / E)"],
	["camera", "CÁMARA"],
	["exit", "SALIDA"],
	["post", "GARITA (CAFÉ)"],
	["alarm", "ALARMA (HACE…)"],
]
const GUARD_LEGEND: Array = [
	["you", "TÚ"],
	["mate", "COMPAÑERO"],
	["combination", "COMBINACIÓN"],
	["pressure", "PRESIÓN"],
	["sensor", "SENSOR"],
	["trace", "RASTRO (FALTA)"],
	["camera", "CÁMARA"],
	["exit", "SALIDA"],
	["post", "GARITA (CAFÉ)"],
	["ping", "WALKIE"],
	["alarm", "ALARMA (HACE…)"],
]


static func text(on: CanvasItem, pos: Vector2, label: String, size: int, color: Color) -> void:
	on.draw_string(MenuTheme84.FONT_STRONG, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## Texto centrado en pos (horizontal) con la línea base en pos.y
static func text_centered(
	on: CanvasItem, pos: Vector2, label: String, size: int, color: Color
) -> void:
	var width: float = MenuTheme84.FONT_STRONG.get_string_size(label, 0, -1, size).x
	text(on, pos - Vector2(width * 0.5, 0.0), label, size, color)


## Tu punto: círculo de tu bando con aro blanco, flecha hacia donde miras y «TÚ»
static func you(on: CanvasItem, pos: Vector2, facing: Vector2, color: Color) -> void:
	if facing.length_squared() > 0.0001:
		var dir: Vector2 = facing.normalized()
		var side: Vector2 = dir.orthogonal() * 6.0
		var tip: Vector2 = pos + dir * 20.0
		on.draw_colored_polygon(
			PackedVector2Array([tip, pos + dir * 9.0 + side, pos + dir * 9.0 - side]), COLOR_YOU
		)
	on.draw_circle(pos, 7.0, color)
	on.draw_arc(pos, 7.0, 0.0, TAU, 24, COLOR_YOU, 2.0)
	# abajo a la derecha: la flecha no lo tapa
	text(on, pos + Vector2(11.0, 16.0), "TÚ", 16, COLOR_YOU)


## Compañero: punto cian con su número («G2»)
static func mate(on: CanvasItem, pos: Vector2, label: String) -> void:
	on.draw_circle(pos, 5.5, TeamMarker3D.GUARD_COLOR)
	text(on, pos + Vector2(8.0, 5.0), label, 13, TeamMarker3D.GUARD_COLOR)


## Campana roja donde saltó una alarma; ago en segundos («hace 1:20»), < 0 para no ponerlo
static func alarm(on: CanvasItem, pos: Vector2, ago: float) -> void:
	var c: Vector2 = pos
	var bell: PackedVector2Array = PackedVector2Array(
		[
			c + Vector2(-3.0, -8.0),
			c + Vector2(3.0, -8.0),
			c + Vector2(5.0, -2.0),
			c + Vector2(8.0, 3.0),
			c + Vector2(-8.0, 3.0),
			c + Vector2(-5.0, -2.0)
		]
	)
	on.draw_colored_polygon(bell, COLOR_ALARM)
	on.draw_circle(c + Vector2(0.0, 5.5), 2.2, COLOR_ALARM)
	on.draw_circle(c + Vector2(0.0, -9.0), 1.6, COLOR_ALARM)
	if ago >= 0.0:
		text(on, c + Vector2(11.0, 4.0), "hace %s" % clock(ago), 14, COLOR_ALARM)


## Taza de café: lo que hay en la garita
static func cup(on: CanvasItem, pos: Vector2, color: Color) -> void:
	on.draw_rect(Rect2(pos + Vector2(-6.0, -5.0), Vector2(11.0, 10.0)), color, true)
	on.draw_arc(pos + Vector2(6.0, 0.0), 3.5, -PI * 0.5, PI * 0.5, 8, color, 2.0)
	on.draw_line(pos + Vector2(-8.0, 7.0), pos + Vector2(8.0, 7.0), color, 2.0)
	for x: float in [-3.0, 1.0]:
		on.draw_line(pos + Vector2(x, -8.0), pos + Vector2(x + 1.5, -12.0), color, 1.5)


static func camera(on: CanvasItem, pos: Vector2) -> void:
	on.draw_circle(pos, 4.5, COLOR_ALARM)


static func vent(on: CanvasItem, pos: Vector2, network: String) -> void:
	on.draw_rect(Rect2(pos - Vector2(5.0, 5.0), Vector2(10.0, 10.0)), COLOR_VENT, false, 1.5)
	if network != "":
		text(on, pos + Vector2(8.0, 5.0), network, 11, COLOR_VENT)


static func ping(on: CanvasItem, pos: Vector2) -> void:
	on.draw_arc(pos, 10.0, 0.0, TAU, 24, COLOR_ALARM, 2.0)


## m:ss
static func clock(seconds: float) -> String:
	var total: int = maxi(0, int(seconds))
	return "%d:%02d" % [total / 60, total % 60]


## Recuadro de la leyenda en la esquina superior derecha de panel (abajo va el panel de depuración)
static func legend(on: CanvasItem, panel: Rect2, thief_view: bool) -> void:
	var rows: Array = THIEF_LEGEND if thief_view else GUARD_LEGEND
	var size: Vector2 = Vector2(LEGEND_WIDTH, 40.0 + rows.size() * LEGEND_ROW)
	var box: Rect2 = Rect2(Vector2(panel.end.x - size.x - 20.0, panel.position.y + 64.0), size)
	on.draw_rect(box, Color(COLOR_BG, 0.92), true)
	on.draw_rect(box, COLOR_TEXT, false, 1.5)
	text(on, box.position + Vector2(14.0, 26.0), "LEYENDA", 16, COLOR_HEADER)
	var y: float = box.position.y + 40.0 + LEGEND_ROW * 0.5
	for row: Array in rows:
		var icon_at: Vector2 = Vector2(box.position.x + 26.0, y)
		_legend_icon(on, String(row[0]), icon_at, thief_view)
		text(on, Vector2(box.position.x + 50.0, y + 5.0), String(row[1]), 14, COLOR_TEXT)
		y += LEGEND_ROW


static func _legend_icon(on: CanvasItem, kind: String, at: Vector2, thief_view: bool) -> void:
	var own: Color = TeamMarker3D.THIEF_COLOR if thief_view else TeamMarker3D.GUARD_COLOR
	match kind:
		"you":
			on.draw_circle(at, 6.0, own)
			on.draw_arc(at, 6.0, 0.0, TAU, 20, COLOR_YOU, 2.0)
		"mate":
			on.draw_circle(at, 5.5, TeamMarker3D.GUARD_COLOR)
		"contract":
			text(on, at + Vector2(-6.0, 6.0), "◆", 16, TeamMarker3D.THIEF_COLOR)
		"combination", "pressure", "sensor":
			text(on, at + Vector2(-6.0, 6.0), PROTECTION_ICONS[StringName(kind)], 15, own)
		"trace":
			text(on, at + Vector2(-6.0, 6.0), "✘", 15, COLOR_ALARM)
		"vent":
			vent(on, at, "")
		"camera":
			camera(on, at)
		"exit":
			on.draw_line(at - Vector2(9.0, 0.0), at + Vector2(9.0, 0.0), COLOR_OK, 4.0)
		"post":
			on.draw_rect(
				Rect2(at - Vector2(9.0, 7.0), Vector2(18.0, 14.0)), Color(COLOR_POST, 0.35)
			)
			on.draw_rect(Rect2(at - Vector2(9.0, 7.0), Vector2(18.0, 14.0)), COLOR_POST, false, 1.5)
		"ping":
			ping(on, at)
		"alarm":
			alarm(on, at, -1.0)
