## @file test_cctv_feeds.gd
## Tests del panel de imágenes CCTV del HUD (FEAT-017, interaction.md M2): orden, 4:3,
## alto según feed_height_frac, disposición en fila, redimensionado y marco de alerta.
extends GutTest

const RULES: CCTVRules = preload("res://data/balance/cctv_rules.tres")
const CAMERA_SCENE: PackedScene = preload("res://scenes/entities/security_camera.tscn")
const ASPECT_TOLERANCE: float = 0.005


## Cámaras en desorden a propósito: CAM-2, CAM-1, CAM-3
func _cameras() -> Array[SecurityCamera3D]:
	var cameras: Array[SecurityCamera3D] = []
	var ids: Array[String] = ["CAM-2", "CAM-1", "CAM-3"]
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


func _assert_row(feeds: CCTVFeeds84, view: Vector2) -> void:
	var height: float = RULES.feed_height_frac * view.y
	for i: int in feeds.panel_count():
		var rect: Rect2 = feeds.feed_rect(i)
		assert_almost_eq(rect.size.y, height, 1.0, "Alto %d = feed_height_frac × alto" % i)
		assert_almost_eq(rect.size.x / rect.size.y, 4.0 / 3.0, ASPECT_TOLERANCE, "4:3")
		assert_almost_eq(rect.position.y, 60.0, 0.01, "Borde superior a 60 px")
	var first: Rect2 = feeds.feed_rect(0)
	var last: Rect2 = feeds.feed_rect(feeds.panel_count() - 1)
	assert_almost_eq(first.position.x, view.x - last.end.x, 1.0, "Centrada en horizontal")
	for i: int in range(1, feeds.panel_count()):
		var gap: float = feeds.feed_rect(i).position.x - feeds.feed_rect(i - 1).end.x
		assert_almost_eq(gap, 12.0, 0.01, "12 px entre paneles")


func test_three_panels_sorted_by_id() -> void:
	var feeds: CCTVFeeds84 = _feeds_in(self, _cameras())
	autofree(feeds)
	assert_eq(feeds.panel_count(), 3, "Un panel por cámara")
	assert_true(feeds.label_text(0).begins_with("CAM-1"), "Primero CAM-1")
	assert_eq(feeds.label_text(0), "CAM-1 VESTÍBULO")
	assert_eq(feeds.label_text(1), "CAM-2 GALERÍA")
	assert_eq(feeds.label_text(2), "CAM-3 ALMACÉN")


func test_feeds_are_4_3_and_height_follows_rules() -> void:
	var feeds: CCTVFeeds84 = _feeds_in(self, _cameras())
	autofree(feeds)
	_assert_row(feeds, get_viewport().get_visible_rect().size)


func test_feeds_do_not_overlap() -> void:
	var feeds: CCTVFeeds84 = _feeds_in(self, _cameras())
	autofree(feeds)
	for i: int in feeds.panel_count():
		for j: int in range(i + 1, feeds.panel_count()):
			assert_false(
				feeds.feed_rect(i).intersects(feeds.feed_rect(j)),
				"Imágenes %d y %d solapadas" % [i, j]
			)


func test_known_resolutions() -> void:
	var feeds_1080: CCTVFeeds84 = _feeds_in_viewport(_cameras(), Vector2i(1920, 1080))
	assert_almost_eq(feeds_1080.feed_rect(0).size, Vector2(576.0, 432.0), Vector2(1.0, 1.0))
	_assert_row(feeds_1080, Vector2(1920.0, 1080.0))
	var feeds_720: CCTVFeeds84 = _feeds_in_viewport(_cameras(), Vector2i(1280, 720))
	assert_almost_eq(feeds_720.feed_rect(2).size, Vector2(384.0, 288.0), Vector2(1.0, 1.0))
	_assert_row(feeds_720, Vector2(1280.0, 720.0))


func test_relayout_when_viewport_resizes() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	add_child_autofree(viewport)
	var feeds: CCTVFeeds84 = _feeds_in(viewport, _cameras())
	assert_almost_eq(feeds.feed_rect(0).size.y, 288.0, 1.0)
	viewport.size = Vector2i(1920, 1080)
	assert_almost_eq(feeds.feed_rect(0).size, Vector2(576.0, 432.0), Vector2(1.0, 1.0))
	_assert_row(feeds, Vector2(1920.0, 1080.0))


func test_frame_turns_red_while_camera_detects() -> void:
	var cameras: Array[SecurityCamera3D] = _cameras()
	var feeds: CCTVFeeds84 = _feeds_in(self, cameras)
	autofree(feeds)
	await wait_frames(2)
	for i: int in feeds.panel_count():
		assert_false(feeds.is_frame_alert(i), "Sin alerta al empezar")
	cameras[0].is_alert_active = true  # CAM-2: segundo panel
	await wait_frames(2)
	assert_true(feeds.is_frame_alert(1), "CAM-2 detecta: su marco en rojo")
	assert_false(feeds.is_frame_alert(0), "CAM-1 no detecta")
	assert_false(feeds.is_frame_alert(2), "CAM-3 no detecta")
	cameras[0].is_alert_active = false
	await wait_frames(2)
	assert_false(feeds.is_frame_alert(1), "Al perderlo vuelve al marco gris")


func test_ignores_mouse_everywhere() -> void:
	var feeds: CCTVFeeds84 = _feeds_in(self, _cameras())
	autofree(feeds)
	assert_eq(feeds.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	for node: Node in feeds.find_children("*", "Control", true, false):
		assert_eq((node as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, node.name)
