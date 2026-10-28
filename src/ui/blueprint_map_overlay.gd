## @file blueprint_map_overlay.gd
## Plano cianotipo del museo (FEAT-034), con [M] o [TAB]. Sale de los datos del nivel (el mapa
## los deja en su meta «level_data»): salas con su nombre, puertas, salidas y cámaras. Además:
## - el ladrón ve su encargo (rosa; ✔ las que lleva) y las rejillas de ventilación;
## - los guardias ven todas las candidatas con su protección (✘ rastro descubierto, ✔ auténtica
##   examinada), su ruta de relojes con el siguiente marcado y las marcas del walkie.
## Solo lee el estado que ya tiene el cliente.
class_name BlueprintMapOverlay
extends Control

const COLOR_BG: Color = Color(0.04, 0.10, 0.18, 0.96)
const COLOR_GRID: Color = Color(0.08, 0.20, 0.32, 0.40)
const COLOR_ROOM: Color = Color(0.10, 0.22, 0.36, 0.55)
const COLOR_OUTSIDE: Color = Color(0.06, 0.12, 0.18, 0.55)
const COLOR_WALL: Color = Color(0.80, 0.92, 1.0, 0.90)
const COLOR_DOOR: Color = Color(0.20, 0.90, 0.60, 0.85)
const COLOR_TEXT: Color = Color(0.70, 0.88, 1.0, 0.95)
const COLOR_HEADER: Color = Color(1.0, 0.82, 0.40, 1.0)
const COLOR_FOUND: Color = Color("ff4a3d")
const COLOR_OK: Color = Color("4be38a")
const COLOR_VENT: Color = Color(0.6, 0.62, 0.68, 0.9)
const MARGIN: float = 40.0
const HEADER: float = 70.0
const FOOTER: float = 34.0
## Icono de cada protección en las fichas de los guardias
const PROTECTION_ICONS: Dictionary = {&"combination": "◎", &"pressure": "▣", &"sensor": "ϟ"}

var data: LevelData = null
var player_pawn: Node3D = null
var _scale: float = 10.0
var _origin: Vector2 = Vector2.ZERO
var _area: Rect2 = Rect2()


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_blueprint"):
		toggle_map()
		get_viewport().set_input_as_handled()


func toggle_map() -> void:
	visible = not visible
	if visible and data == null:
		var scene: Node = get_tree().current_scene
		if scene != null and scene.has_meta(&"level_data"):
			data = scene.get_meta(&"level_data") as LevelData


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	var view: Vector2 = get_viewport_rect().size
	var panel: Rect2 = Rect2(MARGIN, MARGIN, view.x - MARGIN * 2.0, view.y - MARGIN * 2.0)
	draw_rect(panel, COLOR_BG, true)
	draw_rect(panel, COLOR_WALL, false, 2.0)
	_text(panel.position + Vector2(24.0, 34.0), "PLANO DEL MUSEO VELVET '84", 22, COLOR_HEADER)
	_text(
		panel.position + Vector2(24.0, 56.0),
		"DOCUMENTO DE SEGURIDAD // [M] / [TAB] PARA CERRAR",
		13,
		COLOR_TEXT
	)
	if data == null:
		_text(panel.get_center(), "Sin plano para este mapa", 18, COLOR_TEXT)
		return
	_fit(panel)
	for x: float in range(int(_area.position.x), int(_area.end.x), int(_scale * 2.0)):
		draw_line(Vector2(x, _area.position.y), Vector2(x, _area.end.y), COLOR_GRID, 1.0)
	for y: float in range(int(_area.position.y), int(_area.end.y), int(_scale * 2.0)):
		draw_line(Vector2(_area.position.x, y), Vector2(_area.end.x, y), COLOR_GRID, 1.0)
	_draw_rooms()
	_draw_doors()
	var thief_view: bool = HeistDirector.local_is_thief(get_tree())
	_draw_cameras()
	if thief_view:
		_draw_vents()
	_draw_pieces(thief_view)
	if not thief_view:
		_draw_route()
		_draw_pings()
	_draw_player()
	_text(Vector2(panel.position.x + 24.0, panel.end.y - 12.0), _legend(thief_view), 13, COLOR_TEXT)


## Escala para que todo el nivel quepa en el panel
func _fit(panel: Rect2) -> void:
	var bounds: Rect2 = Rect2()
	var first: bool = true
	for room: Dictionary in data.section("rooms"):
		bounds = data.room_rect(room) if first else bounds.merge(data.room_rect(room))
		first = false
	var space: Vector2 = panel.size - Vector2(48.0, HEADER + FOOTER)
	_scale = minf(space.x / bounds.size.x, space.y / bounds.size.y)
	var size: Vector2 = bounds.size * _scale
	_area = Rect2(panel.position + Vector2((panel.size.x - size.x) * 0.5, HEADER), size)
	_origin = _area.position - bounds.position * _scale


func _draw_rooms() -> void:
	for room: Dictionary in data.section("rooms"):
		var rect: Rect2 = data.room_rect(room)
		var ui: Rect2 = Rect2(_to_map(rect.position), rect.size * _scale)
		var outside: bool = bool(room.get("exterior", false))
		draw_rect(ui, COLOR_OUTSIDE if outside else COLOR_ROOM, true)
		draw_rect(ui, COLOR_WALL, false, 1.5)
		var label: String = String(room.get("name", room["id"])).to_upper()
		if ui.size.x < 110.0:
			label = String(room["id"])
		_text(ui.position + Vector2(5.0, 13.0), label, 10, COLOR_TEXT)


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
		draw_line(pos - along, pos + along, COLOR_BG, 4.0)
		var color: Color = COLOR_HEADER if door.has("leaf") else COLOR_DOOR
		draw_line(pos - along, pos + along, color, 2.5)
		if exits.has(String(door["id"])):
			_text(pos + Vector2(-20.0, 16.0), "SALIDA", 11, COLOR_OK)


func _draw_cameras() -> void:
	for cam: Dictionary in data.section("cameras"):
		var pos: Vector2 = _to_map(Vector2(float(cam["pos"][0]), float(cam["pos"][1])))
		draw_circle(pos, 3.5, COLOR_FOUND)


func _draw_vents() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"vents"):
		var vent: Vent3D = node as Vent3D
		var pos: Vector2 = _world(vent.global_position)
		draw_rect(Rect2(pos - Vector2(4.0, 4.0), Vector2(8.0, 8.0)), COLOR_VENT, false, 1.5)
		_text(pos + Vector2(6.0, 4.0), vent.network.substr(0, 1).to_upper(), 9, COLOR_VENT)


func _draw_pieces(thief_view: bool) -> void:
	var heist: HeistDirector = GameManager.heist
	for node: Node in get_tree().get_nodes_in_group(&"heist_targets"):
		var piece: TargetPiece3D = node as TargetPiece3D
		var pos: Vector2 = _world(piece.global_position)
		if thief_view:
			if heist == null or not heist.is_in_contract(piece.piece_id):
				continue
			var done: bool = heist.stolen.has(piece.piece_id)
			_text(pos + Vector2(-5.0, 5.0), "✔" if done else "◆", 15, TeamMarker3D.THIEF_COLOR)
			_text(pos + Vector2(9.0, 4.0), piece.piece_name, 10, TeamMarker3D.THIEF_COLOR)
			continue
		var icon: String = PROTECTION_ICONS.get(piece.protection, "◆")
		var color: Color = TeamMarker3D.GUARD_COLOR
		if piece.discovered:
			icon = "✘"
			color = COLOR_FOUND
		elif piece.inspected:
			color = COLOR_OK
		_text(pos + Vector2(-5.0, 5.0), icon, 14, color)


func _draw_route() -> void:
	var round_node: GuardRound = GuardRound.of(player_pawn)
	if round_node == null:
		return
	for node: Node in get_tree().get_nodes_in_group(&"time_clock"):
		var clock: TimeClock3D = node as TimeClock3D
		var pos: Vector2 = _world(clock.global_position)
		var order: int = round_node.route.find(clock.clock_id)
		var next: bool = clock.clock_id == round_node.next_clock()
		var color: Color = COLOR_HEADER if next else (COLOR_TEXT if order >= 0 else COLOR_GRID)
		if next:
			draw_arc(pos, 9.0, 0.0, TAU, 24, COLOR_HEADER, 2.0)
		_text(pos + Vector2(-8.0, 4.0), "R%d" % clock.clock_id, 11, color)


func _draw_pings() -> void:
	var alert: AlertDirector = AlertDirector.of(get_tree())
	if alert == null:
		return
	for ping: Dictionary in alert.pings:
		draw_arc(_world(ping["pos"]), 10.0, 0.0, TAU, 24, COLOR_FOUND, 2.0)


func _draw_player() -> void:
	if player_pawn == null or not is_instance_valid(player_pawn):
		return
	var pos: Vector2 = _world(player_pawn.global_position)
	var color: Color = (
		TeamMarker3D.THIEF_COLOR if player_pawn is ThiefController3D else TeamMarker3D.GUARD_COLOR
	)
	draw_circle(pos, 5.0, color)
	draw_arc(pos, 10.0, 0.0, TAU, 24, Color(color, 0.5), 2.0)


func _legend(thief_view: bool) -> String:
	if thief_view:
		return "◆ TU ENCARGO   ✔ ROBADA   □ VENTILACIÓN (S/O/E)   ● CÁMARA"
	return "◎ COMBINACIÓN   ▣ PRESIÓN   ϟ SENSOR   ✘ RASTRO   R RELOJ (○ EL SIGUIENTE)   ● CÁMARA"


func _world(pos: Vector3) -> Vector2:
	return _to_map(Vector2(pos.x - data.offset.x, pos.z - data.offset.y))


func _to_map(design: Vector2) -> Vector2:
	return _origin + design * _scale


func _text(pos: Vector2, text: String, size: int, color: Color) -> void:
	draw_string(MenuTheme84.FONT_STRONG, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
