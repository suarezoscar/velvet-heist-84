## @file blueprint_map_overlay.gd
## Plano cianotipo del museo (FEAT-034, #117), con [M] o [TAB]. Sale de los datos del nivel (el
## mapa los deja en su meta «level_data»): salas, puertas, salidas y cámaras, la garita en ámbar,
## los objetos interactivos (BlueprintMapProps), tu punto («TÚ» y hacia dónde miras), una
## campana donde saltó cada alarma («hace 1:20») y una leyenda por bando (BlueprintMapLegend).
## Rueda del ratón: zoom hacia el cursor; botón central: arrastrar el plano. Además:
## - el ladrón ve su encargo (rosa; ✔ las que lleva), las rejillas, la mesa de copias, el
##   coche y los objetos sueltos;
## - los guardias ven a sus compañeros («G2»), todas las candidatas con su protección
##   (✘ rastro descubierto, ✔ auténtica examinada) y las marcas del walkie.
## Solo lee el estado que ya tiene el cliente.
class_name BlueprintMapOverlay
extends Control

const ICONS := preload("res://src/ui/blueprint_map_icons.gd")
const PROPS := preload("res://src/ui/blueprint_map_props.gd")
const LEGEND := preload("res://src/ui/blueprint_map_legend.gd")
const COLOR_BG: Color = ICONS.COLOR_BG
const COLOR_GRID: Color = Color(0.08, 0.20, 0.32, 0.40)
const COLOR_ROOM: Color = Color(0.10, 0.22, 0.36, 0.55)
const COLOR_OUTSIDE: Color = Color(0.06, 0.12, 0.18, 0.55)
const COLOR_WALL: Color = Color(0.80, 0.92, 1.0, 0.90)
const COLOR_DOOR: Color = Color(0.20, 0.90, 0.60, 0.95)
const MARGIN: float = 16.0
const HEADER: float = 70.0
const FOOTER: float = 16.0
const ROOM_LABEL: int = 20
const ZOOM_MAX: float = 4.0
const ZOOM_STEP: float = 1.2
## Objetos que solo salen en el plano del ladrón
const THIEF_ONLY: Array[StringName] = [&"copy", &"car", &"loot"]

var data: LevelData = null
var player_pawn: Node3D = null
## 1 = todo el museo; hasta ZOOM_MAX
var zoom: float = 1.0
var _scale: float = 10.0
var _origin: Vector2 = Vector2.ZERO
var _area: Rect2 = Rect2()
var _bounds: Rect2 = Rect2()
## Punto del nivel (en metros de diseño) que queda en el centro del área
var _center: Vector2 = Vector2.ZERO
var _props: Array[Node3D] = []
var _time: float = 0.0


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_blueprint"):
		toggle_map()
		get_viewport().set_input_as_handled()
		return
	if not visible or data == null:
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed:
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_at(button.position, zoom * ZOOM_STEP)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_at(button.position, zoom / ZOOM_STEP)
		else:
			return
		get_viewport().set_input_as_handled()
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and motion.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		_center -= motion.relative / _scale
		get_viewport().set_input_as_handled()


func toggle_map() -> void:
	visible = not visible
	if not visible:
		return
	var scene: Node = get_tree().current_scene
	if data == null and scene != null and scene.has_meta(&"level_data"):
		data = scene.get_meta(&"level_data") as LevelData
	_props = PROPS.collect(scene)
	zoom = 1.0
	_center = Vector2.INF  # se centra en el nivel al dibujar


## Cambia el zoom dejando quieto el punto del plano que hay bajo screen_pos
func zoom_at(screen_pos: Vector2, new_zoom: float) -> void:
	var under: Vector2 = (screen_pos - _origin) / _scale
	zoom = clampf(new_zoom, 1.0, ZOOM_MAX)
	var new_scale: float = _base_scale() * zoom
	_center = under - (screen_pos - _area.get_center()) / new_scale


func _process(delta: float) -> void:
	if visible:
		_time += delta
		queue_redraw()


func _draw() -> void:
	var view: Vector2 = get_viewport_rect().size
	var panel: Rect2 = Rect2(MARGIN, MARGIN, view.x - MARGIN * 2.0, view.y - MARGIN * 2.0)
	draw_rect(panel, COLOR_BG, true)
	if data == null:
		ICONS.text(self, panel.get_center(), "Sin plano para este mapa", 22, ICONS.COLOR_TEXT)
		return
	_fit(panel)
	_draw_grid()
	_draw_rooms()
	_draw_doors()
	var thief_view: bool = HeistDirector.local_is_thief(get_tree())
	for prop: Node3D in _props:
		var kind: StringName = PROPS.kind_of(prop)
		if PROPS.shown(prop) and (thief_view or not THIEF_ONLY.has(kind)):
			PROPS.icon(self, kind, _world(prop.global_position), prop)
	_draw_cameras()
	if thief_view:
		_draw_vents()
	_draw_pieces(thief_view)
	if not thief_view:
		_draw_pings()
		_draw_mates()
	_draw_alarms()
	_draw_player()
	_mask_outside(view)
	_draw_frame(panel)
	LEGEND.draw(self, panel, panel.position.y + HEADER, thief_view)


## Escala y origen: el nivel entero cabe con zoom 1 (dejando sitio a la leyenda a la derecha)
func _fit(panel: Rect2) -> void:
	var first: bool = true
	for room: Dictionary in data.section("rooms"):
		_bounds = data.room_rect(room) if first else _bounds.merge(data.room_rect(room))
		first = false
	var free: Vector2 = panel.size - Vector2(LEGEND.WIDTH + 64.0, HEADER + FOOTER)
	_area = Rect2(panel.position + Vector2(24.0, HEADER), free)
	_scale = _base_scale() * zoom
	if _center == Vector2.INF:
		_center = _bounds.get_center()
	# Sin salirse del nivel: con zoom 1 queda centrado
	var half: Vector2 = _area.size * 0.5 / _scale
	var lo: Vector2 = _bounds.position + half
	var hi: Vector2 = _bounds.end - half
	_center.x = _bounds.get_center().x if lo.x > hi.x else clampf(_center.x, lo.x, hi.x)
	_center.y = _bounds.get_center().y if lo.y > hi.y else clampf(_center.y, lo.y, hi.y)
	_origin = _area.get_center() - _center * _scale


func _base_scale() -> float:
	if _bounds.size.x <= 0.0 or _bounds.size.y <= 0.0:
		return 10.0
	return minf(_area.size.x / _bounds.size.x, _area.size.y / _bounds.size.y)


func _draw_grid() -> void:
	var step: float = _scale * 2.0
	var start: Vector2 = _to_map(_bounds.position)
	var end: Vector2 = _to_map(_bounds.end)
	for i: int in range(int((end.x - start.x) / step) + 1):
		var x: float = start.x + i * step
		draw_line(Vector2(x, start.y), Vector2(x, end.y), COLOR_GRID, 1.0)
	for i: int in range(int((end.y - start.y) / step) + 1):
		var y: float = start.y + i * step
		draw_line(Vector2(start.x, y), Vector2(end.x, y), COLOR_GRID, 1.0)


## Tapa lo que sobresale del área al hacer zoom (hasta los bordes de la pantalla)
func _mask_outside(view: Vector2) -> void:
	var a: Rect2 = _area
	draw_rect(Rect2(0.0, 0.0, view.x, a.position.y), COLOR_BG)
	draw_rect(Rect2(0.0, a.end.y, view.x, view.y - a.end.y), COLOR_BG)
	draw_rect(Rect2(0.0, a.position.y, a.position.x, a.size.y), COLOR_BG)
	draw_rect(Rect2(a.end.x, a.position.y, view.x - a.end.x, a.size.y), COLOR_BG)


func _draw_frame(panel: Rect2) -> void:
	draw_rect(panel, COLOR_WALL, false, 2.0)
	var title: Vector2 = panel.position + Vector2(24.0, 38.0)
	ICONS.text(self, title, "PLANO DEL MUSEO VELVET '84", 30, ICONS.COLOR_HEADER)
	var hint: String = "[M] / [TAB] CERRAR   ·   RUEDA: ZOOM   ·   BOTÓN CENTRAL: MOVER"
	ICONS.text(self, panel.position + Vector2(24.0, 60.0), hint, 16, ICONS.COLOR_TEXT)


func _draw_rooms() -> void:
	for room: Dictionary in data.section("rooms"):
		var rect: Rect2 = data.room_rect(room)
		var ui: Rect2 = Rect2(_to_map(rect.position), rect.size * _scale)
		var post: bool = bool(room.get("guard_post", false))
		var fill: Color = COLOR_OUTSIDE if bool(room.get("exterior", false)) else COLOR_ROOM
		draw_rect(ui, Color(ICONS.COLOR_POST, 0.28) if post else fill, true)
		draw_rect(ui, ICONS.COLOR_POST if post else COLOR_WALL, false, 3.0 if post else 2.0)
		if post:
			ICONS.text(self, ui.position + Vector2(8.0, 30.0), "GARITA", 30, ICONS.COLOR_POST)
			continue
		var label: String = String(room.get("name", room["id"])).to_upper()
		if ICONS.FONT.get_string_size(label, 0, -1, ROOM_LABEL).x > ui.size.x - 12.0:
			label = String(room["id"])
		ICONS.text(self, ui.position + Vector2(7.0, 23.0), label, ROOM_LABEL, ICONS.COLOR_TEXT)


func _draw_doors() -> void:
	var exits: Array = []
	for exit_data: Dictionary in data.section("exits"):
		exits.append(String(exit_data["id"]))
	for door: Dictionary in data.section("doors"):
		var pos: Vector2 = _to_map(Vector2(float(door["pos"][0]), float(door["pos"][1])))
		var half: float = float(door.get("width", 1.2)) * _scale * 0.5
		var along: Vector2 = Vector2(half, 0.0)
		if LevelArchitectureBuilder._door_axis(data, door) == "V":
			along = Vector2(0.0, half)
		var exit: bool = exits.has(String(door["id"]))
		draw_line(pos - along, pos + along, ICONS.COLOR_OUTLINE, 9.0)
		var color: Color = ICONS.COLOR_HEADER if door.has("leaf") else COLOR_DOOR
		draw_line(pos - along, pos + along, ICONS.COLOR_OK if exit else color, 5.0)
		if exit:
			ICONS.text_centered(self, pos + Vector2(0.0, 26.0), "SALIDA", 18, ICONS.COLOR_OK)


func _draw_cameras() -> void:
	for cam: Dictionary in data.section("cameras"):
		ICONS.camera(self, _to_map(Vector2(float(cam["pos"][0]), float(cam["pos"][1]))))


func _draw_vents() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"vents"):
		var vent: Vent3D = node as Vent3D
		ICONS.vent(self, _world(vent.global_position), vent.network.substr(0, 1).to_upper())


func _draw_pieces(thief_view: bool) -> void:
	var heist: HeistDirector = GameManager.heist
	for node: Node in get_tree().get_nodes_in_group(&"heist_targets"):
		var piece: TargetPiece3D = node as TargetPiece3D
		var pos: Vector2 = _world(piece.global_position)
		if thief_view:
			if heist == null or not heist.is_in_contract(piece.piece_id):
				continue
			var pink: Color = TeamMarker3D.THIEF_COLOR
			ICONS.glyph(self, pos, "✔" if heist.stolen.has(piece.piece_id) else "◆", 24, pink)
			ICONS.text(self, pos + Vector2(15.0, 7.0), piece.piece_name, 17, pink)
			continue
		var icon: String = ICONS.PROTECTION_ICONS.get(piece.protection, "◆")
		var color: Color = TeamMarker3D.GUARD_COLOR
		if piece.discovered:
			icon = "✘"
			color = ICONS.COLOR_ALARM
		elif piece.inspected:
			color = ICONS.COLOR_OK
		ICONS.glyph(self, pos, icon, 22, color)


func _draw_pings() -> void:
	var alert: AlertDirector = AlertDirector.of(get_tree())
	if alert != null:
		for ping: Dictionary in alert.pings:
			ICONS.ping(self, _world(ping["pos"]))


## Los demás guardias, con su número
func _draw_mates() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"guards"):
		var guard: GuardController3D = node as GuardController3D
		if guard != null and guard != player_pawn:
			ICONS.mate(self, _world(guard.global_position), "G%d" % guard.guard_id)


## Una campana por cada vez que saltó la alarma (los dos bandos)
func _draw_alarms() -> void:
	var alert: AlertDirector = AlertDirector.of(get_tree())
	if alert != null:
		for mark: Dictionary in alert.alarm_marks:
			ICONS.alarm(self, _world(mark["pos"]), float(mark["t"]) - GameManager.match_timer)


func _draw_player() -> void:
	if player_pawn == null or not is_instance_valid(player_pawn):
		return
	var color: Color = (
		TeamMarker3D.THIEF_COLOR if player_pawn is ThiefController3D else TeamMarker3D.GUARD_COLOR
	)
	var forward: Vector3 = -player_pawn.global_transform.basis.z
	var pulse: float = fmod(_time, 1.2) / 1.2
	ICONS.you(
		self, _world(player_pawn.global_position), Vector2(forward.x, forward.z), color, pulse
	)


func _world(pos: Vector3) -> Vector2:
	return _to_map(Vector2(pos.x - data.offset.x, pos.z - data.offset.y))


func _to_map(design: Vector2) -> Vector2:
	return _origin + design * _scale
