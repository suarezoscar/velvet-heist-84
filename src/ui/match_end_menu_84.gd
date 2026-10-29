## @file match_end_menu_84.gd
## Acciones del fin de partida, al pie del informe (MatchReport84, FEAT-041):
## - «REVANCHA» (R): sin red recarga el mapa; con red vota en NetRematch y enseña cuántos
##   jugadores están listos; el servidor relanza con los mismos bandos cuando votan todos;
## - «VOLVER A LA SALA» (solo con red): lleva a todos a la sala de espera para cambiar de
##   bandos, sin desconectar a nadie;
## - «SALIR» (Esc): sale de la red, si la hay, y vuelve al menú principal.
class_name MatchEndMenu84
extends VBoxContainer

## Segundos tras el final en que R y Esc no hacen nada: un Esc por reflejo (salir de la caja
## fuerte) no debe sacarte al menú y romper la revancha de todos
const INPUT_GRACE: float = 0.75
## Segundos tras pedir «VOLVER A LA SALA» en que el botón espera respuesta
const LOBBY_RETRY: float = 2.0

var rematch_button: Button = null
var lobby_button: Button = null
var menu_button: Button = null
var status_label: Label = null
var _map: HeistMap3D = null
var _shown_time: float = 0.0


## Se añade a parent (el pie del informe)
func setup(map: HeistMap3D, parent: Control) -> MatchEndMenu84:
	_map = map
	name = "MatchEndMenu"
	add_theme_constant_override("separation", 10)
	status_label = MenuTheme84.label("", MenuTheme84.FONT_BODY, 20, MenuTheme84.DIM)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(status_label)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	add_child(row)
	rematch_button = _button(row, "REVANCHA  [%s]" % ControlsCatalog.keys(&"rematch"))
	rematch_button.pressed.connect(request_rematch)
	lobby_button = _button(row, "VOLVER A LA SALA")
	lobby_button.pressed.connect(back_to_lobby)
	menu_button = _button(row, "SALIR  [Esc]")
	menu_button.pressed.connect(go_to_menu)
	parent.add_child(self)
	var vote: NetRematch = _vote()
	if vote != null:
		vote.votes_changed.connect(func(_v: int, _n: int) -> void: refresh())
	refresh()
	return self


func _process(delta: float) -> void:
	visible = GameManager.is_match_over()
	_shown_time = _shown_time + delta if visible else 0.0
	if visible:
		refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _shown_time < INPUT_GRACE:
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


## Con red, lleva a todos a la sala de espera
func back_to_lobby() -> void:
	var vote: NetRematch = _vote()
	if vote != null:
		lobby_button.disabled = true
		vote.back_to_lobby()
		# Si el servidor no lo acepta (por ejemplo, alguien aún no estaba listo), se puede repetir
		get_tree().create_timer(LOBBY_RETRY).timeout.connect(
			func() -> void:
				if is_instance_valid(lobby_button):
					lobby_button.disabled = false
		)


## Sale de la red, si la hay, y vuelve al menú principal
func go_to_menu() -> void:
	MenuReturn.to_main_menu(get_tree())


## Estado de los botones y recuento de la revancha con red
func refresh() -> void:
	var vote: NetRematch = _vote()
	lobby_button.visible = vote != null
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
