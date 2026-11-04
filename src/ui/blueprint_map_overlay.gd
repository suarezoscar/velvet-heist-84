## @file blueprint_map_overlay.gd
## Plano cianotipo del museo (FEAT-034, #117), con [M] o [TAB]. Sale de los datos del nivel (el
## mapa los deja en su meta «level_data»): salas con su nombre, puertas, salidas y cámaras, la
## garita en ámbar con su café, tu punto («TÚ» y hacia dónde miras), una campana donde saltó
## cada alarma («hace 1:20») y una leyenda por bando (BlueprintMapIcons). Además:
## - el ladrón ve su encargo (rosa; ✔ las que lleva) y las rejillas de ventilación;
## - los guardias ven a sus compañeros («G2»), todas las candidatas con su protección
##   (✘ rastro descubierto, ✔ auténtica examinada) y las marcas del walkie.
## Solo lee el estado que ya tiene el cliente.
class_name BlueprintMapOverlay
extends Control

const ICONS := preload("res://src/ui/blueprint_map_icons.gd")
const COLOR_BG: Color = ICONS.COLOR_BG
const COLOR_GRID: Color = Color(0.08, 0.20, 0.32, 0.40)
const COLOR_ROOM: Color = Color(0.10, 0.22, 0.36, 0.55)
const COLOR_OUTSIDE: Color = Color(0.06, 0.12, 0.18, 0.55)
const COLOR_WALL: Color = Color(0.80, 0.92, 1.0, 0.90)
const COLOR_DOOR: Color = Color(0.20, 0.90, 0.60, 0.95)
const COLOR_TEXT: Color = ICONS.COLOR_TEXT
const COLOR_HEADER: Color = ICONS.COLOR_HEADER
const COLOR_FOUND: Color = ICONS.COLOR_ALARM
const COLOR_OK: Color = ICONS.COLOR_OK
const MARGIN: float = 16.0
const HEADER: float = 64.0
const FOOTER: float = 16.0
const ROOM_LABEL: int = 15

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
	ICONS.text(
		self, panel.position + Vector2(24.0, 34.0), "PLANO DEL MUSEO VELVET '84", 24, COLOR_HEADER
	)
	ICONS.text(
		self,
		panel.position + Vector2(24.0, 54.0),
		"DOCUMENTO DE SEGURIDAD // [M] / [TAB] PARA CERRAR",
		13,
		COLOR_TEXT
	)
	if data == null:
		ICONS.text(self, panel.get_center(), "Sin plano para este mapa", 18, COLOR_TEXT)
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
		_draw_pings()
		_draw_mates()
	_draw_alarms()
	_draw_player()
	ICONS.legend(self, panel, thief_view)


## Escala para que todo el nivel quepa en el panel, dejando a la derecha sitio a la leyenda
func _fit(panel: Rect2) -> void:
	var bounds: Rect2 = Rect2()
	var first: bool = true
	for room: Dictionary in data.section("rooms"):
		bounds = data.room_rect(room) if first else bounds.merge(data.room_rect(room))
		first = false
	var free: Vector2 = panel.size - Vector2(ICONS.LEGEND_WIDTH + 64.0, HEADER + FOOTER)
	_scale = minf(free.x / bounds.size.x, free.y / bounds.size.y)
	var size: Vector2 = bounds.size * _scale
	var left: float = panel.position.x + 24.0 + (free.x - size.x) * 0.5
	_area = Rect2(Vector2(left, panel.position.y + HEADER), size)
	_origin = _area.position - bounds.position * _scale


func _draw_rooms() -> void:
	for room: Dictionary in data.section("rooms"):
		var rect: Rect2 = data.room_rect(room)
		var ui: Rect2 = Rect2(_to_map(rect.position), rect.size * _scale)
		var outside: bool = bool(room.get("exterior", false))
		var post: bool = bool(room.get("guard_post", false))
		var fill: Color = COLOR_OUTSIDE if outside else COLOR_ROOM
		draw_rect(ui, Color(ICONS.COLOR_POST, 0.28) if post else fill, true)
		draw_rect(ui, ICONS.COLOR_POST if post else COLOR_WALL, false, 2.5 if post else 1.5)
		if post:  # rótulo arriba y la taza en medio: los puntos de los guardias no lo tapan
			ICONS.text(self, ui.position + Vector2(8.0, 26.0), "GARITA", 24, ICONS.COLOR_POST)
			ICONS.cup(self, ui.get_center() + Vector2(0.0, 12.0), ICONS.COLOR_POST)
			continue
		var label: String = String(room.get("name", room["id"])).to_upper()
		var width: float = MenuTheme84.FONT_STRONG.get_string_size(label, 0, -1, ROOM_LABEL).x
		if width > ui.size.x - 10.0:
			label = String(room["id"])
		ICONS.text(self, ui.position + Vector2(6.0, 18.0), label, ROOM_LABEL, COLOR_TEXT)


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
		draw_line(pos - along, pos + along, COLOR_BG, 7.0)
		var color: Color = COLOR_HEADER if door.has("leaf") else COLOR_DOOR
		draw_line(pos - along, pos + along, COLOR_OK if exit else color, 4.5)
		if exit:
			ICONS.text_centered(self, pos + Vector2(0.0, 22.0), "SALIDA", 14, COLOR_OK)


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
			var done: bool = heist.stolen.has(piece.piece_id)
			var pink: Color = TeamMarker3D.THIEF_COLOR
			ICONS.text(self, pos + Vector2(-6.0, 6.0), "✔" if done else "◆", 17, pink)
			ICONS.text(self, pos + Vector2(10.0, 5.0), piece.piece_name, 12, pink)
			continue
		var icon: String = ICONS.PROTECTION_ICONS.get(piece.protection, "◆")
		var color: Color = TeamMarker3D.GUARD_COLOR
		if piece.discovered:
			icon = "✘"
			color = COLOR_FOUND
		elif piece.inspected:
			color = COLOR_OK
		ICONS.text(self, pos + Vector2(-6.0, 6.0), icon, 16, color)


func _draw_pings() -> void:
	var alert: AlertDirector = AlertDirector.of(get_tree())
	if alert == null:
		return
	for ping: Dictionary in alert.pings:
		ICONS.ping(self, _world(ping["pos"]))


## Los demás guardias, con su número
func _draw_mates() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"guards"):
		var guard: GuardController3D = node as GuardController3D
		if guard == null or guard == player_pawn:
			continue
		ICONS.mate(self, _world(guard.global_position), "G%d" % guard.guard_id)


## Una campana por cada vez que saltó la alarma (los dos bandos)
func _draw_alarms() -> void:
	var alert: AlertDirector = AlertDirector.of(get_tree())
	if alert == null:
		return
	for mark: Dictionary in alert.alarm_marks:
		ICONS.alarm(self, _world(mark["pos"]), float(mark["t"]) - GameManager.match_timer)


func _draw_player() -> void:
	if player_pawn == null or not is_instance_valid(player_pawn):
		return
	var color: Color = (
		TeamMarker3D.THIEF_COLOR if player_pawn is ThiefController3D else TeamMarker3D.GUARD_COLOR
	)
	var forward: Vector3 = -player_pawn.global_transform.basis.z
	ICONS.you(self, _world(player_pawn.global_position), Vector2(forward.x, forward.z), color)


func _world(pos: Vector3) -> Vector2:
	return _to_map(Vector2(pos.x - data.offset.x, pos.z - data.offset.y))


func _to_map(design: Vector2) -> Vector2:
	return _origin + design * _scale
