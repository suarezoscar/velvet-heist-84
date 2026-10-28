## @file main_menu.gd
## Menú principal de Velvet Heist '84 (FEAT-018): fondo nocturno con zoom lento, logo de neón,
## entradas Un jugador, Multijugador, Opciones y Salir, y el crédito del autor. Un jugador y
## Opciones se abren como paneles a la derecha; Multijugador abre el lobby (LobbyView).
class_name MainMenu
extends Control

const BACKDROP_SHADER: Shader = preload("res://assets/shaders/menu_backdrop.gdshader")
const MARGIN: float = 120.0
const NAV_TOP: float = 560.0
const ZOOM_SCALE: float = 1.07
const ZOOM_TIME: float = 40.0
const FADE_TIME: float = 0.7
const PANEL_SHIFT: float = 40.0
const VERSION_PREFIX: String = "PROTOTIPO  v"
const CREDIT_TEXT: String = "Un juego de Óscar Suárez"

var settings: GameSettings = null
var home: Control = null
var logo: TitleLogo84 = null
var nav: MenuNav84 = null
var hint_label: Label = null
var credit_label: Label = null
var version_label: Label = null
var single_player: SinglePlayerPanel = null
var options: OptionsPanel = null
var controls: ControlsPanel = null
var _open_panel: Control = null

@onready var background: TextureRect = $Background
@onready var lobby_view: LobbyView = $LobbyView


func _ready() -> void:
	settings = GameSettings.load_saved()
	settings.apply()
	theme = MenuTheme84.build()
	_build_backdrop()
	_build_home()
	_build_panels()
	lobby_view.back_requested.connect(_show_home)
	_show_home()
	_play_intro()
	var notice: String = MenuReturn.take_notice()
	if notice != "":  # volvemos de una partida que se cortó (FEAT-026)
		open_section(&"multi")
		lobby_view.show_notice(notice)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and _open_panel != null:
		_close_panel()
		get_viewport().set_input_as_handled()


## Abre una sección del menú: &"single", &"multi", &"options" o &"quit"
func open_section(id: StringName) -> void:
	match id:
		&"single":
			_open(single_player)
		&"options":
			_open(options)
		&"multi":
			_close_panel()
			home.visible = false
			lobby_view.visible = true
			lobby_view.refresh()
		&"quit":
			get_tree().quit()


func _build_backdrop() -> void:
	background.resized.connect(func() -> void: background.pivot_offset = background.size * 0.5)
	background.pivot_offset = background.size * 0.5
	var overlay: ColorRect = ColorRect.new()
	overlay.name = "Backdrop"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = BACKDROP_SHADER
	overlay.material = material
	add_child(overlay)
	move_child(overlay, background.get_index() + 1)
	var zoom: Tween = create_tween().set_loops()
	zoom.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	zoom.tween_property(background, "scale", Vector2.ONE * ZOOM_SCALE, ZOOM_TIME)
	zoom.tween_property(background, "scale", Vector2.ONE, ZOOM_TIME)


func _build_home() -> void:
	home = Control.new()
	home.name = "Home"
	home.set_anchors_preset(Control.PRESET_FULL_RECT)
	home.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(home)
	logo = TitleLogo84.new()
	logo.position = Vector2(MARGIN, 110.0)
	home.add_child(logo)
	nav = MenuNav84.new()
	nav.position = Vector2(MARGIN, NAV_TOP)
	home.add_child(nav)
	nav.add_entry(&"single", "UN JUGADOR", "Tú eres el ladrón; la IA lleva a los guardias.")
	nav.add_entry(&"multi", "MULTIJUGADOR", "Únete a un servidor por IP y elige bando.")
	nav.add_entry(&"options", "OPCIONES", "Pantalla y sonido.")
	nav.add_entry(&"quit", "SALIR", "Hasta la próxima noche.")
	nav.entry_chosen.connect(open_section)
	hint_label = MenuTheme84.label("", MenuTheme84.FONT_BODY, 22, MenuTheme84.DIM)
	hint_label.position = Vector2(MARGIN + 2.0, NAV_TOP + 4.0 * 68.0 + 18.0)
	home.add_child(hint_label)
	nav.set_hint_label(hint_label)
	version_label = MenuTheme84.label(
		VERSION_PREFIX + GameVersion.current(),
		MenuTheme84.FONT_MONO,
		16,
		Color(MenuTheme84.DIM, 0.7)
	)
	version_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	version_label.position += Vector2(MARGIN * 0.5, -36.0)
	home.add_child(version_label)
	credit_label = MenuTheme84.label(
		CREDIT_TEXT, MenuTheme84.FONT_BODY, 20, Color(MenuTheme84.TEXT, 0.5)
	)
	credit_label.name = "Credit"
	credit_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	credit_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	credit_label.position += Vector2(-MARGIN * 0.5, -38.0)
	home.add_child(credit_label)


func _build_panels() -> void:
	single_player = SinglePlayerPanel.new()
	single_player.name = "SinglePlayerPanel"
	single_player.start_requested.connect(_load_scene)
	single_player.back_requested.connect(_close_panel)
	options = OptionsPanel.new()
	options.name = "OptionsPanel"
	options.setup(settings)
	options.back_requested.connect(_close_panel)
	options.controls_requested.connect(func() -> void: _open(controls))
	controls = ControlsPanel.new()
	controls.name = "ControlsPanel"
	controls.back_requested.connect(func() -> void: _open(options))
	for panel: Control in [single_player, options, controls]:
		panel.visible = false
		home.add_child(panel)


func _open(panel: Control) -> void:
	if _open_panel == panel:
		return
	if _open_panel != null:
		_open_panel.visible = false
	_open_panel = panel
	panel.visible = true
	panel.reset_size()
	# A la altura del menú, o más arriba si el panel es alto (Controles)
	var view: Vector2 = get_viewport_rect().size
	var top: float = clampf(view.y - panel.size.y - 60.0, 40.0, NAV_TOP - 260.0)
	var target: Vector2 = Vector2(view.x - MARGIN - panel.size.x, top)
	panel.position = target + Vector2(PANEL_SHIFT, 0.0)
	panel.modulate.a = 0.0
	var tween: Tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "position", target, 0.25)
	tween.tween_property(panel, "modulate:a", 1.0, 0.25)


func _close_panel() -> void:
	if _open_panel != null:
		_open_panel.visible = false
	_open_panel = null
	nav.focus_first()


func _show_home() -> void:
	lobby_view.visible = false
	home.visible = true
	nav.focus_first()


func _play_intro() -> void:
	home.modulate.a = 0.0
	logo.position.x = MARGIN - 30.0
	var tween: Tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(home, "modulate:a", 1.0, FADE_TIME)
	tween.tween_property(logo, "position:x", MARGIN, FADE_TIME * 1.4)


func _load_scene(path: String) -> void:
	print("[MainMenu] Cargando escenario: ", path)
	get_tree().change_scene_to_file(path)
