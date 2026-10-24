## @file lobby_view.gd
## Vista del lobby online: conexión por IP y puerto a un servidor dedicado,
## elección de rol, lista de jugadores e inicio de partida.
class_name LobbyView
extends Control

## Se emite al pulsar "Volver" (ya desconectado) para que el menú cambie de vista.
signal back_requested

const HELP_TEXT: String = "Arranca el servidor con tools/net/run_server.sh en un PC de la red"
const HELP_TAIL: String = " y únete con su IP"
const COLOR_AMBER: Color = Color(1.0, 0.85, 0.35, 1.0)
const COLOR_CYAN: Color = Color(0.35, 0.9, 0.85, 1.0)
const COLOR_GREEN: Color = Color(0.4, 0.95, 0.5, 1.0)
const COLOR_RED: Color = Color(1.0, 0.35, 0.25, 0.9)
const COLOR_DIM: Color = Color(0.7, 0.75, 0.8, 0.7)
const COLOR_TEXT: Color = Color(0.9, 0.95, 1.0, 1.0)

@onready var lobby_title_lbl: Label = $HeaderBox/LobbyTitleLabel
@onready var lobby_status_lbl: Label = $HeaderBox/LobbyStatusLabel
@onready var ip_edit: LineEdit = $ColumnsHBox/ConnectionPanel/VBox/IpEdit
@onready var port_edit: LineEdit = $ColumnsHBox/ConnectionPanel/VBox/PortEdit
@onready var host_btn: Button = $ColumnsHBox/ConnectionPanel/VBox/HostButton
@onready var join_btn: Button = $ColumnsHBox/ConnectionPanel/VBox/JoinButton
@onready var disconnect_btn: Button = $ColumnsHBox/ConnectionPanel/VBox/DisconnectButton
@onready var conn_log_lbl: Label = $ColumnsHBox/ConnectionPanel/VBox/ConnectionLogLabel
@onready var role_thief_btn: Button = $ColumnsHBox/RolesPanel/VBox/RoleThiefButton
@onready var role_guard1_btn: Button = $ColumnsHBox/RolesPanel/VBox/RoleGuard1Button
@onready var role_guard2_btn: Button = $ColumnsHBox/RolesPanel/VBox/RoleGuard2Button
@onready var current_role_lbl: Label = $ColumnsHBox/RolesPanel/VBox/CurrentRoleInfoLabel
@onready var players_box: VBoxContainer = $ColumnsHBox/PlayersPanel/VBox/Scroll/PlayersListContainer
@onready var lobby_back_btn: Button = $BottomActionsHBox/LobbyBackButton
@onready var start_match_btn: Button = $BottomActionsHBox/StartMatchButton


func _ready() -> void:
	host_btn.visible = false  # start_host devuelve ERR_UNAVAILABLE: solo servidor dedicado
	conn_log_lbl.text = HELP_TEXT + HELP_TAIL
	join_btn.pressed.connect(_on_join_pressed)
	disconnect_btn.pressed.connect(_on_disconnect_pressed)
	lobby_back_btn.pressed.connect(_on_back_pressed)
	start_match_btn.pressed.connect(_on_start_match_pressed)
	role_thief_btn.pressed.connect(_on_role_btn_pressed.bind(NetManagerNode.ROLE_THIEF))
	role_guard1_btn.pressed.connect(_on_role_btn_pressed.bind(NetManagerNode.ROLE_GUARD_1))
	role_guard2_btn.pressed.connect(_on_role_btn_pressed.bind(NetManagerNode.ROLE_GUARD_2))
	NetManager.connection_succeeded.connect(_on_connection_succeeded)
	NetManager.connection_failed.connect(_on_connection_failed)
	NetManager.server_disconnected.connect(_on_server_disconnected)
	NetManager.player_list_updated.connect(refresh)


## Vuelve a pintar la vista con el estado actual de NetManager.
func refresh() -> void:
	if not is_inside_tree():
		return
	var online: bool = NetManager.is_online()
	lobby_title_lbl.text = "SALA DE TRANSMISIÓN ANALÓGICA — FRECUENCIA %d" % _get_port_input()
	join_btn.disabled = online
	disconnect_btn.disabled = not online
	ip_edit.editable = not online
	port_edit.editable = not online
	if not online:
		lobby_status_lbl.text = "ESTADO: DESCONECTADO"
		lobby_status_lbl.modulate = COLOR_DIM
	else:
		lobby_status_lbl.text = "ESTADO: CONECTADO COMO CLIENTE"
		lobby_status_lbl.modulate = COLOR_CYAN
	start_match_btn.disabled = _get_role_occupant(NetManagerNode.ROLE_THIEF) == 0

	var local_role: StringName = NetManager.get_local_role()
	if local_role == &"":
		current_role_lbl.text = "TU FRECUENCIA ASIGNADA: NINGUNA"
		current_role_lbl.modulate = COLOR_DIM
	else:
		current_role_lbl.text = "TU FRECUENCIA ASIGNADA: %s" % _format_role_name(local_role)
		current_role_lbl.modulate = COLOR_GREEN
	_update_role_button(role_thief_btn, NetManagerNode.ROLE_THIEF, "INFILTRADO (LADRÓN)")
	_update_role_button(role_guard1_btn, NetManagerNode.ROLE_GUARD_1, "GUARDIA 1")
	_update_role_button(role_guard2_btn, NetManagerNode.ROLE_GUARD_2, "GUARDIA 2")
	_populate_players_list()


func _on_join_pressed() -> void:
	var ip: String = ip_edit.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	var port: int = _get_port_input()
	conn_log_lbl.text = "SINTONIZANDO REPETIDOR EN %s:%d..." % [ip, port]
	var err: Error = NetManager.join_server(ip, port)
	if err != OK:
		conn_log_lbl.text = "ERROR AL CONECTAR A %s:%d: %s" % [ip, port, error_string(err)]
	refresh()


func _on_disconnect_pressed() -> void:
	NetManager.disconnect_network()
	conn_log_lbl.text = "DESCONECTADO DE LA FRECUENCIA DE RADIO."
	refresh()


func _on_role_btn_pressed(role: StringName) -> void:
	if not NetManager.request_role(role):
		conn_log_lbl.text = "ROL %s NO DISPONIBLE O RECHAZADO POR CENTRAL." % role
	refresh()


func _on_start_match_pressed() -> void:
	conn_log_lbl.text = "LANZANDO OPERACIÓN MULTIJUGADOR..."
	NetManager.request_start()


func _on_back_pressed() -> void:
	NetManager.disconnect_network()
	back_requested.emit()


func _on_connection_succeeded() -> void:
	conn_log_lbl.text = "SINTONIZADO A FRECUENCIA CON ÉXITO."
	refresh()


func _on_connection_failed() -> void:
	conn_log_lbl.text = "FALLO AL SINTONIZAR FRECUENCIA CON EL SERVIDOR."
	refresh()


func _on_server_disconnected() -> void:
	conn_log_lbl.text = "SEÑAL PERDIDA: DESCONECTADO DEL SERVIDOR."
	refresh()


## Devuelve el peer que ocupa el rol, o 0 si está libre.
func _get_role_occupant(role: StringName) -> int:
	var players: Dictionary = NetManager.get_connected_players()
	for pid: int in players:
		if (players[pid] as Dictionary).get("role") == role:
			return pid
	return 0


func _update_role_button(btn: Button, role: StringName, role_label: String) -> void:
	if NetManager.get_local_role() == role:
		btn.text = "✔  %s  [TU ROL ACTUAL]" % role_label
		btn.modulate = COLOR_GREEN
		btn.disabled = false
	elif NetManager.is_role_available(role):
		btn.text = "○  %s  [DISPONIBLE]" % role_label
		btn.modulate = COLOR_TEXT
		btn.disabled = false
	else:
		var pid: int = _get_role_occupant(role)
		var info: Dictionary = NetManager.get_connected_players().get(pid, {})
		var occupant: String = info.get("name", "Agente_%d" % pid) if pid != 0 else "OTRO AGENTE"
		btn.text = "✕  %s  [OCUPADO: %s]" % [role_label, occupant]
		btn.modulate = COLOR_RED
		btn.disabled = true


func _populate_players_list() -> void:
	for child in players_box.get_children():
		players_box.remove_child(child)
		child.queue_free()
	var players: Dictionary = NetManager.get_connected_players()
	if players.is_empty():
		var empty_lbl: Label = Label.new()
		empty_lbl.text = "[ SIN EMISIONES DETECTADAS — FRECUENCIA EN ESPERA ]"
		empty_lbl.modulate = COLOR_DIM
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		players_box.add_child(empty_lbl)
		return
	var my_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	for pid: int in players:
		players_box.add_child(_build_player_row(pid, players[pid], pid == my_id))


func _build_player_row(pid: int, info: Dictionary, is_me: bool) -> PanelContainer:
	var p_role: StringName = info.get("role", &"")
	var row: PanelContainer = PanelContainer.new()
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	for side: String in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 4)
	row.add_child(margin)
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	margin.add_child(hbox)

	var indicator: Label = Label.new()
	indicator.text = "●"
	indicator.modulate = COLOR_GREEN if is_me else COLOR_CYAN
	hbox.add_child(indicator)

	var name_lbl: Label = Label.new()
	var host_tag: String = " [HOST]" if pid == 1 else ""
	var me_tag: String = " [TÚ]" if is_me else ""
	name_lbl.text = "%s%s%s" % [info.get("name", "Agente_%d" % pid), host_tag, me_tag]
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.modulate = COLOR_AMBER if is_me else COLOR_TEXT
	hbox.add_child(name_lbl)

	var role_lbl: Label = Label.new()
	role_lbl.text = _format_role_name(p_role)
	role_lbl.modulate = (
		COLOR_CYAN if p_role == NetManagerNode.ROLE_THIEF else Color(0.85, 0.75, 0.95, 1.0)
	)
	hbox.add_child(role_lbl)
	return row


func _format_role_name(role: StringName) -> String:
	match role:
		NetManagerNode.ROLE_THIEF:
			return "INFILTRADO (LADRÓN)"
		NetManagerNode.ROLE_GUARD_1:
			return "GUARDIA 1"
		NetManagerNode.ROLE_GUARD_2:
			return "GUARDIA 2"
		_:
			return "SIN ROL ASIGNADO"


func _get_port_input() -> int:
	var port_str: String = port_edit.text.strip_edges()
	var port: int = port_str.to_int() if not port_str.is_empty() else NetManagerNode.DEFAULT_PORT
	return port if port > 0 else NetManagerNode.DEFAULT_PORT
