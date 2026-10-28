## @file safe_dial_84.gd
## Panel central del dial de la caja fuerte (FEAT-019): dial de 100 marcas que gira hasta el
## número actual, progreso de la combinación y controles. Destella en verde al acertar un
## número y en rojo al fallar. Lo enlaza LocalViewPresenter mientras el ladrón local gira el
## dial; solo lee la caja, nunca la cambia.
## Cada marca suena (DialSounds): tic lejos, clic que crece cerca, golpe sordo en el número
## exacto; acorde al acertar y traqueteo al fallar. La flecha se enciende igual: ámbar cerca,
## verde en el número.
class_name SafeDial84
extends Control

const PANEL_SIZE: Vector2 = Vector2(560.0, 640.0)
const DIAL_SIZE: Vector2 = Vector2(400.0, 400.0)
const FLASH_TIME: float = 0.45
const OK_COLOR: Color = Color("4be38a")
const FAIL_COLOR: Color = Color("ff4a3d")
const FAR_POINTER: Color = Color("6d6a62")
const SFX_DB: float = -6.0

var face: DialFace = null
var safe: SafeBox3D = null
var _stage_label: Label = null
var _pips: Label = null
var _frame: StyleBoxFlat = null
var _last_stage: int = 0
var _last_value: int = 0
var _last_fails: int = 0
var _player: AudioStreamPlayer = null


## Esfera del dial dibujada a mano; shown sigue a value por el camino corto
class DialFace:
	extends Control

	const RIM: Color = Color("b9b4a8")
	const FACE: Color = Color("16181e")
	const KNOB: Color = Color("0c0d11")

	var value: int = 0
	var shown: float = 0.0
	var pointer: Color = MenuTheme84.AMBER

	func _process(delta: float) -> void:
		var diff: float = wrapf(float(value) - shown, -50.0, 50.0)
		shown = wrapf(shown + diff * clampf(18.0 * delta, 0.0, 1.0), 0.0, 100.0)
		queue_redraw()

	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var radius: float = minf(size.x, size.y) * 0.5 - 18.0
		draw_circle(center, radius, FACE)
		draw_arc(center, radius, 0.0, TAU, 128, RIM, 7.0, true)
		draw_arc(center, radius - 9.0, 0.0, TAU, 128, Color(0.0, 0.0, 0.0, 0.6), 2.0, true)
		var font: Font = MenuTheme84.FONT_STRONG
		for i: int in range(100):
			var angle: float = (float(i) - shown) * TAU / 100.0 - PI * 0.5
			var dir: Vector2 = Vector2(cos(angle), sin(angle))
			var length: float = 22.0 if i % 10 == 0 else (14.0 if i % 5 == 0 else 7.0)
			var width: float = 3.0 if i % 10 == 0 else 1.5
			var start: Vector2 = center + dir * (radius - 14.0)
			draw_line(start, start - dir * length, Color(RIM, 0.9), width, true)
			if i % 10 == 0:
				var text: String = str(i)
				var text_size: Vector2 = font.get_string_size(
					text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22
				)
				var at: Vector2 = center + dir * (radius - 56.0)
				draw_string(font, at + Vector2(-text_size.x * 0.5, 8.0), text, 0, -1, 22, RIM)
		var tip: float = radius + 4.0
		draw_colored_polygon(
			PackedVector2Array(
				[
					center + Vector2(-13.0, -tip - 16.0),
					center + Vector2(13.0, -tip - 16.0),
					center + Vector2(0.0, -tip + 10.0),
				]
			),
			pointer
		)
		draw_circle(center, radius * 0.38, KNOB)
		draw_arc(center, radius * 0.38, 0.0, TAU, 96, Color(RIM, 0.5), 2.0, true)
		var number: String = "%02d" % value
		var display: Font = MenuTheme84.FONT_DISPLAY
		var number_size: Vector2 = display.get_string_size(
			number, HORIZONTAL_ALIGNMENT_LEFT, -1, 96
		)
		draw_string(
			display,
			center + Vector2(-number_size.x * 0.5, 34.0),
			number,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			96,
			MenuTheme84.TEXT
		)


func _ready() -> void:
	name = "SafeDial"
	visible = false
	_player = AudioStreamPlayer.new()
	_player.bus = &"SFX"
	_player.volume_db = SFX_DB
	_player.max_polyphony = 4
	add_child(_player)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title: Label = MenuTheme84.label(
		"CAJA FUERTE", MenuTheme84.FONT_DISPLAY, 52, MenuTheme84.TEXT
	)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	face = DialFace.new()
	face.custom_minimum_size = DIAL_SIZE
	face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(face)
	_stage_label = _centered("", MenuTheme84.FONT_STRONG, 26, MenuTheme84.NEON_CYAN)
	box.add_child(_stage_label)
	_pips = _centered("", MenuTheme84.FONT_BODY, 30, MenuTheme84.AMBER)
	box.add_child(_pips)
	box.add_child(
		_centered(
			"← →  girar     E  probar número     Esc  salir",
			MenuTheme84.FONT_BODY,
			22,
			MenuTheme84.DIM
		)
	)


func _process(_delta: float) -> void:
	if safe == null or not is_instance_valid(safe):
		return
	face.value = safe.current_dial_val
	var total: int = safe.combination.size()
	var stage: int = clampi(safe.current_stage, 0, total)
	_stage_label.text = "NÚMERO %d DE %d" % [mini(stage + 1, total), total]
	_pips.text = "  ".join(PackedStringArray(_pip_marks(stage, total)))
	var distance: int = safe.target_distance()
	face.pointer = pointer_color(distance)
	if safe.current_dial_val != _last_value:
		_last_value = safe.current_dial_val
		_play(DialSounds.for_distance(distance))
	if safe.fails != _last_fails:
		_last_fails = safe.fails
		_flash(FAIL_COLOR)
		_play(DialSounds.wrong())
	elif stage > _last_stage:
		_flash(OK_COLOR)
		_play(DialSounds.correct())
	_last_stage = stage


## Color de la flecha a distance pasos del número (lo usan los tests)
static func pointer_color(distance: int) -> Color:
	if distance == 0:
		return OK_COLOR
	if distance <= SafeBox3D.NEAR_STEPS:
		return MenuTheme84.AMBER
	return FAR_POINTER


## Enseña el panel para esta caja fuerte, o lo oculta con null
func bind(target: SafeBox3D) -> void:
	if target == safe:
		return
	safe = target
	visible = safe != null
	if safe != null:
		_last_stage = safe.current_stage
		_last_value = safe.current_dial_val
		_last_fails = safe.fails
		face.value = safe.current_dial_val
		face.shown = float(safe.current_dial_val)
		_process(0.0)


## Texto del progreso (lo usan los tests)
func stage_text() -> String:
	return _stage_label.text


func _pip_marks(stage: int, total: int) -> Array[String]:
	var marks: Array[String] = []
	for i: int in range(total):
		marks.append("●" if i < stage else "○")
	return marks


func _play(stream: AudioStream) -> void:
	if _player != null and visible:
		_player.stream = stream
		_player.play()


func _flash(color: Color) -> void:
	_frame.border_color = color
	var tween: Tween = create_tween()
	tween.tween_property(_frame, "border_color", Color(MenuTheme84.TEXT, 0.25), FLASH_TIME)


func _centered(text: String, font: Font, font_size: int, color: Color) -> Label:
	var node: Label = MenuTheme84.label(text, font, font_size, color)
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return node
