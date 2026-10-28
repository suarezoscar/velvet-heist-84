## @file match_end_menu_84.gd
## Acciones del panel de fin de partida (FEAT-024): «Revancha» (R) y «Menú principal» (Esc).
## Sin red, la revancha recarga el mapa. Con red, vota en NetRematch y enseña cuántos jugadores
## están listos; el servidor relanza el mapa con los mismos bandos cuando han votado todos.
## La crea HeistMap3D dentro del panel de fin de partida del HUD.
class_name MatchEndMenu84
extends VBoxContainer

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"

var rematch_button: Button = null
var menu_button: Button = null
var status_label: Label = null
var _map: HeistMap3D = null


## Se añade al panel de fin de partida del HUD del mapa
func setup(map: HeistMap3D) -> void:
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
	menu_button = _button(row, "MENÚ PRINCIPAL  [Esc]")
	menu_button.pressed.connect(go_to_menu)
	var panel: Control = map.hud.game_over_panel if map.hud != null else null
	var box: Node = panel.get_node_or_null("VBox") if panel != null else null
	if box != null:
		box.add_child(self)
	var vote: NetRematch = _vote()
	if vote != null:
		vote.votes_changed.connect(func(_v: int, _n: int) -> void: refresh())
	refresh()


func _process(_delta: float) -> void:
	visible = GameManager.is_match_over()
	if visible:
		refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"rematch", false):
		request_rematch()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_cancel", false):
		go_to_menu()
		get_viewport().set_input_as_handled()


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
	if NetManager.is_online():
		NetManager.disconnect_network()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


## Texto y estado de los botones según el recuento de la revancha
func refresh() -> void:
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
		return
	var needed: int = maxi(vote.needed, NetRematch.players_needed(players))
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
