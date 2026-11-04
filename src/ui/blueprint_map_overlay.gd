## @file blueprint_map_overlay.gd
## Plano táctico del museo (FEAT-034, #117), con [M] o [TAB], estilo monitor de 1984. Sale de los
## datos del nivel (el mapa los deja en su meta «level_data»): la arquitectura la dibuja
## BlueprintMapRooms; los objetos interactivos, BlueprintMapProps; la leyenda por capas,
## BlueprintMapLegend. Aquí van tu puntero, los compañeros, las piezas, las cámaras con su
## abanico, las campanas de alarma («hace 1:20») y el walkie.
## Rueda: zoom hacia el cursor; botón central: mover; [1]-[4]: encender y apagar capas.
## Solo lee el estado que ya tiene el cliente.
class_name BlueprintMapOverlay
extends Control

const ICONS := preload("res://src/ui/blueprint_map_icons.gd")
const PROPS := preload("res://src/ui/blueprint_map_props.gd")
const ROOMS := preload("res://src/ui/blueprint_map_rooms.gd")
const LEGEND := preload("res://src/ui/blueprint_map_legend.gd")
const COLOR_BG: Color = ICONS.COLOR_BG
const MARGIN: float = 16.0
const HEADER: float = 76.0
const FOOTER: float = 16.0
const ZOOM_MAX: float = 4.0
const ZOOM_STEP: float = 1.2
const HINT: String = "[M]/[TAB] CERRAR · RUEDA: ZOOM · BOTÓN CENTRAL: MOVER · [1]-[4]: CAPAS"
## Objetos que solo salen en el plano del ladrón
const THIEF_ONLY: Array[StringName] = [&"copy", &"car", &"loot"]
## Capa de cada tipo de objeto
const PROP_LAYER: Dictionary = {
	&"power": &"power",
	&"switch": &"power",
	&"lamp": &"power",
	&"coffee": &"places",
	&"desk": &"places",
	&"copy": &"places",
	&"car": &"places",
	&"loot": &"places",
}

var data: LevelData = null
var player_pawn: Node3D = null
## 1 = todo el museo; hasta ZOOM_MAX
var zoom: float = 1.0
## Capas encendidas: {&"people", &"security", &"power", &"places": bool}
var layers: Dictionary = {&"people": true, &"security": true, &"power": true, &"places": true}
var _scale: float = 10.0
var _origin: Vector2 = Vector2.ZERO
var _area: Rect2 = Rect2()
var _bounds: Rect2 = Rect2()
## Punto del nivel (en metros de diseño) que queda en el centro del área
var _center: Vector2 = Vector2.INF
var _props: Array[Node3D] = []
var _lamps: Array[Lamp3D] = []
var _time: float = 0.0


func _ready() -> void:
	visible = false
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # siluetas reducidas, sin dientes
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_blueprint"):
		toggle_map()
		get_viewport().set_input_as_handled()
		return
	if not visible or data == null:
		return
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo:
		var index: int = key.keycode - KEY_1
		if index >= 0 and index < LEGEND.LAYERS.size():
			toggle_layer(LEGEND.LAYERS[index])
			get_viewport().set_input_as_handled()
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
	set_props(PROPS.collect(scene))
	zoom = 1.0
	_center = Vector2.INF  # se centra en el nivel al dibujar


## Objetos interactivos que se dibujan (y, de ellos, las lámparas para los cables y la luz)
func set_props(props: Array[Node3D]) -> void:
	_props = props
	_lamps.clear()
	for prop: Node3D in props:
		if prop is Lamp3D:
			_lamps.append(prop as Lamp3D)


func toggle_layer(layer: StringName) -> void:
	layers[layer] = not bool(layers.get(layer, true))


## Cambia el zoom dejando quieto el punto del plano que hay bajo screen_pos
func zoom_at(screen_pos: Vector2, new_zoom: float) -> void:
	var under: Vector2 = (screen_pos - _origin) / _scale
	zoom = clampf(new_zoom, 1.0, ZOOM_MAX)
	_center = under - (screen_pos - _area.get_center()) / (_base_scale() * zoom)


func _process(delta: float) -> void:
	if visible:
		_time += delta
		queue_redraw()


func _draw() -> void:
	var view: Vector2 = get_viewport_rect().size
	var panel: Rect2 = Rect2(MARGIN, MARGIN, view.x - MARGIN * 2.0, view.y - MARGIN * 2.0)
	draw_rect(Rect2(Vector2.ZERO, view), COLOR_BG)
	if data == null:
		ICONS.text(self, panel.get_center(), "Sin plano para este mapa", 22, ICONS.COLOR_TEXT)
		return
	_fit(panel)
	ROOMS.draw_grid(self, _to_map(_bounds.position), _to_map(_bounds.end), _scale * 2.0)
	var power: bool = layers[&"power"]
	ROOMS.draw(self, data, _to_map, _scale, ROOMS.light_levels(data, _lamps) if power else {})
	ROOMS.draw_doors(self, data, _to_map, _scale)
	var thief_view: bool = HeistDirector.local_is_thief(get_tree())
	_draw_props(thief_view)
	if layers[&"security"]:
		PROPS.draw_cameras(self, data, _to_map)
	if thief_view and layers[&"places"]:
		_draw_vents()
	_draw_pieces(thief_view)
	if not thief_view and layers[&"people"]:
		_draw_pings()
		_draw_mates()
	if power:
		PROPS.draw_wiring(self, _props, _lamps, get_local_mouse_position(), _world)
	if layers[&"security"]:
		_draw_alarms()
	if layers[&"people"]:
		_draw_player()
	ICONS.scanlines(self, _area)
	_mask_outside(view)
	_draw_header(panel)
	LEGEND.draw(self, panel, panel.position.y + HEADER, thief_view, layers)


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
	var half: Vector2 = _area.size * 0.5 / _scale  # sin salirse del nivel
	var lo: Vector2 = _bounds.position + half
	var hi: Vector2 = _bounds.end - half
	_center.x = _bounds.get_center().x if lo.x > hi.x else clampf(_center.x, lo.x, hi.x)
	_center.y = _bounds.get_center().y if lo.y > hi.y else clampf(_center.y, lo.y, hi.y)
	_origin = _area.get_center() - _center * _scale


func _base_scale() -> float:
	if _bounds.size.x <= 0.0 or _bounds.size.y <= 0.0:
		return 10.0
	return minf(_area.size.x / _bounds.size.x, _area.size.y / _bounds.size.y)


## Tapa lo que sobresale del área al hacer zoom (hasta los bordes de la pantalla)
func _mask_outside(view: Vector2) -> void:
	var a: Rect2 = _area
	draw_rect(Rect2(0.0, 0.0, view.x, a.position.y), COLOR_BG)
	draw_rect(Rect2(0.0, a.end.y, view.x, view.y - a.end.y), COLOR_BG)
	draw_rect(Rect2(0.0, a.position.y, a.position.x, a.size.y), COLOR_BG)
	draw_rect(Rect2(a.end.x, a.position.y, view.x - a.end.x, a.size.y), COLOR_BG)
	draw_rect(a, Color(ICONS.COLOR_TEXT, 0.5), false, 1.0)


## Cabecera de terminal: título y controles
func _draw_header(panel: Rect2) -> void:
	var box: Rect2 = Rect2(panel.position, Vector2(panel.size.x, HEADER - 14.0))
	ICONS.terminal_frame(self, box)
	var title: Vector2 = box.position + Vector2(18.0, 36.0)
	ICONS.text(self, title, "PLANO DEL MUSEO VELVET '84", 30, ICONS.COLOR_HEADER)
	var hint_at: Vector2 = Vector2(box.end.x - 18.0 - _hint_width(), box.position.y + 36.0)
	ICONS.mono(self, hint_at, HINT, 15, ICONS.COLOR_TEXT)


func _hint_width() -> float:
	return MenuTheme84.FONT_MONO.get_string_size(HINT, 0, -1, 15).x


func _draw_props(thief_view: bool) -> void:
	for prop: Node3D in _props:
		var kind: StringName = PROPS.kind_of(prop)
		if not PROPS.shown(prop) or not layers[PROP_LAYER.get(kind, &"places")]:
			continue
		if thief_view or not THIEF_ONLY.has(kind):
			PROPS.icon(self, kind, _world(prop.global_position), prop)


func _draw_vents() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"vents"):
		var vent: Vent3D = node as Vent3D
		ICONS.vent(self, _world(vent.global_position), vent.network.substr(0, 1).to_upper())


## El encargo del ladrón (capa de personas) o las candidatas de los guardias (seguridad)
func _draw_pieces(thief_view: bool) -> void:
	if not layers[&"people" if thief_view else &"security"]:
		return
	var heist: HeistDirector = GameManager.heist
	for node: Node in get_tree().get_nodes_in_group(&"heist_targets"):
		var piece: TargetPiece3D = node as TargetPiece3D
		var pos: Vector2 = _world(piece.global_position)
		if thief_view:
			if heist == null or not heist.is_in_contract(piece.piece_id):
				continue
			var pink: Color = TeamMarker3D.THIEF_COLOR
			ICONS.glow(self, pos, pink, 20.0, 0.5)
			ICONS.piece(self, pos, &"cut_diamond", pink)
			if heist.stolen.has(piece.piece_id):
				ICONS.glyph(self, pos + Vector2(9.0, -9.0), "✔", 18, ICONS.COLOR_OK)
			ICONS.text(self, pos + Vector2(15.0, 7.0), piece.piece_name, 17, pink)
			continue
		var icon: StringName = ICONS.PROTECTION_SPRITES.get(piece.protection, &"cut_diamond")
		var color: Color = TeamMarker3D.GUARD_COLOR
		if piece.discovered:
			icon = &"cross_mark"
			color = ICONS.COLOR_ALARM
		elif piece.inspected:
			color = ICONS.COLOR_OK
		ICONS.piece(self, pos, icon, color)


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
	if alert == null:
		return
	var pulse: float = fmod(_time, 1.6) / 1.6
	for mark: Dictionary in alert.alarm_marks:
		var ago: float = float(mark["t"]) - GameManager.match_timer
		ICONS.alarm(self, _world(mark["pos"]), ago, pulse)


func _draw_player() -> void:
	if player_pawn == null or not is_instance_valid(player_pawn):
		return
	var forward: Vector3 = -player_pawn.global_transform.basis.z
	var pulse: float = fmod(_time, 1.2) / 1.2
	ICONS.you(self, _world(player_pawn.global_position), Vector2(forward.x, forward.z), pulse)


func _world(pos: Vector3) -> Vector2:
	return _to_map(Vector2(pos.x - data.offset.x, pos.z - data.offset.y))


func _to_map(design: Vector2) -> Vector2:
	return _origin + design * _scale
