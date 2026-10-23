## @file offscreen_chevron_84.gd
## Chevron indicador en el borde de la pantalla para ruidos fuera de campo.
class_name OffscreenChevron84
extends Control

var world_pos: Vector3 = Vector3.ZERO
var lifetime: float = 1.0
var time_left: float = 1.0
var chevron_color: Color = Color.WHITE


func _ready() -> void:
	custom_minimum_size = Vector2(16.0, 16.0)
	size = Vector2(16.0, 16.0)
	pivot_offset = Vector2(8.0, 8.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		queue_free()
		return

	var fade_threshold: float = lifetime * 0.4
	if time_left < fade_threshold and fade_threshold > 0.0:
		modulate.a = time_left / fade_threshold
	else:
		modulate.a = 1.0

	_update_edge_transform()
	queue_redraw()


func _update_edge_transform() -> void:
	var vp: Viewport = get_viewport()
	var sz: Vector2 = Vector2(1920.0, 1080.0)
	if vp != null:
		sz = vp.get_visible_rect().size
	if sz.x <= 0.0 or sz.y <= 0.0:
		sz = Vector2(1920.0, 1080.0)
	var center: Vector2 = sz * 0.5
	var dir: Vector2 = Vector2.UP

	var cam: Camera3D = null
	if vp != null:
		cam = vp.get_camera_3d()
	if cam != null:
		var to_pos: Vector2 = cam.unproject_position(world_pos) - center
		if cam.is_position_behind(world_pos):
			to_pos = -to_pos
		if to_pos.length_squared() > 0.001:
			dir = to_pos.normalized()

	var max_d: Vector2 = (center - Vector2(24.0, 24.0)).abs()
	var t_x: float = 1e9
	if absf(dir.x) > 0.0001:
		t_x = max_d.x / absf(dir.x)
	var t_y: float = 1e9
	if absf(dir.y) > 0.0001:
		t_y = max_d.y / absf(dir.y)

	position = center + dir * minf(t_x, t_y) - pivot_offset
	rotation = dir.angle()


func _draw() -> void:
	var points: PackedVector2Array = PackedVector2Array(
		[
			Vector2(2.0, 2.0),
			Vector2(14.0, 8.0),
			Vector2(2.0, 14.0),
		]
	)
	draw_polyline(points, chevron_color, 2.5, true)
