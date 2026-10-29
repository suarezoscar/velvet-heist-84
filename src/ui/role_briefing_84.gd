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
var _is_thief: bool = false


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
	_is_thief = actor == map.thief
	var color: Color = TeamMarker3D.THIEF_COLOR if _is_thief else TeamMarker3D.GUARD_COLOR
	var guard_number: int = map.guards.find(actor as GuardController3D) + 1
	title_label.text = "ERES EL LADRÓN" if _is_thief else "ERES EL GUARDIA %d" % guard_number
	title_label.add_theme_color_override("font_color", color)
	_refresh_lines()


## Con encargo, sus líneas (heist.md); si no, las de la cuota. Con red, el encargo llega unos
## instantes después de cargar el mapa: por eso se vuelve a leer mientras la tarjeta está abierta
func _refresh_lines() -> void:
	var clocks: int = get_tree().get_nodes_in_group(&"time_clock").size()
	var lines: Array[String] = []
	if GameManager.heist != null:
		lines = heist_objectives(
			_is_thief,
			_contract_names(),
			GameManager.heist.contract_size,
			_minutes(),
			clocks,
			PlayerName.thief_signature(get_tree())
		)
	else:
		lines = objectives(_is_thief, GameManager.quota_target, _minutes(), clocks)
	var text: String = "\n".join(PackedStringArray(lines))
	if lines_label.text != text:
		lines_label.text = text


## Líneas con encargo: el ladrón ve sus piezas y dónde están; los guardias, la carta
static func heist_objectives(
	is_thief: bool,
	pieces: Array[String],
	size: int,
	minutes: int,
	_clocks: int,
	signature: String = PlayerName.FALLBACK_SIGNATURE
) -> Array[String]:
	if is_thief:
		var contract: String = "• El encargo del coleccionista: aún sin abrir el sobre…"
		if size > 0 and not pieces.is_empty():
			contract = (
				"• El encargo del coleccionista (%d %s): %s."
				% [size, "pieza" if size == 1 else "piezas", ", ".join(PackedStringArray(pieces))]
			)
		return [
			contract,
			"• Con todas encima, sal por cualquier puerta exterior antes de %d minutos." % minutes,
			(
				"• Vitrinas y cajas fuertes se abren con el dial."
				+ " A lo bruto [Q] es rápido, pero salta la alarma."
			),
			"• Nada de violencia: escóndete, engaña y espera tu momento. Un caballero no deja huellas.",
		]
	return [
		(
			"«Esta noche me llevaré %d piezas de su colección. Con mis respetos, %s»"
			% [size, signature]
		),
		(
			"• Parte de la central: las piezas en el punto de mira llevan una marca cian."
			+ " No se sabe cuáles busca."
		),
		(
			"• Atrapadlo con la porra antes de %d minutos. Cada uno tiene su ronda: no la dejéis."
			% minutes
		),
		"• Él ve tu linterna; tú no lo ves a oscuras. Escucha sus pasos.",
	]


func _contract_names() -> Array[String]:
	var names: Array[String] = []
	for piece_id: StringName in GameManager.heist.targets:
		var piece: TargetPiece3D = GameManager.heist.piece(piece_id)
		if piece != null:
			names.append("%s (%s)" % [piece.piece_name, piece.room_name])
	return names


## Líneas del objetivo de cada bando (las usan los tests)
static func objectives(is_thief: bool, quota: int, minutes: int, clocks: int) -> Array[String]:
	if is_thief:
		return [
			"• Llévate piezas por valor de %d y la Pieza Maestra de la cámara acorazada." % quota,
			"• Vuelve al coche antes de %d minutos." % minutes,
			"• La luz y el ruido delatan: un caballero se mueve en la sombra y en silencio.",
			"• Nada de violencia: escóndete, engaña y espera tu momento.",
		]
	return [
		"• Atrapa al ladrón con la porra antes de %d minutos." % minutes,
		"• Ficha los %d relojes a tiempo: con demasiadas faltas, solo te vale atraparlo." % clocks,
		"• Los monitores de la garita muestran lo que ven las cámaras.",
		"• Él ve tu linterna; tú no lo ves a oscuras. Escucha sus pasos.",
	]


func _process(delta: float) -> void:
	if _panel == null or _closing:
		return
	_time_left -= delta
	if GameManager.heist != null:
		_refresh_lines()  # el encargo se sortea (o llega por red) justo después de abrirse
	if GameManager.is_match_over():
		queue_free()  # sin fundido: no debe tapar el panel de fin
	elif _time_left <= 0.0:
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
			"Pulsa cualquier tecla para empezar  ·  Esc: pausa y controles",
			MenuTheme84.FONT_BODY,
			20,
			MenuTheme84.DIM
		)
	)
