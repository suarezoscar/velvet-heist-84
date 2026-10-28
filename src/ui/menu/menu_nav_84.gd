## @file menu_nav_84.gd
## Lista de entradas del menú principal: texto grande que se enciende en rosa y se desplaza al
## pasar el ratón o el foco, con una barra de neón a la izquierda, una línea de ayuda debajo
## y un clic de interruptor. Se navega con ratón, teclado o mando.
class_name MenuNav84
extends VBoxContainer

## Se emite al elegir una entrada, con su id
signal entry_chosen(id: StringName)

const ENTRY_FONT_SIZE: int = 46
const HOVER_SHIFT: float = 22.0
const HOVER_TIME: float = 0.14
const BAR_SIZE: Vector2 = Vector2(6.0, 34.0)
const HOVER_SOUND: AudioStream = preload("res://assets/audio/sfx/mechanism/switch_002.ogg")
const PRESS_SOUND: AudioStream = preload("res://assets/audio/sfx/mechanism/switch_004.ogg")

var buttons: Dictionary = {}
var _hint: Label = null
var _hints: Dictionary = {}
var _bars: Dictionary = {}
var _player: AudioStreamPlayer = null


func _ready() -> void:
	add_theme_constant_override("separation", 4)
	_player = AudioStreamPlayer.new()
	_player.bus = &"SFX"
	_player.volume_db = -14.0
	add_child(_player)


## Añade una entrada; hint es la línea de ayuda que aparece al enfocarla
func add_entry(id: StringName, text: String, hint: String) -> Button:
	var row: Control = Control.new()
	row.custom_minimum_size = Vector2(560.0, 64.0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar: ColorRect = ColorRect.new()
	bar.color = MenuTheme84.NEON_PINK
	bar.size = BAR_SIZE
	bar.position = Vector2(0.0, (64.0 - BAR_SIZE.y) * 0.5)
	bar.modulate.a = 0.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar)
	var button: Button = Button.new()
	button.name = "Entry_%s" % id
	button.text = text
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_override("font", MenuTheme84.FONT_DISPLAY)
	button.add_theme_font_size_override("font_size", ENTRY_FONT_SIZE)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.position = Vector2(0.0, 0.0)
	button.size = Vector2(560.0, 64.0)
	button.mouse_entered.connect(button.grab_focus)
	button.focus_entered.connect(_on_focus.bind(id, true))
	button.focus_exited.connect(_on_focus.bind(id, false))
	button.pressed.connect(_on_pressed.bind(id))
	row.add_child(button)
	add_child(row)
	buttons[id] = button
	_bars[id] = bar
	_hints[id] = hint
	return button


## Línea de ayuda que enseña la descripción de la entrada enfocada
func set_hint_label(label: Label) -> void:
	_hint = label


## Pone el foco en la primera entrada (teclado y mando)
func focus_first() -> void:
	if not buttons.is_empty():
		(buttons.values()[0] as Button).grab_focus()


func _on_focus(id: StringName, focused: bool) -> void:
	var button: Button = buttons[id]
	var bar: ColorRect = _bars[id]
	var tween: Tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "position:x", HOVER_SHIFT if focused else 0.0, HOVER_TIME)
	tween.tween_property(bar, "modulate:a", 1.0 if focused else 0.0, HOVER_TIME)
	if focused:
		if _hint != null:
			_hint.text = _hints.get(id, "")
		_play(HOVER_SOUND)


func _on_pressed(id: StringName) -> void:
	_play(PRESS_SOUND)
	entry_chosen.emit(id)


func _play(stream: AudioStream) -> void:
	if _player != null and is_inside_tree():
		_player.stream = stream
		_player.play()
