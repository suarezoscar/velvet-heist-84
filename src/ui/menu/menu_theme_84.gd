## @file menu_theme_84.gd
## Paleta, tipografías y tema del menú principal (neo-noir de 1984: neón rosa, ámbar y cian
## sobre negro azulado). Se aplica a la raíz del menú, así que también viste el lobby.
class_name MenuTheme84
extends RefCounted

const NEON_PINK: Color = Color("ff3d9a")
const NEON_CYAN: Color = Color("3de0e0")
const AMBER: Color = Color("f2b84b")
const TEXT: Color = Color("ece4d6")
const DIM: Color = Color("8a8f9c")
const INK: Color = Color("07080d")

const FONT_SCRIPT: FontFile = preload("res://assets/fonts/mrdafoe/MrDafoe-Regular.ttf")
const FONT_DISPLAY: FontFile = preload("res://assets/fonts/bebasneue/BebasNeue-Regular.ttf")
const FONT_BODY: FontFile = preload("res://assets/fonts/barlowcondensed/BarlowCondensed-Medium.ttf")
const FONT_STRONG: FontFile = preload(
	"res://assets/fonts/barlowcondensed/BarlowCondensed-SemiBold.ttf"
)
const FONT_MONO: FontFile = preload("res://assets/fonts/sharetechmono/ShareTechMono-Regular.ttf")


## Tema común: botones con borde fino que se encienden en rosa, paneles oscuros translúcidos
static func build() -> Theme:
	var theme: Theme = Theme.new()
	theme.default_font = FONT_BODY
	theme.default_font_size = 22
	theme.set_color("font_color", "Label", TEXT)
	_style_buttons(theme)
	_style_fields(theme)
	var panel: StyleBoxFlat = box(Color(INK, 0.82), Color(TEXT, 0.10), 1)
	panel.set_content_margin_all(28)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "Panel", panel)
	var line: StyleBoxLine = StyleBoxLine.new()
	line.color = Color(TEXT, 0.15)
	line.thickness = 1
	theme.set_stylebox("separator", "HSeparator", line)
	return theme


## Caja plana con fondo, borde y esquinas casi rectas
static func box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(2)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


## Etiqueta con fuente, tamaño y color dados
static func label(text: String, font: Font, size: int, color: Color) -> Label:
	var node: Label = Label.new()
	node.text = text
	node.add_theme_font_override("font", font)
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## Brillo de neón alrededor del texto (sombra sin desplazamiento y muy difuminada)
static func add_glow(node: Label, color: Color, size: int) -> void:
	node.add_theme_color_override("font_shadow_color", color)
	node.add_theme_constant_override("shadow_offset_x", 0)
	node.add_theme_constant_override("shadow_offset_y", 0)
	node.add_theme_constant_override("shadow_outline_size", size)


static func _style_buttons(theme: Theme) -> void:
	theme.set_font("font", "Button", FONT_STRONG)
	theme.set_font_size("font_size", "Button", 22)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", NEON_PINK)
	theme.set_color("font_focus_color", "Button", NEON_PINK)
	theme.set_color("font_pressed_color", "Button", AMBER)
	theme.set_color("font_disabled_color", "Button", Color(DIM, 0.5))
	theme.set_stylebox("normal", "Button", box(Color(TEXT, 0.04), Color(TEXT, 0.22), 1))
	theme.set_stylebox("hover", "Button", box(Color(NEON_PINK, 0.12), NEON_PINK, 1))
	theme.set_stylebox("focus", "Button", box(Color(NEON_PINK, 0.08), NEON_PINK, 1))
	theme.set_stylebox("pressed", "Button", box(Color(AMBER, 0.15), AMBER, 1))
	theme.set_stylebox("disabled", "Button", box(Color(TEXT, 0.02), Color(TEXT, 0.08), 1))
	theme.set_color("font_color", "CheckButton", TEXT)
	theme.set_color("font_hover_color", "CheckButton", NEON_PINK)
	theme.set_color("font_focus_color", "CheckButton", NEON_PINK)


static func _style_fields(theme: Theme) -> void:
	theme.set_font("font", "LineEdit", FONT_MONO)
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("caret_color", "LineEdit", NEON_CYAN)
	theme.set_stylebox("normal", "LineEdit", box(Color(INK, 0.7), Color(TEXT, 0.25), 1))
	theme.set_stylebox("focus", "LineEdit", box(Color(INK, 0.7), NEON_CYAN, 1))
	theme.set_stylebox("read_only", "LineEdit", box(Color(INK, 0.4), Color(TEXT, 0.1), 1))
	var track: StyleBoxFlat = box(Color(TEXT, 0.18), Color(TEXT, 0.0), 0)
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	theme.set_stylebox("slider", "HSlider", track)
	var filled: StyleBoxFlat = box(NEON_PINK, Color(NEON_PINK, 0.0), 0)
	filled.content_margin_top = 2
	filled.content_margin_bottom = 2
	theme.set_stylebox("grabber_area", "HSlider", filled)
	theme.set_stylebox("grabber_area_highlight", "HSlider", filled)
