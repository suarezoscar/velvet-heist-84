## @file options_panel.gd
## Panel de opciones del menú principal: pantalla completa, sincronía vertical, volumen
## general y panel de rendimiento. Cada cambio se aplica y se guarda al momento.
class_name OptionsPanel
extends PanelContainer

## Se emite al pulsar «Volver»
signal back_requested
## Se emite al pulsar «Ver controles»
signal controls_requested

var settings: GameSettings = null
var fullscreen_check: CheckButton = null
var vsync_check: CheckButton = null
var volume_slider: HSlider = null
var perf_check: CheckButton = null
var controls_button: Button = null
var back_button: Button = null
var _volume_value: Label = null
var _settings_path: String = GameSettings.DEFAULT_PATH


## Rellena el panel con los ajustes dados; path es donde se guardan (los tests usan otro)
func setup(current: GameSettings, path: String = GameSettings.DEFAULT_PATH) -> void:
	settings = current
	_settings_path = path
	custom_minimum_size = Vector2(620.0, 0.0)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	add_child(box)
	box.add_child(MenuTheme84.label("OPCIONES", MenuTheme84.FONT_DISPLAY, 64, MenuTheme84.TEXT))
	box.add_child(_section("PANTALLA"))
	fullscreen_check = _check(box, "Pantalla completa", settings.fullscreen)
	fullscreen_check.toggled.connect(_on_fullscreen)
	vsync_check = _check(box, "Sincronía vertical (VSync)", settings.vsync)
	vsync_check.toggled.connect(_on_vsync)
	box.add_child(_section("SONIDO"))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var name_label: Label = MenuTheme84.label(
		"Volumen general", MenuTheme84.FONT_BODY, 24, MenuTheme84.TEXT
	)
	name_label.custom_minimum_size = Vector2(230.0, 0.0)
	row.add_child(name_label)
	volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 100.0
	volume_slider.step = 5.0
	volume_slider.value = roundf(settings.master_volume * 100.0)
	volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	volume_slider.value_changed.connect(_on_volume)
	row.add_child(volume_slider)
	_volume_value = MenuTheme84.label("", MenuTheme84.FONT_MONO, 22, MenuTheme84.AMBER)
	_volume_value.custom_minimum_size = Vector2(60.0, 0.0)
	row.add_child(_volume_value)
	_refresh_volume_label()
	box.add_child(_section("DEPURACIÓN"))
	perf_check = _check(
		box,
		"Panel de rendimiento y red (%s)" % ControlsCatalog.keys(&"toggle_perf_overlay"),
		settings.show_perf
	)
	perf_check.toggled.connect(_on_perf)
	box.add_child(_section("TECLADO Y RATÓN"))
	controls_button = Button.new()
	controls_button.text = "VER CONTROLES"
	controls_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	controls_button.pressed.connect(controls_requested.emit)
	box.add_child(controls_button)
	box.add_child(HSeparator.new())
	back_button = Button.new()
	back_button.text = "VOLVER"
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back_button.pressed.connect(back_requested.emit)
	box.add_child(back_button)


func _section(text: String) -> Label:
	return MenuTheme84.label(text, MenuTheme84.FONT_STRONG, 20, MenuTheme84.NEON_CYAN)


func _check(box: VBoxContainer, text: String, value: bool) -> CheckButton:
	var check: CheckButton = CheckButton.new()
	check.text = text
	check.button_pressed = value
	check.add_theme_font_size_override("font_size", 24)
	box.add_child(check)
	return check


func _on_fullscreen(on: bool) -> void:
	settings.fullscreen = on
	_commit()


func _on_vsync(on: bool) -> void:
	settings.vsync = on
	_commit()


func _on_perf(on: bool) -> void:
	settings.show_perf = on
	_commit()


func _on_volume(value: float) -> void:
	settings.master_volume = value / 100.0
	_refresh_volume_label()
	_commit()


func _refresh_volume_label() -> void:
	_volume_value.text = "%d" % int(roundf(settings.master_volume * 100.0))


func _commit() -> void:
	settings.apply()
	settings.save(_settings_path)
