## @file match_report_84.gd
## Informe de la noche (FEAT-041): al acabar la partida ocupa toda la pantalla. Primero un sello
## con lo que ha pasado («ESCAPADO», «CAPTURADO», «AMANECE») durante STAMP_TIME segundos; después
## el veredicto, la ficha del ladrón y la de cada guardia (MatchReportCard84, con sus puntos y
## el sello del mejor de la noche) y las acciones (MatchEndMenu84). Lo monta HeistMap3D y tapa
## el panel de fin del HUD. El informe llega de MatchRecorder (con red, con el estado del final).
class_name MatchReport84
extends CanvasLayer

const STAMP_TIME: float = 1.5
const BACKGROUND: Texture2D = preload("res://assets/ui/menu_background_84.jpg")

var menu: MatchEndMenu84 = null
var stamp_label: Label = null
var verdict_label: Label = null
var facts_label: Label = null
var cards: HBoxContainer = null
var _map: HeistMap3D = null
var _root: Control = null
var _content: VBoxContainer = null
var _over_time: float = 0.0
var _shown_report: Dictionary = {}


## Se añade al mapa, oculto hasta que acaba la partida
func setup(map: HeistMap3D) -> MatchReport84:
	_map = map
	name = "MatchReport"
	layer = 60
	_build()
	map.add_child(self)
	return self


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = MenuTheme84.build()
	_root.visible = false
	add_child(_root)
	var picture: TextureRect = TextureRect.new()
	picture.texture = BACKGROUND
	picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.modulate = Color(0.32, 0.32, 0.38)
	_root.add_child(picture)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(MenuTheme84.INK, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	_root.add_child(margin)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 14)
	margin.add_child(_content)
	_content.add_child(
		MenuTheme84.label("INFORME DE LA NOCHE", MenuTheme84.FONT_STRONG, 22, MenuTheme84.AMBER)
	)
	verdict_label = MenuTheme84.label("", MenuTheme84.FONT_DISPLAY, 84, MenuTheme84.TEXT)
	_content.add_child(verdict_label)
	facts_label = MenuTheme84.label("", MenuTheme84.FONT_BODY, 22, MenuTheme84.DIM)
	_content.add_child(facts_label)
	cards = HBoxContainer.new()
	cards.add_theme_constant_override("separation", 18)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards.alignment = BoxContainer.ALIGNMENT_BEGIN
	_content.add_child(cards)
	menu = MatchEndMenu84.new().setup(_map, _content)
	stamp_label = MenuTheme84.label("", MenuTheme84.FONT_DISPLAY, 190, MenuTheme84.NEON_PINK)
	stamp_label.set_anchors_preset(Control.PRESET_CENTER)
	stamp_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	stamp_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	stamp_label.rotation = deg_to_rad(-9.0)
	stamp_label.add_theme_color_override("font_outline_color", MenuTheme84.INK)
	stamp_label.add_theme_constant_override("outline_size", 18)
	_root.add_child(stamp_label)


## Texto y color del sello según cómo acabó la partida
static func stamp_for(state: GameManager.MatchState) -> Array:
	match state:
		GameManager.MatchState.THIEF_ESCAPED:
			return ["ESCAPADO", TeamMarker3D.THIEF_COLOR]
		GameManager.MatchState.THIEF_CAPTURED:
			return ["CAPTURADO", TeamMarker3D.GUARD_COLOR]
	return ["AMANECE", MenuTheme84.AMBER]


func _process(delta: float) -> void:
	var over: bool = GameManager.is_match_over()
	_root.visible = over
	if not over:
		_over_time = 0.0
		return
	if _map != null and _map.hud != null and _map.hud.game_over_panel != null:
		_map.hud.game_over_panel.visible = false  # el informe lo sustituye
	_over_time += delta
	var stamp: Array = stamp_for(GameManager.current_state)
	stamp_label.text = stamp[0]
	stamp_label.add_theme_color_override("font_color", stamp[1])
	# El sello entra grande y se asienta; luego se queda tenue detrás del informe
	var settle: float = clampf(_over_time / 0.18, 0.0, 1.0)
	stamp_label.scale = Vector2.ONE * lerpf(1.6, 1.0, settle)
	stamp_label.pivot_offset = stamp_label.size * 0.5
	var showing: bool = _over_time >= STAMP_TIME
	stamp_label.modulate.a = 0.16 if showing else 1.0
	_content.visible = showing
	if showing:
		_refresh()


func _refresh() -> void:
	var state: GameManager.MatchState = GameManager.current_state
	verdict_label.text = MatchSummary.verdict(state, MatchSummary.local_side(_map))
	var side: StringName = MatchSummary.winner(state)
	verdict_label.add_theme_color_override(
		"font_color",
		(
			TeamMarker3D.THIEF_COLOR
			if side == &"thief"
			else (TeamMarker3D.GUARD_COLOR if side == &"guards" else MenuTheme84.TEXT)
		)
	)
	var elapsed: float = GameManager.match_duration_seconds - GameManager.match_timer
	var seconds: int = maxi(roundi(elapsed), 0)
	var allowed: int = RoundRules.allowed_faults(
		get_tree().get_nodes_in_group(&"guard_round"), GameManager.CLOCK_RULES.allowed_misses
	)
	facts_label.text = (
		"Duró %d:%02d · Faltas de ronda de la patrulla: %d de %d toleradas"
		% [seconds / 60, seconds % 60, GameManager.round_faults, allowed]
	)
	var recorder: MatchRecorder = MatchRecorder.of(get_tree())
	var report: Dictionary = recorder.report if recorder != null else {}
	if report != _shown_report:
		_shown_report = report.duplicate(true)
		_fill_cards(report)


func _fill_cards(report: Dictionary) -> void:
	for child: Node in cards.get_children():
		child.queue_free()
	if report.is_empty():
		cards.add_child(
			MenuTheme84.label("Recogiendo el informe…", MenuTheme84.FONT_BODY, 22, MenuTheme84.DIM)
		)
		return
	var best: String = MatchScore.best(report)
	var thief_card: MatchReportCard84 = MatchReportCard84.thief(
		report.get("thief", {}), best == "thief"
	)
	thief_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	cards.add_child(thief_card)
	var guards: Array = report.get("guards", [])
	var column: GridContainer = GridContainer.new()
	column.columns = 1 if guards.size() <= 2 else 2
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	column.add_theme_constant_override("h_separation", 14)
	column.add_theme_constant_override("v_separation", 14)
	cards.add_child(column)
	for index: int in range(guards.size()):
		column.add_child(MatchReportCard84.guard(guards[index], index + 1, best == str(index)))
