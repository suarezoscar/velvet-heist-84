## @file round_sheet_84.gd
## Tablilla de ronda del HUD de los guardias (interaction.md R6): cada reloj con sus
## segundos, ámbar a warning_time, rojo vencido, y el contador de faltas con sus avisos.
## Al entrar un reloj en ámbar suena un pitido de reloj de pulsera (solo UI).
class_name RoundSheet84
extends PanelContainer

const RULES: TimeClockRules = preload("res://data/balance/time_clock_rules.tres")
const HUD_PALETTE: HudPalette = preload("res://assets/ui/hud_palette.tres")
const COLOR_NORMAL: Color = Color("b8e6c1")
const BEEP_HZ: float = 2400.0
const BEEP_SECONDS: float = 0.07
const BEEP_RATE: int = 22050

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
	offset_left = -230.0
	offset_right = -20.0
	offset_top = 65.0
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
	_beep.stream = _make_beep()
	_beep.volume_db = -14.0
	add_child(_beep)


func _process(_delta: float) -> void:
	if visible:
		refresh(get_tree().get_nodes_in_group(&"time_clock"))


## Redibuja la tablilla con los relojes dados (ordenados por id)
func refresh(clocks: Array) -> void:
	var sorted: Array[TimeClock3D] = []
	for node: Node in clocks:
		if node is TimeClock3D:
			sorted.append(node as TimeClock3D)
	sorted.sort_custom(func(a: TimeClock3D, b: TimeClock3D) -> bool: return a.clock_id < b.clock_id)
	for clock: TimeClock3D in sorted:
		_update_row(clock)
	var faults: int = RoundRules.team_faults(sorted)
	_faults_label.text = "FALTAS %d / %d" % [faults, RULES.allowed_misses]
	_faults_label.modulate = _faults_color(faults)
	if faults > RULES.allowed_misses:
		_warning_label.text = "Ronda rota: solo vale capturarlo"
	elif faults == RULES.allowed_misses:
		_warning_label.text = "Una falta más y la central no os cubre"
	else:
		_warning_label.text = ""
	_warning_label.visible = not _warning_label.text.is_empty()


## Texto de la fila de un reloj (lo usan los tests)
func row_text(clock_id: int) -> String:
	var label: Label = _labels.get(clock_id) as Label
	return label.text if label != null else ""


func _update_row(clock: TimeClock3D) -> void:
	var label: Label = _labels.get(clock.clock_id) as Label
	if label == null:
		label = _make_label("", COLOR_NORMAL)
		_rows.add_child(label)
		_labels[clock.clock_id] = label
	var amber: bool = not clock.is_expired and clock.time_left <= RULES.warning_time
	if amber and not bool(_amber.get(clock.clock_id, false)) and is_visible_in_tree():
		_beep.play()
	_amber[clock.clock_id] = amber
	if clock.is_expired:
		label.text = "R%d  VENCIDO" % clock.clock_id
		label.modulate = HUD_PALETTE.color_meter_high
	else:
		label.text = "R%d  %3d s" % [clock.clock_id, int(ceil(clock.time_left))]
		label.modulate = HUD_PALETTE.color_meter_mid if amber else COLOR_NORMAL


func _faults_color(faults: int) -> Color:
	if faults > RULES.allowed_misses:
		return HUD_PALETTE.color_meter_high
	if faults == RULES.allowed_misses:
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
