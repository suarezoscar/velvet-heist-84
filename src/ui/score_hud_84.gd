## @file score_hud_84.gd
## Puntuación en vivo del jugador local (#123, heist.md R11): «PUNTOS 235» arriba a la derecha y,
## debajo, los avisos breves al puntuar («+25 VISTO») que suben y se desvanecen. Solo lee su
## LiveScore (privada de cada jugador); no es un ruido de juego.
class_name ScoreHud84
extends Control

const MARGIN: float = 24.0
const TOTAL_SIZE: int = 28
const NOTE_SIZE: int = 22
const NOTE_TIME: float = 1.6
const NOTE_RISE: float = 30.0
const NOTE_GAP: float = 26.0
const NOTE_TOP: float = 44.0
const GOOD_COLOR: Color = Color("6fd38a")
const BAD_COLOR: Color = Color("ff6b5e")

## Rol del jugador local (lo pone LocalViewPresenter)
var role: StringName = &"":
	set(value):
		if value == role:
			return
		role = value
		_last_id = _highest_id()
var total_label: Label = null

var _notes_box: Control = null
var _last_id: int = 0
var _live_count: int = 0


## Verde para un aviso que suma («+25 VISTO»), rojo para uno que resta
static func color_for(text: String) -> Color:
	return GOOD_COLOR if text.begins_with("+") else BAD_COLOR


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	total_label = _make_label("", TOTAL_SIZE, MenuTheme84.TEXT)
	add_child(total_label)
	_place(total_label, 0.0)
	_notes_box = Control.new()
	_notes_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_notes_box)
	visible = false


func _process(_delta: float) -> void:
	var live: LiveScore = null
	if role != &"" and not GameManager.is_match_over():
		live = LiveScore.of(get_tree(), role)
	visible = live != null
	if live == null:
		return
	total_label.text = "PUNTOS %d" % live.total
	for note: Array in live.notes:
		if int(note[0]) > _last_id:
			_last_id = int(note[0])
			_show_note(String(note[1]))


func _highest_id() -> int:
	var live: LiveScore = LiveScore.of(get_tree(), role) if is_inside_tree() else null
	var highest: int = 0
	if live != null:
		for note: Array in live.notes:
			highest = maxi(highest, int(note[0]))
	return highest


func _show_note(text: String) -> void:
	var label: Label = _make_label(text, NOTE_SIZE, color_for(text))
	_notes_box.add_child(label)
	_place(label, NOTE_TOP + NOTE_GAP * _live_count)
	_live_count += 1
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + NOTE_RISE, NOTE_TIME)
	tween.tween_property(label, "modulate:a", 0.0, NOTE_TIME)
	tween.chain().tween_callback(_free_note.bind(label))


func _free_note(label: Label) -> void:
	_live_count = maxi(_live_count - 1, 0)
	label.queue_free()


## Alinea la etiqueta a la esquina superior derecha, a una altura dada
func _place(label: Label, top: float) -> void:
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	label.offset_right = -MARGIN
	label.offset_top = MARGIN + top


func _make_label(text: String, size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_override("font", MenuTheme84.FONT_DISPLAY)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
