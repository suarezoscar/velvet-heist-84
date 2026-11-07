## @file role_briefing_84.gd
## Tarjeta de inicio de partida (FEAT-027, rediseñada en #187): rótulo de película de los 80 con
## tu papel, una frase de objetivo y las piezas del encargo como fichas (los guardias, la carta
## del ladrón). Las reglas y la ayuda viven en la pausa (tips). Se cierra sola a los SHOW_TIME
## segundos o con cualquier tecla o clic; no frena la partida ni consume la tecla.
class_name RoleBriefing84
extends CanvasLayer

enum Style { MARQUEE, DOSSIER }

const SHOW_TIME: float = 5.0
const FADE_TIME: float = 0.5
## Entrada del rótulo: el título se enciende como un neón y las fichas llegan una a una
const INTRO_TIME: float = 0.35
const CARD_DELAY: float = 0.12
const PAPER: Color = Color("d9cfb8")
const PAPER_INK: Color = Color("1d1a17")
const STAMP_RED: Color = Color("b3261e")

## Estilo de la tarjeta (el expediente solo se usa para comparar en el prototipo de #187)
static var style: Style = Style.MARQUEE

var title_label: Label = null
var headline_label: Label = null
var cards_box: HBoxContainer = null
var _panel: Control = null
var _time_left: float = SHOW_TIME
var _closing: bool = false
var _is_thief: bool = false
var _shown_cards: String = "-"


## Prepara la tarjeta para el actor local del mapa (sin actor local no se enseña)
func setup(map: HeistMap3D) -> void:
	name = "RoleBriefing"
	layer = 55
	map.add_child(self)
	var actor: PlayerBase3D = map.local_player
	if actor == null:
		queue_free()
		return
	_is_thief = actor == map.thief
	var guard_number: int = map.guards.find(actor as GuardController3D) + 1
	var title: String = "ERES EL LADRÓN" if _is_thief else "ERES EL GUARDIA %d" % guard_number
	var color: Color = TeamMarker3D.THIEF_COLOR if _is_thief else TeamMarker3D.GUARD_COLOR
	if style == Style.DOSSIER:
		_build_dossier(title)
	else:
		_build_marquee(title, color)
	_refresh()
	_intro()


## Frase de objetivo. Con encargo (heist.md) y sin él (cuota); size 0: el encargo aún no ha llegado
static func headline(is_thief: bool, size: int, minutes: int, quota: int = 0) -> String:
	if quota > 0:
		if is_thief:
			return (
				"Llévate piezas por valor de %d y la Pieza Maestra, y vuelve al coche antes de %d minutos."
				% [quota, minutes]
			)
		return "Atrapa al ladrón con la porra antes de %d minutos." % minutes
	if not is_thief:
		return (
			"Atrapad al ladrón con la porra antes de %d minutos: si amanece dentro, ganáis."
			% minutes
		)
	if size <= 0:
		return "El encargo del coleccionista está al llegar…"
	return (
		"Llévate %s del encargo y sal por cualquier puerta exterior antes de %d minutos."
		% ["la pieza" if size == 1 else "las %d piezas" % size, minutes]
	)


## La carta del ladrón que reciben los guardias
static func letter(size: int, signature: String = PlayerName.FALLBACK_SIGNATURE) -> String:
	return (
		"«Esta noche me llevaré %d piezas de su colección. Con mis respetos, %s»"
		% [size, signature]
	)


## Lo esencial de cada papel, para la pausa
static func tips(is_thief: bool) -> Array[String]:
	if is_thief:
		return [
			"Cada pieza se roba allí mismo con [E]: el dial, el cambiazo o el sensor.",
			"A lo bruto [Q] es rápido, pero salta la alarma.",
			"La luz y el ruido delatan: muévete en la sombra y en silencio.",
			"Nada de violencia: escóndete, engaña y espera tu momento. Un caballero no deja huellas.",
		]
	return [
		"Parte de la central: las piezas en el punto de mira llevan una marca cian.",
		"Fuera de la garita entra sueño; el café de la garita lo quita.",
		"Él ve tu linterna; tú no lo ves a oscuras. Escucha sus pasos.",
	]


## Con red, el encargo llega unos instantes después de cargar el mapa: se vuelve a leer
func _refresh() -> void:
	var minutes: int = roundi(GameManager.match_duration_seconds / 60.0)
	var size: int = 0
	var cards: Array = []
	if GameManager.heist != null:
		size = GameManager.heist.contract_size
		if _is_thief:
			cards = _contract_pieces()
			if cards.size() < size:
				size = 0  # el sorteo aún no ha llegado entero
		else:
			cards = [[letter(size, PlayerName.thief_signature(get_tree())), ""]]
		headline_label.text = headline(_is_thief, size, minutes)
	else:
		headline_label.text = headline(_is_thief, 0, minutes, GameManager.quota_target)
	var key: String = str(cards)
	if key != _shown_cards:
		_shown_cards = key
		_fill_cards(cards)


func _contract_pieces() -> Array:
	var out: Array = []
	for piece_id: StringName in GameManager.heist.targets:
		var piece: TargetPiece3D = GameManager.heist.piece(piece_id)
		if piece != null:
			out.append([piece.piece_name, piece.room_name])
	return out


func _process(delta: float) -> void:
	if _panel == null or _closing:
		return
	_time_left -= delta
	if GameManager.heist != null:
		_refresh()
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
	MatchCountdown.begin(get_tree())  # #165: sin red, el 3-2-1 empieza al cerrar la tarjeta
	var tween: Tween = create_tween()
	tween.tween_property(_panel, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(queue_free)


## El título se enciende con un parpadeo de neón y el resto aparece detrás
func _intro() -> void:
	if style == Style.DOSSIER:
		return
	title_label.modulate.a = 0.0
	headline_label.modulate.a = 0.0
	var tween: Tween = create_tween()
	for alpha: float in [1.0, 0.25, 1.0, 0.5, 1.0]:
		tween.tween_property(title_label, "modulate:a", alpha, INTRO_TIME / 5.0)
	tween.tween_property(headline_label, "modulate:a", 1.0, INTRO_TIME)


func _fill_cards(cards: Array) -> void:
	for child: Node in cards_box.get_children():
		child.queue_free()
	var index: int = 0
	for card: Array in cards:
		var node: Control = _card(String(card[0]), String(card[1]))
		cards_box.add_child(node)
		if style == Style.MARQUEE:
			node.modulate.a = 0.0
			var tween: Tween = create_tween()
			tween.tween_interval(INTRO_TIME + CARD_DELAY * index)
			tween.tween_property(node, "modulate:a", 1.0, 0.25)
		index += 1


func _card(title: String, room: String) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dossier: bool = style == Style.DOSSIER
	var accent: Color = PAPER_INK if dossier else MenuTheme84.NEON_PINK
	var bg: Color = Color(PAPER_INK, 0.06) if dossier else Color(MenuTheme84.INK, 0.6)
	var box_style: StyleBoxFlat = MenuTheme84.box(bg, Color(accent, 0.7), 1 if dossier else 2)
	box_style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", box_style)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	var font: Font = MenuTheme84.FONT_MONO if dossier else MenuTheme84.FONT_STRONG
	var ink: Color = PAPER_INK if dossier else MenuTheme84.TEXT
	var name_label: Label = MenuTheme84.label(title, font, 24, ink)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(220.0 if room != "" else 640.0, 0.0)
	box.add_child(name_label)
	if room != "":
		var dim: Color = Color(PAPER_INK, 0.6) if dossier else MenuTheme84.DIM
		box.add_child(MenuTheme84.label(room.to_upper(), MenuTheme84.FONT_MONO, 16, dim))
	return panel


## Rótulo: una franja oscura a lo ancho, con el título en neón, la frase y las fichas
func _build_marquee(title: String, color: Color) -> void:
	var band: PanelContainer = PanelContainer.new()
	band.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	band.anchor_left = 0.0
	band.anchor_right = 1.0
	band.grow_vertical = Control.GROW_DIRECTION_BOTH
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var band_style: StyleBoxFlat = StyleBoxFlat.new()
	band_style.bg_color = Color(MenuTheme84.INK, 0.82)
	band_style.border_color = Color(color, 0.8)
	band_style.border_width_top = 2
	band_style.border_width_bottom = 2
	band_style.content_margin_top = 26
	band_style.content_margin_bottom = 26
	band.add_theme_stylebox_override("panel", band_style)
	add_child(band)
	_panel = band
	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	band.add_child(box)
	var eyebrow: Label = MenuTheme84.label("ESTA NOCHE", MenuTheme84.FONT_MONO, 18, MenuTheme84.DIM)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(eyebrow)
	title_label = MenuTheme84.label(title, MenuTheme84.FONT_DISPLAY, 96, color)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	MenuTheme84.add_glow(title_label, Color(color, 0.6), 18)
	box.add_child(title_label)
	headline_label = MenuTheme84.label("", MenuTheme84.FONT_BODY, 28, MenuTheme84.TEXT)
	headline_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(headline_label)
	cards_box = HBoxContainer.new()
	cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_box.add_theme_constant_override("separation", 14)
	box.add_child(cards_box)
	var hint: Label = MenuTheme84.label(
		"Cualquier tecla para empezar  ·  Esc: pausa, reglas y controles",
		MenuTheme84.FONT_BODY,
		18,
		MenuTheme84.DIM
	)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


## Expediente (solo para comparar en el prototipo): papel, máquina de escribir y sello
func _build_dossier(title: String) -> void:
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var paper: PanelContainer = PanelContainer.new()
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper_style: StyleBoxFlat = MenuTheme84.box(PAPER, Color(PAPER_INK, 0.4), 1)
	paper_style.set_content_margin_all(30)
	paper.add_theme_stylebox_override("panel", paper_style)
	center.add_child(paper)
	_panel = paper
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	paper.add_child(box)
	box.add_child(MenuTheme84.label("EXPEDIENTE Nº 84-0711", MenuTheme84.FONT_MONO, 18, PAPER_INK))
	title_label = MenuTheme84.label(title, MenuTheme84.FONT_DISPLAY, 64, PAPER_INK)
	box.add_child(title_label)
	headline_label = MenuTheme84.label("", MenuTheme84.FONT_MONO, 22, PAPER_INK)
	headline_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	headline_label.custom_minimum_size = Vector2(720.0, 0.0)
	box.add_child(headline_label)
	cards_box = HBoxContainer.new()
	cards_box.add_theme_constant_override("separation", 12)
	box.add_child(cards_box)
	var overlay: Control = Control.new()  # el sello va encima, sin entrar en el reparto
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_child(overlay)
	var stamp: Label = MenuTheme84.label("CONFIDENCIAL", MenuTheme84.FONT_DISPLAY, 54, STAMP_RED)
	stamp.rotation_degrees = -12.0
	stamp.modulate.a = 0.75
	stamp.position = Vector2(440.0, 14.0)
	overlay.add_child(stamp)
