## @file vent_panel_84.gd
## El plano de los conductos (#167, heist.md R10). Con el ladrón local ante una rejilla
## (VentTravel en CHOOSING) enseña dónde está y las salidas con sus segundos; la elegida va en
## ámbar con «▶». Pasar el ratón no cambia nada; un clic en una salida la elige y entra
## (VentInput.pick). Durante el viaje deja solo una etiqueta con los segundos que faltan.
class_name VentPanel84
extends Control

const SIZE_RATIO: float = 0.6
const TRAVEL_TOP: float = 96.0

## Mapa cuyo jugador local decide si se ve (lo pone el HUD con bind)
var map: HeistMap3D = null
var rows: VBoxContainer = null
var travel_label: Label = null
var _panel: PanelContainer = null
var _from: Label = null
var _view: Dictionary = {}


func _ready() -> void:
	name = "VentPanel"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.visible = false
	var frame: StyleBoxFlat = MenuTheme84.box(
		Color(MenuTheme84.INK, 0.9), Color(MenuTheme84.AMBER, 0.7), 2
	)
	frame.set_content_margin_all(24)
	_panel.add_theme_stylebox_override("panel", frame)
	center.add_child(_panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	_panel.add_child(box)
	box.add_child(_centered("CONDUCTO DE VENTILACIÓN", MenuTheme84.FONT_DISPLAY, 44))
	_from = _centered("", MenuTheme84.FONT_STRONG, 26, MenuTheme84.NEON_CYAN)
	box.add_child(_from)
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(rows)
	var hint: Label = _centered(
		"← → elegir · E entrar · Esc salir", MenuTheme84.FONT_BODY, 22, MenuTheme84.DIM
	)
	box.add_child(hint)
	travel_label = _centered("", MenuTheme84.FONT_STRONG, 24, MenuTheme84.AMBER)
	travel_label.visible = false
	travel_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	travel_label.position.y = TRAVEL_TOP
	add_child(travel_label)
	get_viewport().size_changed.connect(_fit)
	_fit()


func _process(_delta: float) -> void:
	refresh()


func bind(target: HeistMap3D) -> void:
	map = target


## Relee el estado de VentTravel y pone o quita el plano grande y la etiqueta del viaje
func refresh() -> void:
	var travel: VentTravel = VentTravel.of(get_tree())
	var mine: bool = travel != null and not GameManager.is_match_over() and _is_thief()
	var choosing: bool = mine and travel.phase == VentTravel.Phase.CHOOSING
	var traveling: bool = mine and travel.phase == VentTravel.Phase.TRAVELING
	visible = choosing or traveling
	_panel.visible = choosing
	travel_label.visible = traveling
	if traveling:
		travel_label.text = "Por el conducto… %d s" % ceili(travel.left)
	if choosing:
		_show(travel.view())


func _show(view: Dictionary) -> void:
	if view == _view:
		return
	_view = view
	_from.text = "ESTÁS AQUÍ: %s" % view.get("from", "")
	for row: Node in rows.get_children():
		rows.remove_child(row)
		row.queue_free()
	var options: Array = view.get("options", [])
	var sel: int = int(view.get("sel", 0))
	for i: int in range(options.size()):
		rows.add_child(_row(i, options[i], sel))


func _row(index: int, option: Array, sel: int) -> Label:
	var on: bool = index == sel
	var label: Label = MenuTheme84.label(
		"%s%s · %d s" % ["▶ " if on else "   ", option[0], int(option[1])],
		MenuTheme84.FONT_STRONG,
		30,
		MenuTheme84.AMBER if on else MenuTheme84.TEXT
	)
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	label.gui_input.connect(_on_row_input.bind(index))
	return label


func _on_row_input(event: InputEvent, index: int) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var options: Array = _view.get("options", [])
	VentInput.pick(index, int(_view.get("sel", 0)), options.size())
	accept_event()


func _is_thief() -> bool:
	return LiveScore.local_role(map) == &"thief"


func _fit() -> void:
	if _panel != null:
		_panel.custom_minimum_size = get_viewport_rect().size * SIZE_RATIO


func _centered(text: String, font: Font, font_size: int, color: Color = MenuTheme84.TEXT) -> Label:
	var label: Label = MenuTheme84.label(text, font, font_size, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label
