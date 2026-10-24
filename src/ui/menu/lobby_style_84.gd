## @file lobby_style_84.gd
## Maquetación y textos fijos del lobby multijugador con el estilo del menú principal: mismos
## márgenes, título grande, letra legible y textos claros. LobbyView la aplica en _ready.
class_name LobbyStyle84
extends RefCounted

const MARGIN: float = 120.0
const WIDTH: float = 1680.0
const COLUMNS_TOP: float = 250.0
const COLUMNS_HEIGHT: float = 540.0
const ACTIONS_TOP: float = 830.0
const HELP: String = (
	"El anfitrión arranca tools/net/run_server.sh y abre el puerto UDP 7777 en su router."
	+ " Los demás se unen con su IP pública."
)


static func apply(view: Control) -> void:
	_place(view.get_node("HeaderBox"), 80.0, 140.0)
	var title: Label = view.get_node("HeaderBox/LobbyTitleLabel")
	title.text = "MULTIJUGADOR"
	_font(title, MenuTheme84.FONT_DISPLAY, 80, MenuTheme84.TEXT)
	_font(view.get_node("HeaderBox/LobbyStatusLabel"), MenuTheme84.FONT_STRONG, 24, MenuTheme84.DIM)
	var columns: HBoxContainer = view.get_node("ColumnsHBox")
	columns.custom_minimum_size = Vector2(WIDTH, COLUMNS_HEIGHT)
	_place(columns, COLUMNS_TOP, COLUMNS_HEIGHT)
	columns.add_theme_constant_override("separation", 24)
	var widths: Dictionary = {"ConnectionPanel": 480.0, "RolesPanel": 560.0, "PlayersPanel": 592.0}
	for panel_name: String in widths:
		var panel: Control = columns.get_node(panel_name)
		panel.custom_minimum_size = Vector2(widths[panel_name], COLUMNS_HEIGHT)
	_section(view, "ColumnsHBox/ConnectionPanel/VBox/SectionTitle", "CONECTAR A UN SERVIDOR")
	_section(view, "ColumnsHBox/RolesPanel/VBox/RolesTitle", "ELIGE BANDO")
	_section(view, "ColumnsHBox/PlayersPanel/VBox/PlayersTitle", "JUGADORES")
	_small(view, "ColumnsHBox/ConnectionPanel/VBox/IpLabel", "Dirección IP")
	_small(view, "ColumnsHBox/ConnectionPanel/VBox/PortLabel", "Puerto")
	_small(
		view, "ColumnsHBox/RolesPanel/VBox/RolesSubtitle", "El ladrón contra el equipo de seguridad"
	)
	var help: Label = view.get_node("ColumnsHBox/ConnectionPanel/VBox/ConnectionLogLabel")
	help.text = HELP
	_font(help, MenuTheme84.FONT_BODY, 20, MenuTheme84.DIM)
	_font(
		view.get_node("ColumnsHBox/RolesPanel/VBox/CurrentRoleInfoLabel"),
		MenuTheme84.FONT_STRONG,
		22,
		MenuTheme84.TEXT
	)
	(view.get_node("ColumnsHBox/ConnectionPanel/VBox/JoinButton") as Button).text = "UNIRSE"
	var actions: HBoxContainer = view.get_node("BottomActionsHBox")
	actions.custom_minimum_size = Vector2(WIDTH, 56.0)
	_place(actions, ACTIONS_TOP, 56.0)
	var back: Button = actions.get_node("LobbyBackButton")
	back.text = "VOLVER"
	back.custom_minimum_size = Vector2(220.0, 56.0)
	var start: Button = actions.get_node("StartMatchButton")
	start.text = "EMPEZAR PARTIDA  ▶"
	start.modulate = Color.WHITE
	start.custom_minimum_size = Vector2(320.0, 56.0)
	for button: Button in [back, start]:
		button.add_theme_font_size_override("font_size", 26)


## Fija los cuatro bordes del nodo: la .tscn trae offsets propios que no deben mandar
static func _place(node: Control, top: float, height: float) -> void:
	node.set_anchors_preset(Control.PRESET_TOP_LEFT)
	node.offset_left = MARGIN
	node.offset_right = MARGIN + WIDTH
	node.offset_top = top
	node.offset_bottom = top + height


static func _section(view: Control, path: String, text: String) -> void:
	var node: Label = view.get_node(path)
	node.text = text
	_font(node, MenuTheme84.FONT_STRONG, 26, MenuTheme84.NEON_CYAN)


static func _small(view: Control, path: String, text: String) -> void:
	var node: Label = view.get_node(path)
	node.text = text
	_font(node, MenuTheme84.FONT_BODY, 20, MenuTheme84.DIM)


static func _font(node: Label, font: Font, size: int, color: Color) -> void:
	node.add_theme_font_override("font", font)
	node.add_theme_font_size_override("font_size", size)
	node.modulate = Color.WHITE
	node.add_theme_color_override("font_color", color)
