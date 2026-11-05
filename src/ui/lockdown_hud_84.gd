## @file lockdown_hud_84.gd
## La cifra grande de la cuenta atrás de las rejas (heist.md R7b, #120): «REJAS 0:30» arriba en
## el centro, bajo la cabecera, y un golpe de campana cada 0,5 s (cada 0,25 s en los últimos
## segundos, cuando además late en rojo). Solo lee HeistLockdown; no es un ruido de juego, así
## que no pasa por NoiseEmit ni SignalBus.
class_name LockdownHud84
extends Control

const RULES: HeistRules = preload("res://data/balance/heist_rules.tres")
const TOP_OFFSET: float = 120.0
const FONT_SIZE: int = 64
const WARN_COLOR: Color = Color("ff4a3d")
const BELL_DB: float = -14.0
const BELL_EVERY: float = 0.5
const BELL_EVERY_WARN: float = 0.25
const PULSE_HZ: float = 2.0

var _label: Label = null
var _player: AudioStreamPlayer = null
var _bell_in: float = 0.0
var _clock: float = 0.0


## El texto de la cifra para unos segundos restantes (redondeados hacia arriba)
static func text_for(seconds: float) -> String:
	var whole: int = maxi(0, ceili(seconds))
	return "REJAS %d:%02d" % [whole / 60, whole % 60]


## La cifra con las rejas ya cerradas: cuántas salidas quedan abiertas
static func closed_text(open: int) -> String:
	return "REJAS CERRADAS · %d %s" % [open, "SALIDA ABIERTA" if open == 1 else "SALIDAS ABIERTAS"]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)  # a lo ancho, centrada
	_label.offset_top = TOP_OFFSET
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_override("font", MenuTheme84.FONT_DISPLAY)
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", MenuTheme84.AMBER)
	add_child(_label)
	_player = AudioStreamPlayer.new()
	_player.bus = &"SFX"
	_player.volume_db = BELL_DB
	_player.stream = AlarmBellSounds.bell()
	add_child(_player)
	visible = false


func _process(delta: float) -> void:
	var lockdown: HeistLockdown = HeistLockdown.of(get_tree())
	var active: bool = (
		lockdown != null and lockdown.shown_time() >= 0.0 and not GameManager.is_match_over()
	)
	visible = active
	if not active:
		_bell_in = 0.0
		return
	_clock += delta
	if lockdown.closed:
		_label.text = closed_text(lockdown.open_count())
		_set_look(WARN_COLOR, 1.0)
	var shown: float = lockdown.shown_time()
	var warn: bool = not lockdown.closed and shown <= RULES.lockdown_warn_at
	if not lockdown.closed:
		_label.text = text_for(shown)
	if lockdown.closed:
		pass
	elif warn:
		var wave: float = 0.5 + 0.5 * sin(_clock * TAU * PULSE_HZ)
		_set_look(WARN_COLOR, 1.0 + 0.1 * wave, 0.6 + 0.4 * wave)
	else:
		_set_look(MenuTheme84.AMBER, 1.0)
	_bell_in -= delta
	if _bell_in <= 0.0:
		_player.play()
		_bell_in = BELL_EVERY_WARN if warn else BELL_EVERY


func _set_look(color: Color, scale_factor: float, alpha: float = 1.0) -> void:
	_label.add_theme_color_override("font_color", color)
	_label.modulate.a = alpha
	_label.pivot_offset = _label.size * 0.5
	_label.scale = Vector2.ONE * scale_factor
