## @file cctv_feeds_84.gd
## Imagen de la cámara en pantalla en el HUD de quien mira los monitores (interaction.md M2,
## #118): una sola imagen 4:3 casi a pantalla completa sobre un margen oscuro (sin mundo), con
## el shader CRT, su rótulo («CAM 07 · PIEZA MAESTRA») y un marco que se pone rojo cuando
## detecta. Sigue la cámara que la mesa tiene en pantalla (CCTVDesk3D.current) y, al cambiar,
## enseña switch_time s de nieve. Solo la SubViewport de la cámara que se ve renderiza (M8).
## Mide contra el viewport (no contra su propio tamaño): debe colgar de un HUD a pantalla completa.
class_name CCTVFeeds84
extends Control

const RULES: CCTVRules = preload("res://data/balance/cctv_rules.tres")
const FEED_SHADER: Shader = preload("res://assets/shaders/crt_feed_ui.gdshader")
## Proporción de la imagen (ancho / alto)
const ASPECT: float = 4.0 / 3.0
## Ancho máximo de la imagen, como fracción del ancho de pantalla (fuera de 16:9 encoge el alto)
const MAX_WIDTH_FRAC: float = 0.96
const BACKDROP_COLOR: Color = Color(0.01, 0.015, 0.02, 0.96)
const FRAME_COLOR: Color = Color(0.22, 0.24, 0.22)
const FRAME_ALERT_COLOR: Color = Color(1.0, 0.15, 0.1)
const FRAME_WIDTH: int = 2
const FRAME_ALERT_WIDTH: int = 4
const LABEL_COLOR: Color = Color("b8e6c1")
const LABEL_OFFSET: Vector2 = Vector2(16.0, 10.0)
## Ruido del shader en la imagen normal y durante la nieve del cambio
const NOISE: float = 0.08
const SNOW_NOISE: float = 1.4
const SNOW_TINT: Color = Color(0.22, 0.26, 0.22)

var _feeds: Array[Feed] = []
var _backdrop: ColorRect = null
## Índice de la imagen que se enseña (-1: ninguna)
var _shown: int = -1
var _snow_left: float = 0.0


## Una imagen de cámara con sus nodos
class Feed:
	var camera: SecurityCamera3D = null
	var root: Control = null
	var label: Label = null
	var style: StyleBoxFlat = null
	var material: ShaderMaterial = null
	var picture: TextureRect = null
	var alert: bool = false


func _ready() -> void:
	name = "CCTVFeeds"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop = ColorRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.color = BACKDROP_COLOR
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)
	get_viewport().size_changed.connect(_layout)
	visibility_changed.connect(_update_rendering)
	_layout()


func _process(delta: float) -> void:
	var desk: CCTVDesk3D = CCTVDesk3D.of(get_tree()) if is_inside_tree() else null
	if desk != null:
		show_index(desk.current)
	if _snow_left > 0.0:
		_snow_left = maxf(0.0, _snow_left - delta)
		if _snow_left == 0.0 and _shown >= 0:
			_snow(_feeds[_shown], false)
	for feed: Feed in _feeds:
		if is_instance_valid(feed.camera):
			_set_alert(feed, feed.camera.is_alert_active)


## Crea una imagen por cámara, en el orden de su camera_id (sustituye a las anteriores);
## se enseña la primera hasta que la mesa diga otra
func setup(cameras: Array[SecurityCamera3D]) -> void:
	_clear()
	var sorted: Array[SecurityCamera3D] = cameras.duplicate()
	sorted.sort_custom(
		func(a: SecurityCamera3D, b: SecurityCamera3D) -> bool:
			return a.camera_id.naturalnocasecmp_to(b.camera_id) < 0
	)
	for camera: SecurityCamera3D in sorted:
		_feeds.append(_build_feed(camera))
	_shown = -1
	show_index(0)
	_snow_left = 0.0
	_layout()


## Enseña la imagen index (en bucle sobre las que hay); al cambiar, nieve switch_time s
func show_index(index: int) -> void:
	if _feeds.is_empty():
		return
	index = posmod(index, _feeds.size())
	if index == _shown:
		return
	var had_one: bool = _shown >= 0
	_shown = index
	for i: int in range(_feeds.size()):
		_feeds[i].root.visible = i == index
	if had_one:
		_snow_left = RULES.switch_time
		_snow(_feeds[index], true)
	_update_rendering()


## Número de imágenes (lo usan los tests)
func panel_count() -> int:
	return _feeds.size()


## Índice de la imagen en pantalla (lo usan los tests)
func shown_index() -> int:
	return _shown


## true durante la nieve del cambio de cámara (lo usan los tests)
func is_snowing() -> bool:
	return _snow_left > 0.0


## Rectángulo de la imagen index, en coordenadas de este Control
func feed_rect(index: int) -> Rect2:
	var root: Control = _feeds[index].root
	return Rect2(root.position, root.size)


## Rótulo de la imagen (lo usan los tests)
func label_text(index: int) -> String:
	return _feeds[index].label.text


## Marco de la imagen en rojo de alerta (lo usan los tests)
func is_frame_alert(index: int) -> bool:
	return _feeds[index].alert


## «CAM 07 · PIEZA MAESTRA» a partir de camera_id («CAM-07») y camera_label
static func caption(camera: SecurityCamera3D) -> String:
	var id: String = camera.camera_id.replace("-", " ")
	return id if camera.camera_label == "" else "%s · %s" % [id, camera.camera_label]


func _clear() -> void:
	for feed: Feed in _feeds:
		_set_rendering(feed.camera, false)
		remove_child(feed.root)
		feed.root.queue_free()
	_feeds.clear()


## M8: renderiza solo la cámara que se ve, y solo mientras este HUD la enseña
func _update_rendering() -> void:
	for i: int in range(_feeds.size()):
		_set_rendering(_feeds[i].camera, is_visible_in_tree() and i == _shown)


static func _set_rendering(camera: SecurityCamera3D, on: bool) -> void:
	if is_instance_valid(camera) and camera.sub_viewport != null:
		camera.sub_viewport.render_target_update_mode = (
			SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
		)


func _build_feed(camera: SecurityCamera3D) -> Feed:
	var feed: Feed = Feed.new()
	feed.camera = camera
	feed.root = Control.new()
	feed.root.name = "Feed_%s" % camera.camera_id
	feed.root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feed.root.clip_contents = true
	feed.root.visible = false
	add_child(feed.root)

	var picture: TextureRect = TextureRect.new()
	picture.name = "Picture"
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	picture.texture = camera.get_viewport_texture()
	feed.material = ShaderMaterial.new()
	feed.material.shader = FEED_SHADER
	feed.material.set_shader_parameter(&"is_alert_active", false)
	feed.material.set_shader_parameter(&"noise_intensity", NOISE)
	picture.material = feed.material
	feed.root.add_child(picture)
	feed.picture = picture

	feed.label = Label.new()
	feed.label.name = "Caption"
	feed.label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feed.label.text = caption(camera)
	feed.label.position = LABEL_OFFSET
	feed.label.add_theme_color_override("font_color", LABEL_COLOR)
	feed.label.add_theme_color_override("font_outline_color", Color.BLACK)
	feed.label.add_theme_constant_override("outline_size", 6)
	feed.root.add_child(feed.label)

	feed.style = StyleBoxFlat.new()
	feed.style.draw_center = false
	var frame: Panel = Panel.new()
	frame.name = "Frame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_stylebox_override("panel", feed.style)
	feed.root.add_child(frame)
	_apply_frame(feed)
	return feed


## Nieve del cambio de cámara: la imagen se apaga casi entera y se llena de ruido
func _snow(feed: Feed, on: bool) -> void:
	feed.material.set_shader_parameter(&"noise_intensity", SNOW_NOISE if on else NOISE)
	feed.picture.self_modulate = SNOW_TINT if on else Color.WHITE


func _set_alert(feed: Feed, alert: bool) -> void:
	if alert == feed.alert:
		return
	feed.alert = alert
	feed.material.set_shader_parameter(&"is_alert_active", alert)
	_apply_frame(feed)


func _apply_frame(feed: Feed) -> void:
	feed.style.border_color = FRAME_ALERT_COLOR if feed.alert else FRAME_COLOR
	feed.style.set_border_width_all(FRAME_ALERT_WIDTH if feed.alert else FRAME_WIDTH)


## Coloca la imagen: alto = feed_height_frac del alto visible, 4:3, centrada; el margen oscuro
## cubre toda la pantalla
func _layout() -> void:
	if not is_inside_tree():
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	if _backdrop != null:
		_backdrop.position = Vector2.ZERO
		_backdrop.size = view
	if _feeds.is_empty():
		return
	var width: float = minf(RULES.feed_height_frac * view.y * ASPECT, view.x * MAX_WIDTH_FRAC)
	var feed_size: Vector2 = Vector2(width, width / ASPECT)
	var font_size: int = clampi(roundi(feed_size.y * 0.035), 14, 34)
	for feed: Feed in _feeds:
		feed.root.position = (view - feed_size) * 0.5
		feed.root.size = feed_size
		feed.label.add_theme_font_size_override("font_size", font_size)
