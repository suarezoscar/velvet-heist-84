## @file name_panel.gd
## «¿Cómo te llamas?» (FEAT-035): la primera vez que se abre el juego, el menú principal pide un
## nombre para la sala de espera y para la firma del ladrón. Se puede dejar sin nombre (firma
## «—V.») y cambiarlo después en Opciones. Guarda en los ajustes y avisa con done.
class_name NamePanel
extends PanelContainer

## Se emite al guardar o al seguir sin nombre
signal done

var settings: GameSettings = null
var field: LineEdit = null
var preview: Label = null
var save_button: Button = null
var skip_button: Button = null
var _settings_path: String = GameSettings.DEFAULT_PATH


func setup(current: GameSettings, path: String = GameSettings.DEFAULT_PATH) -> void:
	settings = current
	_settings_path = path
	custom_minimum_size = Vector2(620.0, 0.0)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	box.add_child(
		MenuTheme84.label("¿CÓMO TE LLAMAS?", MenuTheme84.FONT_DISPLAY, 64, MenuTheme84.TEXT)
	)
	var intro: Label = MenuTheme84.label(
		"Así te verán en la sala de espera. Si te toca ser el ladrón, firmarás con tu inicial.",
		MenuTheme84.FONT_BODY,
		24,
		MenuTheme84.DIM
	)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(intro)
	field = name_field(settings.player_name)
	field.text_submitted.connect(func(_text: String) -> void: _save())
	box.add_child(field)
	preview = MenuTheme84.label("", MenuTheme84.FONT_SCRIPT, 44, MenuTheme84.AMBER)
	box.add_child(preview)
	field.text_changed.connect(func(text: String) -> void: preview.text = preview_text(text))
	preview.text = preview_text(field.text)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	save_button = Button.new()
	save_button.text = "ESTE SOY YO"
	save_button.pressed.connect(_save)
	row.add_child(save_button)
	skip_button = Button.new()
	skip_button.text = "SIN NOMBRE"
	skip_button.pressed.connect(_skip)
	row.add_child(skip_button)


## Campo de texto para un nombre (también lo usan las Opciones)
static func name_field(current: String) -> LineEdit:
	var line: LineEdit = LineEdit.new()
	line.text = current
	line.max_length = PlayerName.MAX_LENGTH
	line.placeholder_text = "Tu nombre"
	line.custom_minimum_size = Vector2(420.0, 52.0)
	line.add_theme_font_size_override("font_size", 28)
	return line


## «Con mis respetos, —D.» con la firma que daría ese nombre
static func preview_text(raw: String) -> String:
	return "Con mis respetos, %s" % PlayerName.signature(PlayerName.clean(raw))


func _save() -> void:
	settings.player_name = PlayerName.clean(field.text)
	_finish()


func _skip() -> void:
	settings.player_name = ""
	_finish()


func _finish() -> void:
	settings.name_asked = true
	settings.save(_settings_path)
	done.emit()
