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
## Siluetas blancas de game-icons.net (CC BY 3.0, créditos en assets/ui/map_icons/CREDITS.md):
## se tiñen al dibujarlas
const SPRITES: Dictionary = {
	&"cctv_camera": preload("res://assets/ui/map_icons/cctv_camera.svg"),
	&"city_car": preload("res://assets/ui/map_icons/city_car.svg"),
	&"coffee_cup": preload("res://assets/ui/map_icons/coffee_cup.svg"),
	&"coins": preload("res://assets/ui/map_icons/coins.svg"),
	&"cross_mark": preload("res://assets/ui/map_icons/cross_mark.svg"),
	&"cut_diamond": preload("res://assets/ui/map_icons/cut_diamond.svg"),
	&"dial_padlock": preload("res://assets/ui/map_icons/dial_padlock.svg"),
	&"easel": preload("res://assets/ui/map_icons/easel.svg"),
	&"exit_door": preload("res://assets/ui/map_icons/exit_door.svg"),
	&"floor_hatch": preload("res://assets/ui/map_icons/floor_hatch.svg"),
	&"eye_target": preload("res://assets/ui/map_icons/eye_target.svg"),
	&"light_bulb": preload("res://assets/ui/map_icons/light_bulb.svg"),
	&"police_officer_head": preload("res://assets/ui/map_icons/police_officer_head.svg"),
	&"power_lightning": preload("res://assets/ui/map_icons/power_lightning.svg"),
	&"radar_sweep": preload("res://assets/ui/map_icons/radar_sweep.svg"),
	&"ringing_bell": preload("res://assets/ui/map_icons/ringing_bell.svg"),
	&"toggles": preload("res://assets/ui/map_icons/toggles.svg"),
	&"tv": preload("res://assets/ui/map_icons/tv.svg"),
	&"walkie_talkie": preload("res://assets/ui/map_icons/walkie_talkie.svg"),
	&"weight": preload("res://assets/ui/map_icons/weight.svg"),
}
## Icono de cada protección en las fichas de los guardias
const PROTECTION_SPRITES: Dictionary = {
	&"combination": &"dial_padlock", &"pressure": &"weight", &"sensor": &"eye_target"
}


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


## Lo que se dibuje después sale escalado k veces alrededor de pos (con k = 1, sin escalar)
static func at(on: CanvasItem, pos: Vector2, k: float) -> Vector2:
	on.draw_set_transform(pos * (1.0 - k), 0.0, Vector2(k, k))
	return pos


## Silueta sprite centrada en pos, de size píxeles y teñida de color
static func sprite(
	on: CanvasItem, pos: Vector2, kind: StringName, size: float, color: Color
) -> void:
	var texture: Texture2D = SPRITES.get(kind) as Texture2D
	if texture != null:
		var rect: Rect2 = Rect2(pos - Vector2(size, size) * 0.5, Vector2(size, size))
		on.draw_texture_rect(texture, rect, false, color)


## Pegatina: la silueta con un borde oscuro grueso alrededor
static func sticker(
	on: CanvasItem, pos: Vector2, kind: StringName, size: float, color: Color
) -> void:
	for i: int in range(8):
		sprite(on, pos + Vector2.RIGHT.rotated(TAU * i / 8.0) * 2.5, kind, size, COLOR_OUTLINE)
	sprite(on, pos, kind, size, color)


## Chapa redonda: borde oscuro, relleno y aro claro, con la silueta kind en oscuro dentro
static func badge(on: CanvasItem, pos: Vector2, fill: Color, kind: StringName = &"") -> void:
	on.draw_circle(pos, BADGE + 3.0, COLOR_OUTLINE)
	on.draw_circle(pos, BADGE, fill)
	on.draw_arc(pos, BADGE - 1.0, 0.0, TAU, 28, Color(1.0, 1.0, 1.0, 0.85), 2.0)
	if kind != &"":
		sprite(on, pos, kind, BADGE * 1.45, COLOR_OUTLINE)


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
	badge(on, pos, TeamMarker3D.GUARD_COLOR, &"police_officer_head")
	text(on, pos + Vector2(15.0, 7.0), label, 19, TeamMarker3D.GUARD_COLOR)


## Campana roja donde saltó una alarma, con pulso; ago en segundos va en una píldora oscura
## con borde rojo («hace 1:20»), < 0 para no ponerlo
static func alarm(on: CanvasItem, pos: Vector2, ago: float, pulse: float = 0.0) -> void:
	if pulse > 0.0:
		on.draw_arc(
			pos, 8.0 + pulse * 18.0, 0.0, TAU, 28, Color(COLOR_ALARM, 0.7 * (1.0 - pulse)), 2.5
		)
	sticker(on, pos, &"ringing_bell", 26.0, COLOR_ALARM)
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
	badge(on, pos, color, &"coffee_cup")


## Cuadro eléctrico: rayo; gris y tachado si el ala está cortada
static func power(on: CanvasItem, pos: Vector2, cut: bool) -> void:
	badge(on, pos, COLOR_OFF if cut else COLOR_POWER, &"power_lightning")
	if cut:
		on.draw_line(pos + Vector2(-9.0, -9.0), pos + Vector2(9.0, 9.0), COLOR_OUTLINE, 6.0)
		on.draw_line(pos + Vector2(-9.0, -9.0), pos + Vector2(9.0, 9.0), COLOR_ALARM, 3.0)


## Lámpara: punto tenue (la luz se lee en el tinte de la sala), amarillo si da luz
static func lamp(on: CanvasItem, pos: Vector2, lit: bool) -> void:
	on.draw_circle(pos, 3.5, Color(COLOR_OUTLINE, 0.6))
	on.draw_circle(pos, 2.0, Color(COLOR_POWER, 0.55) if lit else Color(COLOR_OFF, 0.6))


## Interruptor de la luz
static func light_switch(on: CanvasItem, pos: Vector2) -> void:
	sticker(on, pos, &"toggles", 18.0, COLOR_YOU)


## Coche de huida
static func car(on: CanvasItem, pos: Vector2) -> void:
	sticker(on, pos, &"city_car", 32.0, COLOR_OK)


## Salida (en la leyenda y junto al rótulo «SALIDA»)
static func exit_door(on: CanvasItem, pos: Vector2, size: float = 20.0) -> void:
	sticker(on, pos, &"exit_door", size, COLOR_OK)


## Pieza: pegatina de su protección (guardias) o del diamante del encargo (ladrón)
static func piece(on: CanvasItem, pos: Vector2, kind: StringName, color: Color) -> void:
	sticker(on, pos, kind, 24.0, color)


## Abanico semitransparente de una cámara (polígono ya en pantalla, con el vértice primero)
static func camera_fan(on: CanvasItem, fan: PackedVector2Array) -> void:
	on.draw_colored_polygon(fan, Color(COLOR_ALARM, 0.10))
	var edge: PackedVector2Array = fan.duplicate()
	edge.append(fan[0])
	on.draw_polyline(edge, Color(COLOR_ALARM, 0.35), 1.0)


static func camera(on: CanvasItem, pos: Vector2) -> void:
	badge(on, pos, COLOR_ALARM, &"cctv_camera")


static func vent(on: CanvasItem, pos: Vector2, network: String) -> void:
	sticker(on, pos, &"floor_hatch", 20.0, COLOR_VENT)
	if network != "":
		text(on, pos + Vector2(12.0, 7.0), network, 16, COLOR_VENT)


static func ping(on: CanvasItem, pos: Vector2) -> void:
	sticker(on, pos, &"radar_sweep", 30.0, COLOR_ALARM)


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
