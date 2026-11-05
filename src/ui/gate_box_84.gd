## @file gate_box_84.gd
## Panel de sabotear la caja de la reja (heist.md R7c, #121), como el del robo:
## - Pasos 1 y 3: la tapa con sus tornillos (quitados o puestos marcados) y la barra del que se
##   está girando; en pausa (E suelta) lo dice.
## - Paso 2: las puntas de los cables arriba, los bornes abajo y los cables enredados entre
##   ambos; cada uno con su color y su dibujo (liso, rayado, punteado, doble) para no depender
##   del color. Los cortados quedan tenues y partidos; la punta elegida lleva un marco ámbar.
## Destella en rojo y traquetea al fallar, y suena al acertar. Solo lee GateBox3D.minigame_view.
class_name GateBox84
extends Control

const RULES: HeistRules = preload("res://data/balance/heist_rules.tres")
const PANEL_SIZE: Vector2 = Vector2(600.0, 0.0)
const DRAW_SIZE: Vector2 = Vector2(520.0, 240.0)
const FLASH_TIME: float = 0.45
const OK_COLOR: Color = Color("4be38a")
const FAIL_COLOR: Color = Color("ff4a3d")
const SFX_DB: float = -6.0
const WIRE_COLORS: Array[Color] = [
	Color("ff4a3d"), Color("4fc3ff"), Color("ffd23d"), Color("c7f25a")
]
const CURVE_POINTS: int = 28
const WIRE_WIDTH: float = 5.0

var board: Board = null
var _box: GateBox3D = null
var _title: Label = null
var _status: Label = null
var _warn: Label = null
var _hint: Label = null
var _frame: StyleBoxFlat = null
var _player: AudioStreamPlayer = null
var _last_fails: int = 0
var _last_cut: int = 0
var _last_screws: int = 0
var _last_step: int = 0


## La tapa con los tornillos o los cables, según el paso
class Board:
	extends Control

	var step: int = GateBox3D.Step.UNSCREW
	var screws: int = 0
	var screw: float = 0.0
	var terminals: Array[int] = []
	var cut: Array[int] = []
	var selected: int = 0

	func _draw() -> void:
		if step == GateBox3D.Step.CUT:
			_draw_wires()
		else:
			_draw_cover()

	func _draw_cover() -> void:
		var cover: Rect2 = Rect2(Vector2(20.0, 10.0), Vector2(size.x - 40.0, size.y - 60.0))
		draw_rect(cover, Color("2a2d36"))
		draw_rect(cover, Color("b9b4a8"), false, 3.0)
		var total: int = RULES.box_screws
		for i: int in range(total):
			var t: float = (i + 0.5) / float(total)
			var pos: Vector2 = (
				cover.get_center()
				+ Vector2(
					cos(t * TAU + 0.785) * cover.size.x * 0.38,
					sin(t * TAU + 0.785) * cover.size.y * 0.34
				)
			)
			var on: bool = i < screws if step == GateBox3D.Step.SCREW else i >= screws
			draw_circle(pos, 15.0, Color("0c0d11"))
			if on:
				draw_circle(pos, 12.0, Color("b9b4a8"))
				draw_line(pos + Vector2(-8.0, -3.0), pos + Vector2(8.0, 3.0), Color("3a3d46"), 3.0)
			else:
				draw_arc(pos, 15.0, 0.0, TAU, 20, OK_COLOR, 2.0)
		var bar: Rect2 = Rect2(Vector2(0.0, size.y - 26.0), Vector2(size.x, 18.0))
		draw_rect(bar, Color("16181e"))
		draw_rect(
			Rect2(bar.position, Vector2(bar.size.x * screw, bar.size.y)), MenuTheme84.NEON_CYAN
		)
		draw_rect(bar, Color(MenuTheme84.TEXT, 0.4), false, 2.0)

	func _draw_wires() -> void:
		var count: int = RULES.box_wires
		for i: int in range(count):
			var x: float = _slot(i, count)
			var tip: Rect2 = Rect2(Vector2(x - 16.0, 0.0), Vector2(32.0, 30.0))
			draw_rect(Rect2(tip.position.x, 8.0, 32.0, 22.0), Color("16181e"))
			if i == selected:
				draw_rect(tip.grow(4.0), MenuTheme84.AMBER, false, 3.0)
			_text(str(i + 1), Vector2(x - 5.0, 26.0), Color(MenuTheme84.TEXT))
			draw_rect(Rect2(x - 22.0, size.y - 30.0, 44.0, 26.0), Color("16181e"))
			draw_rect(Rect2(x - 22.0, size.y - 30.0, 44.0, 26.0), Color("b9b4a8"), false, 2.0)
			_text(str(i + 1), Vector2(x - 5.0, size.y - 10.0), Color(MenuTheme84.TEXT))
		for i: int in range(mini(count, terminals.size())):
			_draw_wire(i, count)

	func _draw_wire(i: int, count: int) -> void:
		var a: Vector2 = Vector2(_slot(i, count), 32.0)
		var b: Vector2 = Vector2(_slot(terminals[i], count), size.y - 32.0)
		var pts: PackedVector2Array = PackedVector2Array()
		for k: int in range(CURVE_POINTS + 1):
			var t: float = float(k) / CURVE_POINTS
			var s: float = t * t * (3.0 - 2.0 * t)
			var wobble: float = sin(t * PI * 2.0 + i * 1.7) * 26.0
			pts.append(Vector2(lerpf(a.x, b.x, s) + wobble, lerpf(a.y, b.y, t)))
		var color: Color = WIRE_COLORS[i % WIRE_COLORS.size()]
		if cut.has(i):
			var gap: int = CURVE_POINTS * 2 / 5
			var faded: Color = Color(color, 0.3)
			_stroke(pts.slice(0, gap), faded, i)
			_stroke(pts.slice(CURVE_POINTS - gap + 1), faded, i)
		else:
			_stroke(pts, color, i)

	func _stroke(pts: PackedVector2Array, color: Color, i: int) -> void:
		match i % 4:
			1:  # rayado: segmentos alternos de dos tonos
				for k: int in range(pts.size() - 1):
					var tone: Color = color if (k / 2) % 2 == 0 else color.darkened(0.55)
					draw_line(pts[k], pts[k + 1], tone, WIRE_WIDTH)
			2:  # punteado: tramos con huecos
				for k: int in range(0, pts.size() - 1, 2):
					draw_line(pts[k], pts[k + 1], color, WIRE_WIDTH)
			3:  # doble: dos líneas finas paralelas
				for off: float in [-3.5, 3.5]:
					var moved: PackedVector2Array = PackedVector2Array()
					for p: Vector2 in pts:
						moved.append(p + Vector2(off, 0.0))
					if moved.size() >= 2:
						draw_polyline(moved, color, 2.0)
			_:
				if pts.size() >= 2:
					draw_polyline(pts, color, WIRE_WIDTH)

	func _slot(index: int, count: int) -> float:
		return size.x * (index + 0.5) / float(count)

	func _text(text: String, at: Vector2, color: Color) -> void:
		draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, color)


func _ready() -> void:
	name = "GateBox"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_player = AudioStreamPlayer.new()
	_player.bus = &"SFX"
	_player.volume_db = SFX_DB
	_player.max_polyphony = 4
	add_child(_player)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = PANEL_SIZE
	_frame = MenuTheme84.box(Color(MenuTheme84.INK, 0.9), Color(MenuTheme84.TEXT, 0.25), 2)
	_frame.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", _frame)
	center.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	_title = _centered("SABOTEAR LA REJA", MenuTheme84.FONT_DISPLAY, 44, MenuTheme84.TEXT)
	box.add_child(_title)
	board = Board.new()
	board.custom_minimum_size = DRAW_SIZE
	board.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(board)
	_warn = _centered("", MenuTheme84.FONT_STRONG, 24, FAIL_COLOR)
	box.add_child(_warn)
	_status = _centered("", MenuTheme84.FONT_STRONG, 24, MenuTheme84.NEON_CYAN)
	box.add_child(_status)
	_hint = _centered("", MenuTheme84.FONT_BODY, 22, MenuTheme84.DIM)
	box.add_child(_hint)


## Enseña el panel para esta caja, o lo oculta con null
func bind(target: GateBox3D) -> void:
	if target == _box:
		return
	_box = target
	visible = _box != null
	var view: Dictionary = _box.minigame_view() if _box != null else {}
	_sync_counters(view)
	_process(0.0)


func _process(_delta: float) -> void:
	if _box == null or not is_instance_valid(_box):
		return
	var view: Dictionary = _box.minigame_view()
	if view.is_empty():
		return
	var step: int = int(view.get("step", GateBox3D.Step.UNSCREW))
	board.step = step
	board.screws = int(view.get("screws", 0))
	board.screw = float(view.get("screw", 0.0))
	board.terminals.assign(view.get("terminals", []))
	board.cut.assign(view.get("cut", []))
	board.selected = int(view.get("selected", 0))
	board.queue_redraw()
	_status.text = status_text(view)
	_warn.text = "EMPALMANDO…" if float(view.get("splice", 0.0)) > 0.0 else ""
	_hint.text = (
		"← →  elegir     E  cortar     Esc  salir"
		if step == GateBox3D.Step.CUT
		else "Mantén E     Esc  salir"
	)
	var fails: int = int(view.get("fails", 0))
	var cut_n: int = (view.get("cut", []) as Array).size()
	var screws: int = int(view.get("screws", 0))
	if step != _last_step:
		_last_step = step
		_last_screws = screws
	if fails != _last_fails:
		_flash(FAIL_COLOR)
		_play(DialSounds.wrong())
	elif cut_n > _last_cut or screws > _last_screws:
		_flash(OK_COLOR)
		_play(DialSounds.correct())
	_last_fails = fails
	_last_cut = cut_n
	_last_screws = screws


## Línea de estado según el paso (la usan los tests)
static func status_text(view: Dictionary) -> String:
	var step: int = int(view.get("step", GateBox3D.Step.UNSCREW))
	if step == GateBox3D.Step.CUT:
		return "CORTA LOS CABLES POR ORDEN DE BORNE"
	if not bool(view.get("holding", false)):
		return "EN PAUSA: MANTÉN E"
	return "CERRANDO LA TAPA…" if step == GateBox3D.Step.SCREW else "QUITANDO LA TAPA…"


func _sync_counters(view: Dictionary) -> void:
	_last_fails = int(view.get("fails", 0))
	_last_cut = (view.get("cut", []) as Array).size()
	_last_screws = int(view.get("screws", 0))
	_last_step = int(view.get("step", 0))


func _flash(color: Color) -> void:
	_frame.border_color = color
	var tween: Tween = create_tween()
	tween.tween_property(_frame, "border_color", Color(MenuTheme84.TEXT, 0.25), FLASH_TIME)


func _play(stream: AudioStream) -> void:
	if stream != null and _player.is_inside_tree():
		_player.stream = stream
		_player.play()


func _centered(text: String, font: Font, font_size: int, color: Color) -> Label:
	var label: Label = MenuTheme84.label(text, font, font_size, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label
