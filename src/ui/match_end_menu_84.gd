## @file match_end_menu_84.gd
## Panel de fin de partida: resumen (FEAT-027: has ganado o perdido y las cifras) y acciones
## (FEAT-024): «Revancha» (R) y «Menú principal» (Esc).
## Sin red, la revancha recarga el mapa. Con red, vota en NetRematch y enseña cuántos jugadores
## están listos; el servidor relanza el mapa con los mismos bandos cuando han votado todos.
## La crea HeistMap3D dentro del panel de fin de partida del HUD.
class_name MatchEndMenu84
extends VBoxContainer

## Segundos tras el final en que R y Esc no hacen nada: un Esc por reflejo (salir de la caja
## fuerte) no debe sacarte al menú y romper la revancha de todos
const INPUT_GRACE: float = 0.75

var rematch_button: Button = null
var menu_button: Button = null
var status_label: Label = null
var verdict_label: Label = null
var stats_label: Label = null
var _map: HeistMap3D = null
var _shown_time: float = 0.0


## Se añade al panel de fin de partida del HUD del mapa
func setup(map: HeistMap3D) -> void:
	_map = map
	name = "MatchEndMenu"
	add_theme_constant_override("separation", 10)
	verdict_label = MenuTheme84.label("", MenuTheme84.FONT_DISPLAY, 56, MenuTheme84.TEXT)
	verdict_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label = MenuTheme84.label("", MenuTheme84.FONT_MONO, 20, MenuTheme84.TEXT)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(stats_label)
	status_label = MenuTheme84.label("", MenuTheme84.FONT_BODY, 20, MenuTheme84.DIM)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(status_label)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	add_child(row)
	rematch_button = _button(row, "REVANCHA  [%s]" % ControlsCatalog.keys(&"rematch"))
	rematch_button.pressed.connect(request_rematch)
	menu_button = _button(row, "MENÚ PRINCIPAL  [Esc]")
	menu_button.pressed.connect(go_to_menu)
	var panel: Control = map.hud.game_over_panel if map.hud != null else null
	var box: Node = panel.get_node_or_null("VBox") if panel != null else null
	# Veredicto arriba, después el motivo del HUD y debajo las cifras y los botones
	if box != null:
		box.add_child(verdict_label)
		box.move_child(verdict_label, 0)
		box.add_child(self)
		var style: StyleBoxFlat = MenuTheme84.box(
			Color(MenuTheme84.INK, 0.92), Color(MenuTheme84.TEXT, 0.25), 2
		)
		style.set_content_margin_all(28)
		panel.add_theme_stylebox_override("panel", style)
	var vote: NetRematch = _vote()
	if vote != null:
		vote.votes_changed.connect(func(_v: int, _n: int) -> void: refresh())
	refresh()


func _process(delta: float) -> void:
	visible = GameManager.is_match_over()
	_shown_time = _shown_time + delta if visible else 0.0
	if visible:
		refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _shown_time < INPUT_GRACE:
		return
	# Antes de cambiar de escena: después ya no hay viewport
	if event.is_action_pressed(&"rematch", false):
		get_viewport().set_input_as_handled()
		request_rematch()
	elif event.is_action_pressed(&"ui_cancel", false):
		get_viewport().set_input_as_handled()
		go_to_menu()


## Sin red recarga el mapa; con red vota la revancha (o retira el voto)
func request_rematch() -> void:
	var vote: NetRematch = _vote()
	if vote == null:
		get_tree().reload_current_scene()
		return
	if rematch_button.disabled:
		return
	vote.vote(not vote.has_voted())


## Sale de la red, si la hay, y vuelve al menú principal
func go_to_menu() -> void:
	MenuReturn.to_main_menu(get_tree())


## Veredicto, cifras y estado de los botones (recuento de la revancha con red)
func refresh() -> void:
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
	var allowed: int = GameManager.CLOCK_RULES.allowed_misses
	if GameManager.heist != null:
		stats_label.text = MatchSummary.heist_stats(
			GameManager.heist, elapsed, GameManager.round_faults, allowed
		)
	else:
		stats_label.text = MatchSummary.stats(
			GameManager.current_loot_value,
			GameManager.quota_target,
			GameManager.has_masterpiece,
			elapsed,
			GameManager.round_faults,
			allowed
		)
	var vote: NetRematch = _vote()
	if vote == null:
		status_label.visible = false
		return
	status_label.visible = true
	var players: Dictionary = NetManager.get_connected_players()
	var possible: bool = NetRoleRegistry.can_start(players)
	rematch_button.disabled = not possible
	if not possible:
		status_label.text = "Falta el ladrón o un guardia: no hay revancha"
		rematch_button.text = "REVANCHA  [%s]" % ControlsCatalog.keys(&"rematch")
		return
	var needed: int = vote.needed if vote.needed > 0 else NetRematch.players_needed(players)
	status_label.text = "Revancha: %d de %d listos" % [vote.voters.size(), needed]
	rematch_button.text = (
		"CANCELAR REVANCHA  [%s]" % ControlsCatalog.keys(&"rematch")
		if vote.has_voted()
		else "REVANCHA  [%s]" % ControlsCatalog.keys(&"rematch")
	)


func _vote() -> NetRematch:
	if _map == null or not NetManager.is_online():
		return null
	var session: NetSession = _map.get_node_or_null("NetSession") as NetSession
	return session.rematch if session != null else null


func _button(row: HBoxContainer, text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.theme = MenuTheme84.build()
	button.focus_mode = Control.FOCUS_NONE
	row.add_child(button)
	return button
