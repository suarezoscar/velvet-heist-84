## @file role_briefing_84.gd
## Tarjeta de objetivo al empezar la partida (FEAT-027): quién eres y qué tienes que hacer,
## con las cifras de la partida (cuota, tiempo, relojes). Se cierra sola a los SHOW_TIME
## segundos o con cualquier tecla o clic; no frena la partida ni consume la tecla.
class_name RoleBriefing84
extends CanvasLayer

const SHOW_TIME: float = 8.0
const FADE_TIME: float = 0.6

var title_label: Label = null
var lines_label: Label = null
var _panel: PanelContainer = null
var _time_left: float = SHOW_TIME
var _closing: bool = false


## Prepara la tarjeta para el actor local del mapa (sin actor local no se enseña)
func setup(map: HeistMap3D) -> void:
	name = "RoleBriefing"
	layer = 55
	map.add_child(self)
	var actor: PlayerBase3D = map.local_player
	if actor == null:
		queue_free()
		return
	_build()
	var is_thief: bool = actor == map.thief
	var color: Color = TeamMarker3D.THIEF_COLOR if is_thief else TeamMarker3D.GUARD_COLOR
	var guard_number: int = map.guards.find(actor as GuardController3D) + 1
	title_label.text = "ERES EL LADRÓN" if is_thief else "ERES EL GUARDIA %d" % guard_number
	title_label.add_theme_color_override("font_color", color)
	var clocks: int = get_tree().get_nodes_in_group(&"time_clock").size()
	lines_label.text = "\n".join(
		PackedStringArray(objectives(is_thief, GameManager.quota_target, _minutes(), clocks))
	)


## Líneas del objetivo de cada bando (las usan los tests)
static func objectives(is_thief: bool, quota: int, minutes: int, clocks: int) -> Array[String]:
	if is_thief:
		return [
			"• Roba $%d en botín y la Pieza Maestra de la cámara acorazada." % quota,
			"• Vuelve al coche antes de %d minutos." % minutes,
			"• La luz y el ruido te delatan: busca la sombra y muévete en sigilo.",
			"• Nunca atacas: escóndete, engaña y espera tu momento.",
		]
	return [
		"• Atrapa al ladrón con la porra antes de %d minutos." % minutes,
		(
			"• Ficha los %d relojes antes de que se agoten: con demasiadas faltas solo os vale atraparlo."
			% clocks
		),
		"• Los monitores de la garita muestran lo que ven las cámaras.",
		"• Él ve tu linterna; tú no lo ves a oscuras. Escucha sus pasos.",
	]


func _process(delta: float) -> void:
	if _panel == null or _closing:
		return
	_time_left -= delta
	if _time_left <= 0.0 or GameManager.is_match_over():
		close()


func _input(event: InputEvent) -> void:
	var pressed: bool = (
		# Una pulsación nueva: mantener una tecla de movimiento no la cierra antes de leerla
		(event is InputEventKey and event.is_pressed() and not (event as InputEventKey).echo)
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
	)
	if pressed and _panel != null and _time_left < SHOW_TIME - 0.5:
		close()


func close() -> void:
	if _closing:
		return
	_closing = true
	var tween: Tween = create_tween()
	tween.tween_property(_panel, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(queue_free)


func _minutes() -> int:
	return roundi(GameManager.match_duration_seconds / 60.0)


func _build() -> void:
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = MenuTheme84.box(
		Color(MenuTheme84.INK, 0.88), Color(MenuTheme84.TEXT, 0.25), 2
	)
	style.set_content_margin_all(28)
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_panel.add_child(box)
	title_label = MenuTheme84.label("", MenuTheme84.FONT_DISPLAY, 64, MenuTheme84.TEXT)
	box.add_child(title_label)
	lines_label = MenuTheme84.label("", MenuTheme84.FONT_BODY, 26, MenuTheme84.TEXT)
	lines_label.custom_minimum_size = Vector2(760.0, 0.0)
	lines_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(lines_label)
	box.add_child(
		MenuTheme84.label(
			"Pulsa cualquier tecla para cerrar  ·  Esc: pausa y controles",
			MenuTheme84.FONT_BODY,
			20,
			MenuTheme84.DIM
		)
	)
