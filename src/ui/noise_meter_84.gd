## @file noise_meter_84.gd
## Vúmetro analógico retro de nivel de ruido para el HUD de 1984.
## Muestra una barra de 10 segmentos con dinámica de pico/caída y LED de saturación.
class_name NoiseMeter84
extends Control

const SEGMENTS: int = 10
const HUD_PALETTE: HudPalette = preload("res://assets/ui/hud_palette.tres")

@export var palette: HudPalette = HUD_PALETTE
@export var full_scale: float = 10.0
@export var hold_time: float = 0.15
@export var fall_time: float = 0.4
@export var mark_radius: float = 3.5

var level: float = 0.0

var _peak_level: float = 0.0
var _hold_timer: float = 0.0


func _init() -> void:
	custom_minimum_size = Vector2(120.0, 14.0)


func _ready() -> void:
	custom_minimum_size = Vector2(120.0, 14.0)
	if palette == null:
		palette = HUD_PALETTE


## Configura los parámetros de escala y tiempos de respuesta
func configure(full_scale: float, hold_time: float, fall_time: float, mark_radius: float) -> void:
	self.full_scale = full_scale
	self.hold_time = hold_time
	self.fall_time = fall_time
	self.mark_radius = mark_radius
	queue_redraw()


## Nuevo pico: level = max(level, radius) y reinicia la retención
func push(radius: float) -> void:
	level = maxf(level, radius)
	_peak_level = level
	_hold_timer = hold_time
	queue_redraw()


## Metros que muestra actualmente el nivel
func get_level() -> float:
	return level


## Número de segmentos iluminados (0 a 10)
func lit_segments() -> int:
	if full_scale <= 0.0 or level <= 0.0:
		return 0

	var ratio: float = minf(level, full_scale) / full_scale
	return clampi(int(ceil(ratio * float(SEGMENTS))), 0, SEGMENTS)


## Indica si el nivel actual excede la escala máxima
func is_over() -> bool:
	return level > full_scale


func _process(delta: float) -> void:
	if _hold_timer > 0.0:
		_hold_timer -= delta
		if _hold_timer <= 0.0:
			var remaining_delta: float = -_hold_timer
			_hold_timer = 0.0
			_apply_fall(remaining_delta)
		queue_redraw()
	elif level > 0.0:
		_apply_fall(delta)
		queue_redraw()


func _apply_fall(delta: float) -> void:
	if delta <= 0.0:
		return
	if fall_time <= 0.0:
		level = 0.0
		_peak_level = 0.0
		return

	var fall_rate: float = _peak_level / fall_time
	level = maxf(0.0, level - fall_rate * delta)
	if level <= 0.0:
		_peak_level = 0.0


func _draw() -> void:
	var pal: HudPalette = palette if palette != null else HUD_PALETTE
	var h: float = maxf(size.y, 14.0)

	var font: Font = ThemeDB.fallback_font
	var text: String = "RUIDO"
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
	var base_y: float = (h + font.get_ascent(10) - font.get_descent(10)) * 0.5
	var text_col: Color = pal.color_meter_low
	draw_string(font, Vector2(0.0, base_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, text_col)

	var label_gap: float = 6.0
	var seg_start_x: float = text_size.x + label_gap
	var led_w: float = 8.0
	var led_gap: float = 4.0
	var led_x: float = maxf(size.x - led_w, seg_start_x + 30.0)
	var seg_end_x: float = led_x - led_gap
	var total_seg_w: float = maxf(10.0, seg_end_x - seg_start_x)
	var total_gap_w: float = float(SEGMENTS - 1) * 2.0
	var seg_w: float = maxf(1.0, (total_seg_w - total_gap_w) / float(SEGMENTS))

	var lit_count: int = lit_segments()
	for i: int in range(SEGMENTS):
		var x: float = seg_start_x + float(i) * (seg_w + 2.0)
		var c: Color = pal.color_meter_low
		if i >= 9:
			c = pal.color_meter_high
		elif i >= 7:
			c = pal.color_meter_mid

		var is_lit: bool = i < lit_count
		var draw_c: Color = c if is_lit else Color(c.r, c.g, c.b, 0.15)
		draw_rect(Rect2(x, 0.0, seg_w, h), draw_c)

	var led_c: Color = pal.color_meter_high
	var led_draw_c: Color = led_c if is_over() else Color(led_c.r, led_c.g, led_c.b, 0.15)
	draw_rect(Rect2(led_x, 0.0, led_w, h), led_draw_c)

	if full_scale > 0.0 and mark_radius > 0.0:
		var mark_ratio: float = clampf(mark_radius / full_scale, 0.0, 1.0)
		var mark_x: float = seg_start_x + mark_ratio * total_seg_w
		draw_line(Vector2(mark_x, 0.0), Vector2(mark_x, h), Color(1.0, 1.0, 1.0, 0.6), 1.0)
