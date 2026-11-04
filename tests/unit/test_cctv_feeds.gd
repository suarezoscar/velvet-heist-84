## @file test_cctv_feeds.gd
## Tests de la imagen CCTV del HUD (interaction.md M2 y M8, #118): una imagen por cámara y solo
## una visible, 4:3 casi a pantalla completa y centrada, cambio en bucle con nieve, rótulo,
## marco de alerta y render solo de la cámara que se ve.
extends GutTest

const RULES: CCTVRules = preload("res://data/balance/cctv_rules.tres")
const CAMERA_SCENE: PackedScene = preload("res://scenes/entities/security_camera.tscn")
const ASPECT_TOLERANCE: float = 0.005


## Cámaras en desorden a propósito: CAM-02, CAM-01, CAM-03
func _cameras() -> Array[SecurityCamera3D]:
	var cameras: Array[SecurityCamera3D] = []
	var ids: Array[String] = ["CAM-02", "CAM-01", "CAM-03"]
	var labels: Array[String] = ["GALERÍA", "VESTÍBULO", "ALMACÉN"]
	for i: int in ids.size():
		var camera: SecurityCamera3D = CAMERA_SCENE.instantiate() as SecurityCamera3D
		camera.camera_id = ids[i]
		camera.camera_label = labels[i]
		camera.sweep_enabled = false
		add_child_autofree(camera)
		cameras.append(camera)
	return cameras


func _feeds_in(parent: Node, cameras: Array[SecurityCamera3D]) -> CCTVFeeds84:
	var feeds: CCTVFeeds84 = CCTVFeeds84.new()
	parent.add_child(feeds)
	feeds.setup(cameras)
	return feeds


## Panel dentro de un SubViewport del tamaño dado, para medir a otras resoluciones
func _feeds_in_viewport(cameras: Array[SecurityCamera3D], size: Vector2i) -> CCTVFeeds84:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = size
	add_child_autofree(viewport)
	return _feeds_in(viewport, cameras)


func _mode(camera: SecurityCamera3D) -> int:
	return camera.sub_viewport.render_target_update_mode


func test_one_feed_per_camera_sorted_and_only_one_shown() -> void:
	var feeds: CCTVFeeds84 = _feeds_in(self, _cameras())
	autofree(feeds)
	assert_eq(feeds.panel_count(), 3, "Una imagen por cámara")
	assert_eq(feeds.label_text(0), "CAM 01 · VESTÍBULO", "Primero CAM-01")
	assert_eq(feeds.label_text(1), "CAM 02 · GALERÍA")
	assert_eq(feeds.label_text(2), "CAM 03 · ALMACÉN")
	assert_eq(feeds.shown_index(), 0, "Se empieza por la primera")
	var visible_count: int = 0
	for node: Node in feeds.find_children("Feed_*", "Control", false, false):
		visible_count += int((node as Control).visible)
	assert_eq(visible_count, 1, "Solo una imagen visible")


func test_feed_is_4_3_centered_at_1080p() -> void:
	var feeds: CCTVFeeds84 = _feeds_in_viewport(_cameras(), Vector2i(1920, 1080))
	var rect: Rect2 = feeds.feed_rect(0)
	assert_almost_eq(rect.size, Vector2(1296.0, 972.0), Vector2(1.0, 1.0), "0,9 del alto, 4:3")
	assert_almost_eq(rect.size.x / rect.size.y, 4.0 / 3.0, ASPECT_TOLERANCE)
	assert_almost_eq(rect.position.x, (1920.0 - rect.size.x) * 0.5, 1.0, "Centrada en horizontal")
	assert_almost_eq(rect.position.y, (1080.0 - rect.size.y) * 0.5, 1.0, "Centrada en vertical")
	for i: int in range(1, feeds.panel_count()):
		assert_eq(feeds.feed_rect(i), rect, "Todas ocupan el mismo sitio")


func test_feed_fits_width_outside_16_9() -> void:
	var feeds: CCTVFeeds84 = _feeds_in_viewport(_cameras(), Vector2i(1024, 768))
	var rect: Rect2 = feeds.feed_rect(0)
	assert_lte(
		rect.size.x, 1024.0 * CCTVFeeds84.MAX_WIDTH_FRAC + 0.01, "No pasa del 96 % del ancho"
	)
	assert_almost_eq(rect.size.x / rect.size.y, 4.0 / 3.0, ASPECT_TOLERANCE, "Sigue siendo 4:3")
	assert_gte(rect.position.x, 0.0, "No se sale por la izquierda")
	assert_lte(rect.end.x, 1024.0, "Ni por la derecha")
	assert_lte(rect.size.y, RULES.feed_height_frac * 768.0 + 0.01)


func test_relayout_when_viewport_resizes() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	add_child_autofree(viewport)
	var feeds: CCTVFeeds84 = _feeds_in(viewport, _cameras())
	assert_almost_eq(feeds.feed_rect(0).size.y, 648.0, 1.0)
	viewport.size = Vector2i(1920, 1080)
	assert_almost_eq(feeds.feed_rect(0).size, Vector2(1296.0, 972.0), Vector2(1.0, 1.0))


func test_show_index_loops_and_snows_only_on_change() -> void:
	var feeds: CCTVFeeds84 = _feeds_in(self, _cameras())
	autofree(feeds)
	assert_false(feeds.is_snowing(), "No hay nieve al arrancar")
	feeds.show_index(1)
	assert_eq(feeds.shown_index(), 1)
	assert_true(feeds.is_snowing(), "Al cambiar, nieve")
	feeds.show_index(3)
	assert_eq(feeds.shown_index(), 0, "Pasada la última, vuelve a la primera")
	feeds.show_index(-1)
	assert_eq(feeds.shown_index(), 2, "Antes de la primera, la última")
	await wait_seconds(RULES.switch_time + 0.2)
	assert_false(feeds.is_snowing(), "La nieve dura switch_time")
	feeds.show_index(2)
	assert_false(feeds.is_snowing(), "Repetir la misma no hace nieve")


func test_caption_with_and_without_label() -> void:
	var camera: SecurityCamera3D = _cameras()[0]
	camera.camera_id = "CAM-07"
	camera.camera_label = "PIEZA MAESTRA"
	assert_eq(CCTVFeeds84.caption(camera), "CAM 07 · PIEZA MAESTRA")
	camera.camera_label = ""
	assert_eq(CCTVFeeds84.caption(camera), "CAM 07", "Sin etiqueta, solo el id")


func test_frame_turns_red_while_camera_detects() -> void:
	var cameras: Array[SecurityCamera3D] = _cameras()
	var feeds: CCTVFeeds84 = _feeds_in(self, cameras)
	autofree(feeds)
	await wait_frames(2)
	for i: int in feeds.panel_count():
		assert_false(feeds.is_frame_alert(i), "Sin alerta al empezar")
	cameras[0].is_alert_active = true  # CAM-02: segunda imagen
	await wait_frames(2)
	assert_true(feeds.is_frame_alert(1), "CAM-02 detecta: su marco en rojo")
	assert_false(feeds.is_frame_alert(0), "CAM-01 no detecta")
	assert_false(feeds.is_frame_alert(2), "CAM-03 no detecta")
	cameras[0].is_alert_active = false
	await wait_frames(2)
	assert_false(feeds.is_frame_alert(1), "Al perderlo vuelve al marco gris")


func test_only_the_shown_camera_renders_and_none_when_hidden() -> void:
	var cameras: Array[SecurityCamera3D] = _cameras()  # [CAM-02, CAM-01, CAM-03]
	var feeds: CCTVFeeds84 = _feeds_in(self, cameras)
	autofree(feeds)
	assert_eq(_mode(cameras[1]), SubViewport.UPDATE_ALWAYS, "CAM-01 se ve: renderiza")
	assert_eq(_mode(cameras[0]), SubViewport.UPDATE_DISABLED, "Las demás, no")
	assert_eq(_mode(cameras[2]), SubViewport.UPDATE_DISABLED)
	feeds.show_index(1)
	assert_eq(_mode(cameras[0]), SubViewport.UPDATE_ALWAYS, "Ahora CAM-02")
	assert_eq(_mode(cameras[1]), SubViewport.UPDATE_DISABLED, "CAM-01 deja de renderizar")
	feeds.hide()
	for camera: SecurityCamera3D in cameras:
		assert_eq(_mode(camera), SubViewport.UPDATE_DISABLED, "Oculto el HUD, ninguna")
	feeds.show()
	assert_eq(_mode(cameras[0]), SubViewport.UPDATE_ALWAYS, "Al volver, la mostrada")


func test_ignores_mouse_everywhere() -> void:
	var feeds: CCTVFeeds84 = _feeds_in(self, _cameras())
	autofree(feeds)
	assert_eq(feeds.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	for node: Node in feeds.find_children("*", "Control", true, false):
		assert_eq((node as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, node.name)
