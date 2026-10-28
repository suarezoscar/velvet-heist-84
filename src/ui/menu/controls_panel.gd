## @file controls_panel.gd
## Panel de controles del menú principal (FEAT-024): las teclas de cada bando según
## ControlsCatalog, en dos columnas por grupo. Se abre desde Opciones.
class_name ControlsPanel
extends PanelContainer

## Se emite al pulsar «Volver»
signal back_requested

const KEY_COLUMN: float = 300.0

var back_button: Button = null
var _rows: VBoxContainer = null


func _ready() -> void:
	custom_minimum_size = Vector2(760.0, 0.0)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	box.add_child(MenuTheme84.label("CONTROLES", MenuTheme84.FONT_DISPLAY, 64, MenuTheme84.TEXT))
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	box.add_child(_rows)
	refresh()
	box.add_child(HSeparator.new())
	back_button = Button.new()
	back_button.text = "VOLVER"
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back_button.pressed.connect(back_requested.emit)
	box.add_child(back_button)


## Vuelve a leer las teclas del InputMap
func refresh() -> void:
	for child: Node in _rows.get_children():
		child.queue_free()
	for group: Dictionary in ControlsCatalog.groups():
		var title: Label = MenuTheme84.label(
			group["title"], MenuTheme84.FONT_STRONG, 20, MenuTheme84.NEON_CYAN
		)
		_rows.add_child(title)
		for row: Array in group["rows"]:
			_rows.add_child(_row(String(row[0]), String(row[1])))


## Texto de todas las filas (lo usan los tests)
func rows_text() -> String:
	var lines: Array[String] = []
	for group: Dictionary in ControlsCatalog.groups():
		for row: Array in group["rows"]:
			lines.append("%s: %s" % [row[0], row[1]])
	return "\n".join(PackedStringArray(lines))


func _row(action: String, keys_text: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var name_label: Label = MenuTheme84.label(action, MenuTheme84.FONT_BODY, 22, MenuTheme84.TEXT)
	name_label.custom_minimum_size = Vector2(KEY_COLUMN + 120.0, 0.0)
	row.add_child(name_label)
	row.add_child(MenuTheme84.label(keys_text, MenuTheme84.FONT_MONO, 20, MenuTheme84.AMBER))
	return row
