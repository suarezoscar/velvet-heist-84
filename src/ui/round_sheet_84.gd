## @file round_sheet_84.gd
## Tablilla de ronda del HUD de los guardias (interaction.md R6; FEAT-034): la ruta del
## guardia local con el reloj que le toca marcado, su sala y los segundos del tramo (ámbar a
## warning_time, rojo si llega tarde) y las faltas del equipo con sus avisos. Al pasar a ámbar
## suena un pitido de reloj de pulsera (solo UI).
class_name RoundSheet84
extends PanelContainer

const RULES: TimeClockRules = preload("res://data/balance/time_clock_rules.tres")
const HUD_PALETTE: HudPalette = preload("res://assets/ui/hud_palette.tres")
const COLOR_NORMAL: Color = Color("b8e6c1")
const BEEP_HZ: float = 2400.0
const BEEP_SECONDS: float = 0.07
const BEEP_RATE: int = 22050
## Borde superior normal, a la derecha bajo la barra superior
const TOP: float = 65.0

var _rows: VBoxContainer = null
var _faults_label: Label = null
var _warning_label: Label = null
var _labels: Dictionary = {}
var _amber: Dictionary = {}
var _beep: AudioStreamPlayer = null


func _ready() -> void:
	name = "RoundSheet"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -330.0
	offset_right = -20.0
	offset_top = TOP
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	add_child(box)
	box.add_child(_make_label("HOJA DE RONDA", COLOR_NORMAL))
	_rows = VBoxContainer.new()
	box.add_child(_rows)
	_faults_label = _make_label("", COLOR_NORMAL)
	box.add_child(_faults_label)
	_warning_label = _make_label("", HUD_PALETTE.color_meter_high)
	_warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_warning_label.custom_minimum_size = Vector2(190.0, 0.0)
	box.add_child(_warning_label)
	_beep = AudioStreamPlayer.new()
	_beep.bus = &"SFX"
	_beep.stream = _make_beep()
	_beep.volume_db = -14.0
	add_child(_beep)


func _process(_delta: float) -> void:
	if visible:
		refresh(get_tree().get_nodes_in_group(&"guard_round"))


## Redibuja la tablilla: la ruta del guardia local, su siguiente reloj y las faltas del equipo
func refresh(rounds: Array) -> void:
	var mine: GuardRound = _local_round(rounds)
	_update_route(mine)
	var faults: int = RoundRules.team_faults(rounds)
	var allowed: int = RoundRules.allowed_faults(rounds, RULES.allowed_misses)
	_faults_label.text = "FALTAS DEL EQUIPO %d / %d" % [faults, allowed]
	_faults_label.modulate = _faults_color(faults, allowed)
	if faults > allowed:
		_warning_label.text = "Ronda rota: solo vale capturarlo"
	elif faults == allowed:
		_warning_label.text = "Una falta más y la central no os cubre"
	else:
		_warning_label.text = ""
	_warning_label.visible = not _warning_label.text.is_empty()


## Texto de la fila de la ruta (0) o del siguiente reloj (1) (lo usan los tests)
func row_text(row: int) -> String:
	var label: Label = _labels.get(row) as Label
	return label.text if label != null else ""


func _local_round(rounds: Array) -> GuardRound:
	for node: Node in rounds:
		var round_node: GuardRound = node as GuardRound
		if (
			round_node != null
			and round_node.guard != null
			and round_node.guard.is_locally_controlled
		):
			return round_node
	return null


func _update_route(mine: GuardRound) -> void:
	for row: int in [0, 1]:
		if not _labels.has(row):
			_labels[row] = _make_label("", COLOR_NORMAL)
			_rows.add_child(_labels[row])
	var route_label: Label = _labels[0]
	var next_label: Label = _labels[1]
	if mine == null or mine.route.is_empty():
		route_label.text = "Esperando la ronda de la central"
		next_label.text = ""
		return
	var marks: PackedStringArray = []
	for index: int in range(mine.route.size()):
		var text: String = "R%d" % mine.route[index]
		marks.append("[%s]" % text if index == mine.index else text)
	route_label.text = "RUTA  " + " › ".join(marks)
	var amber: bool = not mine.late and mine.time_left <= RULES.warning_time
	if amber and not bool(_amber.get(0, false)) and is_visible_in_tree():
		_beep.play()
	_amber[0] = amber
	var where: String = _clock_room(mine.next_clock())
	if mine.late:
		next_label.text = "R%d %s  ¡TARDE!" % [mine.next_clock(), where]
		next_label.modulate = HUD_PALETTE.color_meter_high
	else:
		next_label.text = "R%d %s  %d s" % [mine.next_clock(), where, int(ceil(mine.time_left))]
		next_label.modulate = HUD_PALETTE.color_meter_mid if amber else COLOR_NORMAL


func _clock_room(clock_id: int) -> String:
	for node: Node in get_tree().get_nodes_in_group(&"time_clock"):
		var clock: TimeClock3D = node as TimeClock3D
		if clock.clock_id == clock_id:
			return "· " + clock.room_name
	return ""


func _faults_color(faults: int, allowed: int) -> Color:
	if faults > allowed:
		return HUD_PALETTE.color_meter_high
	if faults == allowed:
		return HUD_PALETTE.color_meter_mid
	return COLOR_NORMAL


func _make_label(text: String, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.modulate = color
	label.add_theme_font_size_override("font_size", 15)
	return label


## Pitido corto generado en código (prototipo hasta tener un sonido de verdad)
func _make_beep() -> AudioStreamWAV:
	var frames: int = int(BEEP_SECONDS * BEEP_RATE)
	var data: PackedByteArray = PackedByteArray()
	data.resize(frames * 2)
	for i: int in range(frames):
		var envelope: float = 1.0 - float(i) / float(frames)
		var sample: float = sin(TAU * BEEP_HZ * float(i) / BEEP_RATE) * envelope * 0.6
		data.encode_s16(i * 2, int(sample * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = BEEP_RATE
	stream.data = data
	return stream
