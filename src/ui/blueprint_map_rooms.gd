## @file blueprint_map_rooms.gd
## Arquitectura del plano (#117): salas, muros y puertas con jerarquía.
## - Perímetro del museo grueso, galerías (salas con piezas) a trazo medio y cuartos de servicio
##   (sin piezas) finos, más oscuros y con tramado diagonal; la garita, en ámbar.
## - Silueta tenue en el suelo de las salas con «plan» en el nivel («circle», «frame»).
## - Nombre centrado como marca de agua; si no cabe, la abreviatura (con zoom cabe y sale entero).
## - Puertas interiores en cian discontinuo; el verde queda solo para las salidas.
## - Las salas se tiñen de cálido según la luz que dan sus lámparas.
class_name BlueprintMapRooms
extends RefCounted

const ICONS := preload("res://src/ui/blueprint_map_icons.gd")
const COLOR_GALLERY: Color = Color(0.10, 0.22, 0.36, 0.60)
const COLOR_SERVICE: Color = Color(0.06, 0.13, 0.22, 0.75)
const COLOR_OUTSIDE: Color = Color(0.05, 0.10, 0.16, 0.55)
const COLOR_WALL: Color = Color(0.80, 0.92, 1.0, 0.90)
const COLOR_HATCH: Color = Color(0.45, 0.62, 0.80, 0.12)
const COLOR_PLAN: Color = Color(0.70, 0.88, 1.0, 0.10)
const COLOR_LIGHT: Color = Color(1.0, 0.82, 0.45)
const COLOR_GRID: Color = Color(0.08, 0.20, 0.32, 0.35)
const COLOR_DOOR: Color = Color(0.55, 0.92, 1.0, 0.85)
const LABEL_SIZE: int = 22
const LABEL_ALPHA: float = 0.38
const HATCH_STEP: float = 9.0


## Salas con alguna pieza candidata (galerías): {id: true}
static func galleries(data: LevelData) -> Dictionary:
	var found: Dictionary = {}
	for target: Dictionary in data.section("targets"):
		var pos: Vector2 = Vector2(float(target["pos"][0]), float(target["pos"][1]))
		for room: Dictionary in data.section("rooms"):
			if data.room_rect(room).has_point(pos):
				found[String(room["id"])] = true
	return found


## Fracción de lámparas encendidas por sala (0..1): {id: float}; sin lámparas no sale
static func light_levels(data: LevelData, lamps: Array[Lamp3D]) -> Dictionary:
	var lit: Dictionary = {}
	var total: Dictionary = {}
	for lamp: Lamp3D in lamps:
		if not is_instance_valid(lamp):
			continue
		var pos: Vector2 = Vector2(
			lamp.global_position.x - data.offset.x, lamp.global_position.z - data.offset.y
		)
		for room: Dictionary in data.section("rooms"):
			if data.room_rect(room).has_point(pos):
				var id: String = String(room["id"])
				total[id] = int(total.get(id, 0)) + 1
				lit[id] = int(lit.get(id, 0)) + (1 if lamp.is_lit() else 0)
	var levels: Dictionary = {}
	for id: String in total:
		levels[id] = float(lit[id]) / float(total[id])
	return levels


## Rellenos, tramados, siluetas, muros y nombres. to_map: Vector2 del diseño → pantalla
static func draw(
	on: CanvasItem, data: LevelData, to_map: Callable, scale: float, light: Dictionary
) -> void:
	var gallery: Dictionary = galleries(data)
	var inside: Rect2 = Rect2()
	var first: bool = true
	for room: Dictionary in data.section("rooms"):
		var ui: Rect2 = _ui_rect(data, room, to_map, scale)
		var id: String = String(room["id"])
		if bool(room.get("exterior", false)):
			on.draw_rect(ui, COLOR_OUTSIDE)
			continue
		inside = ui if first else inside.merge(ui)
		first = false
		if bool(room.get("guard_post", false)):
			on.draw_rect(ui, Color(ICONS.COLOR_POST, 0.28))
		elif gallery.has(id):
			on.draw_rect(ui, COLOR_GALLERY)
		else:
			on.draw_rect(ui, COLOR_SERVICE)
			_hatch(on, ui)
		if light.has(id):
			on.draw_rect(ui, Color(COLOR_LIGHT, 0.10 * float(light[id])))
		_plan(on, ui, String(room.get("plan", "")))
	for room: Dictionary in data.section("rooms"):
		var ui: Rect2 = _ui_rect(data, room, to_map, scale)
		var id: String = String(room["id"])
		if bool(room.get("guard_post", false)):
			on.draw_rect(ui, ICONS.COLOR_POST, false, 3.0)
		elif not bool(room.get("exterior", false)):
			on.draw_rect(ui, COLOR_WALL, false, 2.0 if gallery.has(id) else 1.0)
	if not first:
		on.draw_rect(inside, COLOR_WALL, false, 4.0)
	for room: Dictionary in data.section("rooms"):
		_label(on, room, _ui_rect(data, room, to_map, scale))


## Puertas: interiores en cian discontinuo, la de la garita en ámbar y las salidas en verde
static func draw_doors(on: CanvasItem, data: LevelData, to_map: Callable, scale: float) -> void:
	var exits: Array = []
	for exit_data: Dictionary in data.section("exits"):
		exits.append(String(exit_data["id"]))
	for door: Dictionary in data.section("doors"):
		var pos: Vector2 = to_map.call(Vector2(float(door["pos"][0]), float(door["pos"][1])))
		var half: float = float(door.get("width", 1.2)) * scale * 0.5
		var along: Vector2 = Vector2(half, 0.0)
		if LevelArchitectureBuilder._door_axis(data, door) == "V":
			along = Vector2(0.0, half)
		on.draw_line(pos - along, pos + along, ICONS.COLOR_BG, 6.0)  # el hueco en el muro
		if exits.has(String(door["id"])):
			on.draw_line(pos - along, pos + along, ICONS.COLOR_OUTLINE, 10.0)
			on.draw_line(pos - along, pos + along, ICONS.COLOR_OK, 6.0)
			ICONS.text_centered(on, pos + Vector2(0.0, 28.0), "SALIDA", 18, ICONS.COLOR_OK)
		elif door.has("leaf"):
			on.draw_line(pos - along, pos + along, ICONS.COLOR_POST, 3.0)
		else:
			on.draw_dashed_line(pos - along, pos + along, COLOR_DOOR, 2.0, 5.0)


static func _ui_rect(data: LevelData, room: Dictionary, to_map: Callable, scale: float) -> Rect2:
	var rect: Rect2 = data.room_rect(room)
	return Rect2(to_map.call(rect.position), rect.size * scale)


## Tramado diagonal (45°) dentro de ui
static func _hatch(on: CanvasItem, ui: Rect2) -> void:
	var w: float = ui.size.x
	var h: float = ui.size.y
	var t: float = -h
	while t < w:
		var start: Vector2 = ui.position + (Vector2(t, 0.0) if t >= 0.0 else Vector2(0.0, -t))
		var length: float = minf(w - t, h) if t >= 0.0 else minf(w, h + t)
		on.draw_line(start, start + Vector2(length, length), COLOR_HATCH, 1.0)
		t += HATCH_STEP


## Silueta de referencia en el suelo: un círculo (rotonda) o un marco interior (cámara)
static func _plan(on: CanvasItem, ui: Rect2, plan: String) -> void:
	match plan:
		"circle":
			var radius: float = minf(ui.size.x, ui.size.y) * 0.36
			on.draw_arc(ui.get_center(), radius, 0.0, TAU, 48, COLOR_PLAN, 3.0)
			on.draw_arc(ui.get_center(), radius * 0.55, 0.0, TAU, 40, COLOR_PLAN, 2.0)
		"frame":
			on.draw_rect(ui.grow(-minf(ui.size.x, ui.size.y) * 0.16), COLOR_PLAN, false, 3.0)


## Nombre centrado como marca de agua; la abreviatura si no cabe (la garita, en ámbar)
static func _label(on: CanvasItem, room: Dictionary, ui: Rect2) -> void:
	if bool(room.get("guard_post", false)):
		ICONS.text(on, ui.position + Vector2(8.0, 30.0), "GARITA", 30, ICONS.COLOR_POST)
		return
	var label: String = String(room.get("name", room["id"])).to_upper()
	if ICONS.FONT.get_string_size(label, 0, -1, LABEL_SIZE).x > ui.size.x - 16.0:
		label = String(room["id"])
	var width: float = ICONS.FONT.get_string_size(label, 0, -1, LABEL_SIZE).x
	var at: Vector2 = ui.get_center() + Vector2(-width * 0.5, LABEL_SIZE * 0.35)
	var color: Color = Color(ICONS.COLOR_TEXT, LABEL_ALPHA)
	on.draw_string(ICONS.FONT, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, color)


## Cuadrícula de 2 m entre start y end (pantalla), cada step píxeles
static func draw_grid(on: CanvasItem, start: Vector2, end: Vector2, step: float) -> void:
	for i: int in range(int((end.x - start.x) / step) + 1):
		var x: float = start.x + i * step
		on.draw_line(Vector2(x, start.y), Vector2(x, end.y), COLOR_GRID, 1.0)
	for i: int in range(int((end.y - start.y) / step) + 1):
		var y: float = start.y + i * step
		on.draw_line(Vector2(start.x, y), Vector2(end.x, y), COLOR_GRID, 1.0)
