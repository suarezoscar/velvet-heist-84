## @file blueprint_map_icons.gd
## Iconos del plano (#117), estilo cartoon: chapas redondas con borde oscuro grueso y aro claro,
## y textos grandes con contorno. El mismo dibujo sirve en el plano y en la leyenda
## (BlueprintMapLegend), para que cada icono se lea igual en los dos sitios.
class_name BlueprintMapIcons
extends RefCounted

const COLOR_BG: Color = Color(0.04, 0.10, 0.18, 0.99)
const COLOR_TEXT: Color = Color(0.78, 0.92, 1.0, 1.0)
const COLOR_HEADER: Color = Color(1.0, 0.82, 0.40, 1.0)
const COLOR_ALARM: Color = Color("ff4a3d")
const COLOR_OK: Color = Color("4be38a")
const COLOR_VENT: Color = Color(0.72, 0.74, 0.80)
const COLOR_POST: Color = Color(1.0, 0.72, 0.25)
const COLOR_YOU: Color = Color(1.0, 1.0, 1.0)
const COLOR_YOU_WARM: Color = Color(1.0, 0.95, 0.78)
const COLOR_OUTLINE: Color = Color(0.02, 0.03, 0.07)
const COLOR_OFF: Color = Color(0.36, 0.40, 0.46)
const COLOR_POWER: Color = Color("ffd23d")
const COLOR_DESK: Color = Color("5aa8ff")
const COLOR_COPY: Color = Color("b98cff")
const COLOR_LOOT: Color = Color("ffc93d")
const BADGE: float = 11.0
const FONT: FontFile = MenuTheme84.FONT_DISPLAY
## Icono de cada protección en las fichas de los guardias
const PROTECTION_ICONS: Dictionary = {&"combination": "◎", &"pressure": "▣", &"sensor": "ϟ"}


## Texto con contorno oscuro (se lee encima de cualquier cosa)
static func text(on: CanvasItem, pos: Vector2, label: String, size: int, color: Color) -> void:
	var outline: int = maxi(4, size / 4)
	on.draw_string_outline(
		FONT, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, COLOR_OUTLINE
	)
	on.draw_string(FONT, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## Texto centrado en pos.x con la línea base en pos.y
static func text_centered(
	on: CanvasItem, pos: Vector2, label: String, size: int, color: Color
) -> void:
	var width: float = FONT.get_string_size(label, 0, -1, size).x
	text(on, pos - Vector2(width * 0.5, 0.0), label, size, color)


## Glifo (◆, ◎, ✘…) con la fuente que los tiene, centrado en pos y con contorno
static func glyph(on: CanvasItem, pos: Vector2, label: String, size: int, color: Color) -> void:
	var font: FontFile = MenuTheme84.FONT_STRONG
	var at: Vector2 = pos + Vector2(-font.get_string_size(label, 0, -1, size).x * 0.5, size * 0.36)
	on.draw_string_outline(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, COLOR_OUTLINE)
	on.draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## Chapa redonda: borde oscuro, relleno y aro claro; letra opcional en el centro
static func badge(on: CanvasItem, pos: Vector2, fill: Color, letter: String = "") -> void:
	on.draw_circle(pos, BADGE + 3.0, COLOR_OUTLINE)
	on.draw_circle(pos, BADGE, fill)
	on.draw_arc(pos, BADGE - 1.0, 0.0, TAU, 28, Color(1.0, 1.0, 1.0, 0.85), 2.0)
	if letter != "":
		var width: float = FONT.get_string_size(letter, 0, -1, 17).x
		var at: Vector2 = pos + Vector2(-width * 0.5, 6.0)
		on.draw_string(FONT, at, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, COLOR_OUTLINE)


## Tu punto: puntero (gota) blanco cálido que gira hacia donde miras, con halo que late
## (pulse 0..1) y «TÚ». Los compañeros son círculos cian: no se confunden
static func you(
	on: CanvasItem, pos: Vector2, facing: Vector2, pulse: float, label: bool = true
) -> void:
	glow(on, pos, COLOR_YOU_WARM, 22.0 + pulse * 10.0, 0.35 * (1.0 - pulse))
	var dir: Vector2 = facing.normalized() if facing.length_squared() > 0.0001 else Vector2.UP
	var side: Vector2 = dir.orthogonal()
	var drop: PackedVector2Array = PackedVector2Array()
	drop.append(pos + dir * 22.0)
	for i: int in range(13):  # media vuelta de atrás: la gota
		var angle: float = PI * 0.5 + PI * float(i) / 12.0
		drop.append(pos + (dir * cos(angle) + side * sin(angle)) * 9.0)
	on.draw_colored_polygon(drop, COLOR_YOU_WARM)
	drop.append(drop[0])
	on.draw_polyline(drop, COLOR_OUTLINE, 3.0)
	on.draw_circle(pos, 3.0, COLOR_OUTLINE)
	if label:
		text(on, pos + Vector2(14.0, 26.0), "TÚ", 22, COLOR_YOU_WARM)


## Compañero: chapa cian con su número («G2») al lado
static func mate(on: CanvasItem, pos: Vector2, label: String) -> void:
	badge(on, pos, TeamMarker3D.GUARD_COLOR)
	text(on, pos + Vector2(15.0, 7.0), label, 19, TeamMarker3D.GUARD_COLOR)


## Campana roja donde saltó una alarma, con pulso; ago en segundos va en una píldora oscura
## con borde rojo («hace 1:20»), < 0 para no ponerlo
static func alarm(on: CanvasItem, pos: Vector2, ago: float, pulse: float = 0.0) -> void:
	if pulse > 0.0:
		on.draw_arc(
			pos, 8.0 + pulse * 18.0, 0.0, TAU, 28, Color(COLOR_ALARM, 0.7 * (1.0 - pulse)), 2.5
		)
	var bell: PackedVector2Array = PackedVector2Array(
		[
			pos + Vector2(-4.0, -11.0),
			pos + Vector2(4.0, -11.0),
			pos + Vector2(7.0, -3.0),
			pos + Vector2(11.0, 4.0),
			pos + Vector2(-11.0, 4.0),
			pos + Vector2(-7.0, -3.0),
			pos + Vector2(-4.0, -11.0)
		]
	)
	on.draw_circle(pos + Vector2(0.0, 7.5), 4.5, COLOR_OUTLINE)
	on.draw_polyline(bell, COLOR_OUTLINE, 6.0)
	on.draw_colored_polygon(bell.slice(0, 6), COLOR_ALARM)
	on.draw_circle(pos + Vector2(0.0, 7.5), 3.0, COLOR_ALARM)
	if ago < 0.0:
		return
	var label: String = "HACE %s" % clock(ago)
	var width: float = FONT.get_string_size(label, 0, -1, 17).x
	var pill: Rect2 = Rect2(pos + Vector2(15.0, -11.0), Vector2(width + 16.0, 22.0))
	on.draw_rect(pill, Color(COLOR_OUTLINE, 0.85))
	on.draw_rect(pill, COLOR_ALARM, false, 1.5)
	on.draw_string(
		FONT,
		pill.position + Vector2(8.0, 17.0),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		17,
		COLOR_ALARM
	)


## Resplandor CRT: discos concéntricos que se desvanecen
static func glow(on: CanvasItem, pos: Vector2, color: Color, radius: float, alpha: float) -> void:
	for i: int in range(4):
		var k: float = 1.0 - float(i) / 4.0
		on.draw_circle(pos, radius * k, Color(color, alpha * 0.25))


## Taza de café (la cafetera de la garita)
static func cup(on: CanvasItem, pos: Vector2, color: Color) -> void:
	badge(on, pos, color)
	var c: Vector2 = pos + Vector2(-1.0, 1.0)
	on.draw_rect(Rect2(c + Vector2(-5.0, -4.0), Vector2(9.0, 8.0)), COLOR_OUTLINE, true)
	on.draw_arc(c + Vector2(5.0, 0.0), 3.0, -PI * 0.5, PI * 0.5, 8, COLOR_OUTLINE, 2.0)
	on.draw_line(c + Vector2(-2.0, -6.0), c + Vector2(-1.0, -9.0), COLOR_OUTLINE, 1.5)
	on.draw_line(c + Vector2(1.0, -6.0), c + Vector2(2.0, -9.0), COLOR_OUTLINE, 1.5)


## Cuadro eléctrico: rayo; gris y tachado si el ala está cortada
static func power(on: CanvasItem, pos: Vector2, cut: bool) -> void:
	badge(on, pos, COLOR_OFF if cut else COLOR_POWER)
	var bolt: PackedVector2Array = PackedVector2Array(
		[
			pos + Vector2(2.0, -8.0),
			pos + Vector2(-5.0, 1.0),
			pos + Vector2(0.0, 1.0),
			pos + Vector2(-2.0, 8.0),
			pos + Vector2(5.0, -2.0),
			pos + Vector2(0.0, -2.0)
		]
	)
	on.draw_colored_polygon(bolt, COLOR_OUTLINE)
	if cut:
		on.draw_line(pos + Vector2(-8.0, -8.0), pos + Vector2(8.0, 8.0), COLOR_ALARM, 3.0)


## Lámpara: punto tenue (la luz se lee en el tinte de la sala), amarillo si da luz
static func lamp(on: CanvasItem, pos: Vector2, lit: bool) -> void:
	on.draw_circle(pos, 3.5, Color(COLOR_OUTLINE, 0.6))
	on.draw_circle(pos, 2.0, Color(COLOR_POWER, 0.55) if lit else Color(COLOR_OFF, 0.6))


## Interruptor de la luz: palanca
static func light_switch(on: CanvasItem, pos: Vector2) -> void:
	on.draw_rect(Rect2(pos - Vector2(7.0, 9.0), Vector2(14.0, 18.0)), COLOR_OUTLINE, true)
	on.draw_rect(Rect2(pos - Vector2(5.0, 7.0), Vector2(10.0, 14.0)), COLOR_YOU, true)
	on.draw_rect(Rect2(pos - Vector2(2.5, 6.0), Vector2(5.0, 7.0)), COLOR_OUTLINE, true)


## Coche de huida
static func car(on: CanvasItem, pos: Vector2) -> void:
	on.draw_rect(Rect2(pos - Vector2(15.0, 8.0), Vector2(30.0, 14.0)), COLOR_OUTLINE, true)
	on.draw_rect(Rect2(pos - Vector2(13.0, 6.0), Vector2(26.0, 10.0)), COLOR_OK, true)
	on.draw_rect(Rect2(pos - Vector2(6.0, 11.0), Vector2(12.0, 6.0)), COLOR_OK, true)
	for x: float in [-8.0, 8.0]:
		on.draw_circle(pos + Vector2(x, 7.0), 4.0, COLOR_OUTLINE)


## Abanico semitransparente de una cámara (polígono ya en pantalla, con el vértice primero)
static func camera_fan(on: CanvasItem, fan: PackedVector2Array) -> void:
	on.draw_colored_polygon(fan, Color(COLOR_ALARM, 0.10))
	var edge: PackedVector2Array = fan.duplicate()
	edge.append(fan[0])
	on.draw_polyline(edge, Color(COLOR_ALARM, 0.35), 1.0)


static func camera(on: CanvasItem, pos: Vector2) -> void:
	on.draw_circle(pos, 8.0, COLOR_OUTLINE)
	on.draw_circle(pos, 5.5, COLOR_ALARM)
	on.draw_circle(pos, 2.0, COLOR_YOU)


static func vent(on: CanvasItem, pos: Vector2, network: String) -> void:
	on.draw_rect(Rect2(pos - Vector2(9.0, 9.0), Vector2(18.0, 18.0)), COLOR_OUTLINE, true)
	on.draw_rect(Rect2(pos - Vector2(7.0, 7.0), Vector2(14.0, 14.0)), COLOR_VENT, true)
	for y: float in [-3.0, 0.0, 3.0]:
		on.draw_line(pos + Vector2(-5.0, y), pos + Vector2(5.0, y), COLOR_OUTLINE, 1.5)
	if network != "":
		text(on, pos + Vector2(12.0, 7.0), network, 16, COLOR_VENT)


static func ping(on: CanvasItem, pos: Vector2) -> void:
	on.draw_arc(pos, 14.0, 0.0, TAU, 28, COLOR_OUTLINE, 6.0)
	on.draw_arc(pos, 14.0, 0.0, TAU, 28, COLOR_ALARM, 3.0)


## m:ss
static func clock(seconds: float) -> String:
	var total: int = maxi(0, int(seconds))
	return "%d:%02d" % [total / 60, total % 60]


## Texto monoespaciado de terminal, con contorno
static func mono(on: CanvasItem, pos: Vector2, label: String, size: int, color: Color) -> void:
	var font: FontFile = MenuTheme84.FONT_MONO
	on.draw_string_outline(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, COLOR_OUTLINE)
	on.draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## Marco de terminal: fondo opaco, borde fino con resplandor y esquinas marcadas
static func terminal_frame(on: CanvasItem, box: Rect2) -> void:
	on.draw_rect(box.grow(3.0), COLOR_OUTLINE)
	on.draw_rect(box, Color(COLOR_BG, 1.0))
	on.draw_rect(box.grow(2.0), Color(COLOR_TEXT, 0.12), false, 4.0)
	on.draw_rect(box, Color(COLOR_TEXT, 0.7), false, 1.5)
	var corner: float = 14.0
	for x: float in [box.position.x, box.end.x]:
		for y: float in [box.position.y, box.end.y]:
			var sx: float = 1.0 if x == box.position.x else -1.0
			var sy: float = 1.0 if y == box.position.y else -1.0
			on.draw_line(Vector2(x, y), Vector2(x + sx * corner, y), COLOR_HEADER, 3.0)
			on.draw_line(Vector2(x, y), Vector2(x, y + sy * corner), COLOR_HEADER, 3.0)


## Líneas de barrido CRT muy suaves sobre area (no tapan los textos)
static func scanlines(on: CanvasItem, area: Rect2) -> void:
	var y: float = area.position.y
	while y < area.end.y:
		on.draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color(0, 0, 0, 0.10), 1.0)
		y += 3.0
