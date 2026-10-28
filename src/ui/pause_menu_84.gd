## @file pause_menu_84.gd
## Menú de pausa de la partida (FEAT-026): Esc lo abre y lo cierra. «Continuar», «Controles»
## (el mismo panel del menú principal) y «Menú principal», que pide una segunda pulsación para
## confirmar. Sin red pausa el juego; con red la partida sigue y el personaje propio se queda
## quieto (LocalInput3D.blocked) mientras está abierto. No se abre con la partida terminada
## (allí manda MatchEndMenu84) ni con el dial de la caja fuerte abierto (allí Esc lo suelta).
class_name PauseMenu84
extends CanvasLayer

var panel: PanelContainer = null
var list_box: VBoxContainer = null
var controls: ControlsPanel = null
var continue_button: Button = null
var controls_button: Button = null
var menu_button: Button = null
var note_label: Label = null
var _map: HeistMap3D = null
var _confirming: bool = false


func setup(map: HeistMap3D) -> void:
	_map = map
	name = "PauseMenu"
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(MenuTheme84.INK, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.theme = MenuTheme84.build()
	add_child(center)
	panel = PanelContainer.new()
	var style: StyleBoxFlat = MenuTheme84.box(
		Color(MenuTheme84.INK, 0.92), Color(MenuTheme84.TEXT, 0.25), 2
	)
	style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var stack: VBoxContainer = VBoxContainer.new()
	panel.add_child(stack)
	list_box = VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 14)
	list_box.custom_minimum_size = Vector2(420.0, 0.0)
	stack.add_child(list_box)
	list_box.add_child(MenuTheme84.label("PAUSA", MenuTheme84.FONT_DISPLAY, 64, MenuTheme84.TEXT))
	note_label = MenuTheme84.label("", MenuTheme84.FONT_BODY, 20, MenuTheme84.DIM)
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list_box.add_child(note_label)
	continue_button = _button("CONTINUAR  [Esc]", close)
	controls_button = _button("CONTROLES", show_controls)
	menu_button = _button("MENÚ PRINCIPAL", _on_menu_pressed)
	controls = ControlsPanel.new()
	controls.visible = false
	controls.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	stack.add_child(controls)
	controls.back_requested.connect(show_list)
	map.add_child(self)


## Con red la partida puede acabar con la pausa abierta: se cierra sola para dejar paso al
## menú de fin de partida (si no, taparía sus botones y su Esc te sacaría al menú)
func _process(_delta: float) -> void:
	if visible and GameManager.is_match_over():
		close()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel", false) or not can_open():
		return
	get_viewport().set_input_as_handled()
	if not visible:
		open()
	elif controls.visible:
		show_list()
	else:
		close()


## Se puede usar con la partida en marcha y sin el dial de la caja fuerte abierto
func can_open() -> bool:
	if GameManager.is_match_over():
		return false
	var dial: Control = _map.hud.safe_dial if _map != null and _map.hud != null else null
	return dial == null or not dial.visible


func open() -> void:
	visible = true
	_confirming = false
	menu_button.text = "MENÚ PRINCIPAL"
	show_list()
	var online: bool = NetManager.is_online()
	note_label.text = (
		"La partida sigue en marcha: tu personaje se queda quieto mientras el menú esté abierto."
		if online
		else "Juego en pausa."
	)
	LocalInput3D.blocked = true
	if not online:
		get_tree().paused = true


func close() -> void:
	visible = false
	LocalInput3D.blocked = false
	get_tree().paused = false


func show_controls() -> void:
	list_box.visible = false
	controls.visible = true
	controls.refresh()


func show_list() -> void:
	controls.visible = false
	list_box.visible = true


func _on_menu_pressed() -> void:
	if not _confirming:
		_confirming = true
		menu_button.text = "¿SALIR DE LA PARTIDA? PULSA OTRA VEZ"
		return
	MenuReturn.to_main_menu(get_tree())


func _exit_tree() -> void:
	if visible:
		LocalInput3D.blocked = false


func _button(text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.pressed.connect(action)
	list_box.add_child(button)
	return button
