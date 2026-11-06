## @file match_countdown_84.gd
## Lo que se ve del arranque (#165, MatchCountdown): con red, «CARGANDO EL MUSEO…» con la
## lista de jugadores y un ✔ al que ya ha cargado; después el 3-2-1 en grande y «¡YA!».
class_name MatchCountdown84
extends Control

const NUMBER_SIZE: int = 160
const GO_TIME: float = 0.8
const SHADE: Color = Color(0.0, 0.0, 0.0, 0.7)

var title_label: Label = null
var list_label: Label = null
var number_label: Label = null
var _shade: ColorRect = null
var _go_left: float = 0.0
var _was_counting: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade = ColorRect.new()
	_shade.color = SHADE
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_shade)
	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(box)
	title_label = _label(48, MenuTheme84.TEXT)
	list_label = _label(26, MenuTheme84.DIM)
	number_label = _label(NUMBER_SIZE, MenuTheme84.AMBER)
	for label: Label in [title_label, list_label, number_label]:
		box.add_child(label)
	visible = false


func _process(delta: float) -> void:
	refresh(delta)


## Relee MatchCountdown (público para los tests)
func refresh(delta: float = 0.0) -> void:
	var countdown: MatchCountdown = MatchCountdown.of(get_tree())
	var phase: int = countdown.phase if countdown != null else MatchCountdown.Phase.GO
	if phase == MatchCountdown.Phase.COUNTING:
		_was_counting = true
	elif phase == MatchCountdown.Phase.GO and _was_counting:
		_was_counting = false
		_go_left = GO_TIME
	_go_left = maxf(0.0, _go_left - delta)
	var loading: bool = phase == MatchCountdown.Phase.WAITING and NetManager.is_online()
	var counting: bool = phase == MatchCountdown.Phase.COUNTING
	visible = loading or counting or _go_left > 0.0
	_shade.visible = loading
	title_label.visible = loading
	list_label.visible = loading
	number_label.visible = not loading
	if loading:
		title_label.text = "CARGANDO EL MUSEO…"
		list_label.text = _players(countdown.loaded)
	elif counting:
		number_label.text = str(maxi(1, ceili(countdown.left)))
	else:
		number_label.text = "¡YA!"


static func _players(loaded: Array[int]) -> String:
	var lines: PackedStringArray = []
	var players: Dictionary = NetManager.get_connected_players()
	for peer: int in players:
		var info: Dictionary = players[peer]
		var mark: String = "✔" if loaded.has(peer) else "…"
		lines.append("%s  %s" % [String(info.get("name", "Jugador %d" % peer)), mark])
	return "\n".join(lines)


func _label(size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", MenuTheme84.FONT_DISPLAY)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
