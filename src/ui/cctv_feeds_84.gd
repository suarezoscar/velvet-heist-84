## @file cctv_feeds_84.gd
## Imágenes de las cámaras CCTV en el HUD del guardia que mira los monitores
## (interaction.md M2): una fila de paneles 4:3 centrada bajo la barra superior, con el
## shader CRT, el rótulo de cada cámara y un marco que se pone rojo cuando detecta.
## Mide contra el viewport (no contra su propio tamaño): debe colgar de un HUD a pantalla completa.
class_name CCTVFeeds84
extends Control

const RULES: CCTVRules = preload("res://data/balance/cctv_rules.tres")
const FEED_SHADER: Shader = preload("res://assets/shaders/crt_feed_ui.gdshader")
## Proporción de cada imagen (ancho / alto)
const ASPECT: float = 4.0 / 3.0
## Borde superior de la fila: deja libre la barra superior del HUD
const TOP_MARGIN: float = 60.0
## Separación entre imágenes
const GAP: float = 12.0
## Ancho máximo de la fila, como fracción del ancho de pantalla (fuera de 16:9 encoge el alto)
const MAX_ROW_WIDTH_FRAC: float = 0.96
const FRAME_COLOR: Color = Color(0.22, 0.24, 0.22)
const FRAME_ALERT_COLOR: Color = Color(1.0, 0.15, 0.1)
const FRAME_WIDTH: int = 2
const FRAME_ALERT_WIDTH: int = 4
const LABEL_COLOR: Color = Color("b8e6c1")
const LABEL_OFFSET: Vector2 = Vector2(10.0, 6.0)

var _feeds: Array[Feed] = []


## Una imagen de cámara con sus nodos
class Feed:
	var camera: SecurityCamera3D = null
	var root: Control = null
	var label: Label = null
	var style: StyleBoxFlat = null
	var material: ShaderMaterial = null
	var alert: bool = false


func _ready() -> void:
	name = "CCTVFeeds"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _process(_delta: float) -> void:
	for feed: Feed in _feeds:
		if is_instance_valid(feed.camera):
			_set_alert(feed, feed.camera.is_alert_active)


## Crea un panel por cámara, ordenadas por su camera_id (sustituye a las anteriores)
func setup(cameras: Array[SecurityCamera3D]) -> void:
	_clear()
	var sorted: Array[SecurityCamera3D] = cameras.duplicate()
	sorted.sort_custom(
		func(a: SecurityCamera3D, b: SecurityCamera3D) -> bool:
			return a.camera_id.naturalnocasecmp_to(b.camera_id) < 0
	)
	for camera: SecurityCamera3D in sorted:
		_feeds.append(_build_feed(camera))
	_layout()


## Número de paneles (lo usan los tests)
func panel_count() -> int:
	return _feeds.size()


## Rectángulo de la imagen del panel, en coordenadas de este Control
func feed_rect(index: int) -> Rect2:
	var root: Control = _feeds[index].root
	return Rect2(root.position, root.size)


## Rótulo del panel (lo usan los tests)
func label_text(index: int) -> String:
	return _feeds[index].label.text


## Marco del panel en rojo de alerta (lo usan los tests)
func is_frame_alert(index: int) -> bool:
	return _feeds[index].alert


func _clear() -> void:
	for feed: Feed in _feeds:
		remove_child(feed.root)
		feed.root.queue_free()
	_feeds.clear()


func _build_feed(camera: SecurityCamera3D) -> Feed:
	var feed: Feed = Feed.new()
	feed.camera = camera
	feed.root = Control.new()
	feed.root.name = "Feed_%s" % camera.camera_id
	feed.root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feed.root.clip_contents = true
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
	picture.material = feed.material
	feed.root.add_child(picture)

	feed.label = Label.new()
	feed.label.name = "Caption"
	feed.label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feed.label.text = ("%s %s" % [camera.camera_id, camera.camera_label]).strip_edges()
	feed.label.position = LABEL_OFFSET
	feed.label.add_theme_color_override("font_color", LABEL_COLOR)
	feed.label.add_theme_color_override("font_outline_color", Color.BLACK)
	feed.label.add_theme_constant_override("outline_size", 4)
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


func _set_alert(feed: Feed, alert: bool) -> void:
	if alert == feed.alert:
		return
	feed.alert = alert
	feed.material.set_shader_parameter(&"is_alert_active", alert)
	_apply_frame(feed)


func _apply_frame(feed: Feed) -> void:
	feed.style.border_color = FRAME_ALERT_COLOR if feed.alert else FRAME_COLOR
	feed.style.set_border_width_all(FRAME_ALERT_WIDTH if feed.alert else FRAME_WIDTH)


## Coloca la fila: alto = feed_height_frac del alto visible, 4:3, centrada en horizontal
func _layout() -> void:
	if _feeds.is_empty() or not is_inside_tree():
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	var count: int = _feeds.size()
	var max_width: float = (view.x * MAX_ROW_WIDTH_FRAC - GAP * (count - 1)) / count
	var feed_size: Vector2 = Vector2(minf(RULES.feed_height_frac * view.y * ASPECT, max_width), 0.0)
	feed_size.y = feed_size.x / ASPECT
	var total: float = feed_size.x * _feeds.size() + GAP * (_feeds.size() - 1)
	var left: float = (view.x - total) * 0.5
	var font_size: int = clampi(roundi(feed_size.y * 0.045), 11, 26)
	for i: int in _feeds.size():
		var feed: Feed = _feeds[i]
		feed.root.position = Vector2(left + i * (feed_size.x + GAP), TOP_MARGIN)
		feed.root.size = feed_size
		feed.label.add_theme_font_size_override("font_size", font_size)
