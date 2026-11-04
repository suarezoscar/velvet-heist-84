## @file steal_minigame_84.gd
## Panel del minijuego de robo del ladrón local (heist.md R9b y R9c, #119), como el del dial:
## - «Dar el cambiazo»: la esfera de la báscula con su franja verde y la aguja, y la barra del
##   progreso; en pausa (E suelta) lo dice.
## - «Puentear el sensor»: el piloto (rojo encendido, apagado oscuro) y los aciertos.
## Destella en rojo y traquetea al fallar, y suena al acertar. Lo enlaza LocalViewPresenter;
## solo lee la pieza (TargetPiece3D.minigame_view), nunca la cambia.
class_name StealMinigame84
extends Control

const RULES: StealMinigameRules = preload("res://data/balance/steal_minigames.tres")
const PANEL_SIZE: Vector2 = Vector2(560.0, 0.0)
const GAUGE_SIZE: Vector2 = Vector2(480.0, 120.0)
const FLASH_TIME: float = 0.45
const OK_COLOR: Color = Color("4be38a")
const FAIL_COLOR: Color = Color("ff4a3d")
const PILOT_ON: Color = Color("ff3b2f")
const PILOT_OFF: Color = Color("2a1614")
const SFX_DB: float = -6.0

var piece: TargetPiece3D = null
var gauge: Gauge = null
var _title: Label = null
var _status: Label = null
var _hint: Label = null
var _frame: StyleBoxFlat = null
var _player: AudioStreamPlayer = null
var _last_fails: int = 0
var _last_hits: int = 0


## La esfera de la báscula (needle, franja verde y progreso) o el piloto del sensor
class Gauge:
	extends Control

	var kind: int = StealMinigame.Kind.SWAP
	var needle: float = 0.0
	var progress: float = 0.0
	var lit: bool = true
	var hits: int = 0

	func _draw() -> void:
		if kind == StealMinigame.Kind.SWAP:
			_draw_scale()
		else:
			_draw_pilot()

	func _draw_scale() -> void:
		var track: Rect2 = Rect2(Vector2(0.0, 18.0), Vector2(size.x, 44.0))
		draw_rect(track, Color("16181e"))
		var half: float = track.size.x * 0.5
		var green: float = RULES.needle_green_half * half
		var mid: float = track.position.x + half
		draw_rect(
			Rect2(Vector2(mid - green, track.position.y), Vector2(green * 2.0, track.size.y)),
			Color(OK_COLOR, 0.35)
		)
		draw_rect(track, Color("b9b4a8"), false, 3.0)
		var x: float = mid + clampf(needle, -1.0, 1.0) * half
		draw_line(
			Vector2(x, track.position.y - 12.0),
			Vector2(x, track.end.y + 12.0),
			MenuTheme84.AMBER,
			5.0
		)
		var bar: Rect2 = Rect2(Vector2(0.0, size.y - 26.0), Vector2(size.x, 18.0))
		draw_rect(bar, Color("16181e"))
		draw_rect(
			Rect2(bar.position, Vector2(bar.size.x * progress, bar.size.y)), MenuTheme84.NEON_CYAN
		)
		draw_rect(bar, Color(MenuTheme84.TEXT, 0.4), false, 2.0)

	func _draw_pilot() -> void:
		var center: Vector2 = Vector2(size.x * 0.5, size.y * 0.42)
		var radius: float = size.y * 0.3
		draw_circle(center, radius + 6.0, Color("0c0d11"))
		draw_circle(center, radius, PILOT_ON if lit else PILOT_OFF)
		if lit:
			draw_circle(center, radius * 1.6, Color(PILOT_ON, 0.15))
		var y: float = size.y - 14.0
		for i: int in range(RULES.bridge_hits):
			var at: Vector2 = Vector2(size.x * 0.5 + (i - (RULES.bridge_hits - 1) * 0.5) * 34.0, y)
			draw_circle(at, 10.0, OK_COLOR if i < hits else Color(MenuTheme84.TEXT, 0.25))


func _ready() -> void:
	name = "StealMinigame"
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
	_title = _centered("", MenuTheme84.FONT_DISPLAY, 44, MenuTheme84.TEXT)
	box.add_child(_title)
	gauge = Gauge.new()
	gauge.custom_minimum_size = GAUGE_SIZE
	gauge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(gauge)
	_status = _centered("", MenuTheme84.FONT_STRONG, 24, MenuTheme84.NEON_CYAN)
	box.add_child(_status)
	_hint = _centered("", MenuTheme84.FONT_BODY, 22, MenuTheme84.DIM)
	box.add_child(_hint)


## Enseña el panel para esta pieza, o lo oculta con null
func bind(target: TargetPiece3D) -> void:
	if target == piece:
		return
	piece = target
	visible = piece != null
	var view: Dictionary = piece.minigame_view() if piece != null else {}
	_last_fails = int(view.get("fails", 0))
	_last_hits = int(view.get("hits", 0))
	_process(0.0)


func _process(_delta: float) -> void:
	if piece == null or not is_instance_valid(piece):
		return
	var view: Dictionary = piece.minigame_view()
	if view.is_empty():
		return
	var swap: bool = int(view["game"]) == StealMinigame.Kind.SWAP
	gauge.kind = int(view["game"])
	gauge.needle = float(view.get("needle", 0.0))
	gauge.progress = float(view.get("progress", 0.0))
	gauge.lit = bool(view.get("lit", true))
	gauge.hits = int(view.get("hits", 0))
	gauge.queue_redraw()
	_title.text = "DAR EL CAMBIAZO" if swap else "PUENTEAR EL SENSOR"
	_status.text = status_text(view)
	_hint.text = (
		"Mantén E     ← →  corregir la aguja     Esc  salir"
		if swap
		else "E  con el piloto apagado     Esc  salir"
	)
	var fails: int = int(view.get("fails", 0))
	if fails != _last_fails:
		_last_fails = fails
		_flash(FAIL_COLOR)
		_play(DialSounds.wrong())
	elif gauge.hits > _last_hits:
		_flash(OK_COLOR)
		_play(DialSounds.correct())
	_last_hits = gauge.hits


## Línea de estado del minijuego (la usan los tests)
static func status_text(view: Dictionary) -> String:
	if int(view.get("game", 0)) == StealMinigame.Kind.SWAP:
		if not bool(view.get("holding", false)):
			return "EN PAUSA: MANTÉN E"
		return "SUJETA LA AGUJA EN LO VERDE"
	return "ACIERTOS %d DE %d" % [int(view.get("hits", 0)), RULES.bridge_hits]


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
