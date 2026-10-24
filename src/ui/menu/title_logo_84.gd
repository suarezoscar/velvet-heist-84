## @file title_logo_84.gd
## Logo del menú: «Velvet» en neón manuscrito rosa sobre «HEIST '84» en letra condensada,
## con un parpadeo de tubo de neón de vez en cuando y el lema debajo.
class_name TitleLogo84
extends Control

const FLICKER_MIN_WAIT: float = 3.0
const FLICKER_MAX_WAIT: float = 7.0
const TAGLINE: String = "CADA PASO SE OYE.  CADA SOMBRA CUENTA."

var velvet: Label = null
var heist: Label = null
var _flicker_timer: Timer = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(760.0, 330.0)
	heist = MenuTheme84.label("HEIST '84", MenuTheme84.FONT_DISPLAY, 168, MenuTheme84.TEXT)
	heist.add_theme_constant_override("outline_size", 0)
	heist.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
	heist.add_theme_constant_override("shadow_offset_x", 0)
	heist.add_theme_constant_override("shadow_offset_y", 6)
	heist.position = Vector2(0.0, 92.0)
	add_child(heist)
	velvet = MenuTheme84.label("Velvet", MenuTheme84.FONT_SCRIPT, 150, MenuTheme84.NEON_PINK)
	MenuTheme84.add_glow(velvet, Color(MenuTheme84.NEON_PINK, 0.55), 26)
	velvet.position = Vector2(18.0, -28.0)
	velvet.rotation = deg_to_rad(-6.0)
	add_child(velvet)
	var tagline: Label = MenuTheme84.label(
		TAGLINE, MenuTheme84.FONT_STRONG, 22, MenuTheme84.NEON_CYAN
	)
	tagline.add_theme_constant_override("outline_size", 0)
	MenuTheme84.add_glow(tagline, Color(MenuTheme84.NEON_CYAN, 0.25), 10)
	tagline.position = Vector2(6.0, 286.0)
	add_child(tagline)
	_flicker_timer = Timer.new()
	_flicker_timer.one_shot = true
	_flicker_timer.timeout.connect(_flicker)
	add_child(_flicker_timer)
	_schedule_flicker()


func _schedule_flicker() -> void:
	_flicker_timer.start(randf_range(FLICKER_MIN_WAIT, FLICKER_MAX_WAIT))


## Parpadeo corto del tubo de «Velvet», como un neón viejo
func _flicker() -> void:
	var tween: Tween = create_tween()
	for alpha: float in [0.35, 1.0, 0.55, 1.0]:
		tween.tween_property(velvet, "modulate:a", alpha, 0.05)
	tween.finished.connect(_schedule_flicker)
