## @file options_panel.gd
## Panel de opciones del menú principal: pantalla completa, sincronía vertical, volúmenes
## (general, música y efectos) y panel de rendimiento. Cada cambio se aplica y se guarda al
## momento.
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
var music_slider: HSlider = null
var sfx_slider: HSlider = null
var perf_check: CheckButton = null
var controls_button: Button = null
var back_button: Button = null
var _settings_path: String = GameSettings.DEFAULT_PATH


## Rellena el panel con los ajustes dados; path es donde se guardan (los tests usan otro)
func setup(current: GameSettings, path: String = GameSettings.DEFAULT_PATH) -> void:
	settings = current
	_settings_path = path
	custom_minimum_size = Vector2(620.0, 0.0)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	box.add_child(MenuTheme84.label("OPCIONES", MenuTheme84.FONT_DISPLAY, 64, MenuTheme84.TEXT))
	box.add_child(_section("PANTALLA"))
	fullscreen_check = _check(box, "Pantalla completa", settings.fullscreen)
	fullscreen_check.toggled.connect(_on_fullscreen)
	vsync_check = _check(box, "Sincronía vertical (VSync)", settings.vsync)
	vsync_check.toggled.connect(_on_vsync)
	box.add_child(_section("SONIDO"))
	volume_slider = _slider(box, "Volumen general", settings.master_volume, &"master_volume")
	music_slider = _slider(box, "Música", settings.music_volume, &"music_volume")
	sfx_slider = _slider(box, "Efectos", settings.sfx_volume, &"sfx_volume")
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


## Fila «nombre — deslizador 0-100 — valor» que guarda en el campo field de los ajustes
func _slider(box: VBoxContainer, text: String, value: float, field: StringName) -> HSlider:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var name_label: Label = MenuTheme84.label(text, MenuTheme84.FONT_BODY, 24, MenuTheme84.TEXT)
	name_label.custom_minimum_size = Vector2(230.0, 0.0)
	row.add_child(name_label)
	var slider: HSlider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 5.0
	slider.value = roundf(value * 100.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var value_label: Label = MenuTheme84.label(
		"%d" % int(slider.value), MenuTheme84.FONT_MONO, 22, MenuTheme84.AMBER
	)
	value_label.custom_minimum_size = Vector2(60.0, 0.0)
	row.add_child(value_label)
	slider.value_changed.connect(
		func(new_value: float) -> void:
			settings.set(field, new_value / 100.0)
			value_label.text = "%d" % int(new_value)
			_commit()
	)
	return slider


func _on_fullscreen(on: bool) -> void:
	settings.fullscreen = on
	_commit()


func _on_vsync(on: bool) -> void:
	settings.vsync = on
	_commit()


func _on_perf(on: bool) -> void:
	settings.show_perf = on
	_commit()


func _commit() -> void:
	settings.apply()
	settings.save(_settings_path)
