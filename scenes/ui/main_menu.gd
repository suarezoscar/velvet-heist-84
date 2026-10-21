## @file main_menu.gd
## Menú principal de inicio para 'Velvet Heist 84'.
## Controla la navegación del título, selección interactiva de mapas/escenarios,
## previsualización de fichas de misión e interfaz de lobby multijugador online.
class_name MainMenu
extends Control

## Datos de escenarios disponibles para la campaña / selección offline
const SCENARIOS: Array[Dictionary] = [
	{
		"id": "museum",
		"title": "MUSEO METROPOLITANO '84",
		"subtitle": "Operación Asimétrica (1 Ladrón vs 2 Guardias)",
		"desc":
		(
			"Infiltra las galerías de arte, evade las cámaras CCTV en tiempo real "
			+ "y burla a los dos guardias para saquear la cámara acorazada."
		),
		"scene_path": "res://scenes/maps/museum_velvet_84.tscn",
		"thumb": "res://assets/ui/thumb_museum.png",
		"difficulty": "ALTA • CCTV EN DIRECTO • 2 GUARDIAS",
		"badge_color": Color(1.0, 0.35, 0.25)
	},
	{
		"id": "mansion",
		"title": "VILLA BELMONTE '84",
		"subtitle": "Infiltración Clásica en Mansión",
		"desc":
		(
			"Residencia de época con suelos de mármol resonante y parqué. "
			+ "Localiza la caja fuerte de combinación analógica y escapa."
		),
		"scene_path": "res://scenes/maps/mansion_belmonte.tscn",
		"thumb": "res://assets/ui/thumb_mansion.png",
		"difficulty": "MEDIA • 1 GUARDIA DE RONDA",
		"badge_color": Color(0.3, 0.75, 1.0)
	},
	{
		"id": "gym",
		"title": "GIMNASIO ACÚSTICO '84",
		"subtitle": "Campo de Entrenamiento de Sigilo",
		"desc":
		(
			"Entorno de calibración táctica para experimentar con la propagación "
			+ "de ondas sonoras en 3D, pisadas según superficie y conos de visión."
		),
		"scene_path": "res://scenes/maps/test_isometric_gym.tscn",
		"thumb": "res://assets/ui/thumb_museum.png",
		"difficulty": "PRÁCTICA Y MECÁNICAS",
		"badge_color": Color(0.4, 0.95, 0.5)
	}
]

## Colores analógicos CRT para estados de lobby
const COLOR_AMBER: Color = Color(1.0, 0.85, 0.35, 1.0)
const COLOR_CYAN: Color = Color(0.35, 0.9, 0.85, 1.0)
const COLOR_GREEN: Color = Color(0.4, 0.95, 0.5, 1.0)
const COLOR_RED: Color = Color(1.0, 0.35, 0.25, 0.9)
const COLOR_DIM: Color = Color(0.7, 0.75, 0.8, 0.7)

var scenario_thumb_rect: TextureRect = null
var players_list_container: VBoxContainer = null
var _selected_idx: int = 0

# --- Nodos de Vistas Principales ---
@onready var main_view: Control = $MainView
@onready var scenario_view: Control = $ScenarioView
@onready var lobby_view: Control = $LobbyView

# --- Botones de MainView ---
@onready var quick_play_btn: Button = $MainView/ButtonsBox/QuickPlayButton
@onready var select_stage_btn: Button = $MainView/ButtonsBox/SelectStageButton
@onready var online_btn: Button = $MainView/ButtonsBox/OnlineButton
@onready var quit_btn: Button = $MainView/ButtonsBox/QuitButton

# --- Controles de ScenarioView ---
@onready var back_btn: Button = $ScenarioView/BackButton
@onready var scenario_title_lbl: Label = $ScenarioView/ContentHBox/DetailsPanel/VBox/TitleLabel
@onready var scenario_sub_lbl: Label = $ScenarioView/ContentHBox/DetailsPanel/VBox/SubLabel
@onready var scenario_desc_lbl: Label = $ScenarioView/ContentHBox/DetailsPanel/VBox/DescLabel
@onready var scenario_diff_lbl: Label = $ScenarioView/ContentHBox/DetailsPanel/VBox/DifficultyLabel
@onready var launch_btn: Button = $ScenarioView/ContentHBox/DetailsPanel/VBox/LaunchButton
@onready var list_container: VBoxContainer = $ScenarioView/ContentHBox/ListPanel/Scroll/VBox

# --- Controles de LobbyView ---
@onready var lobby_title_lbl: Label = $LobbyView/HeaderBox/LobbyTitleLabel
@onready var lobby_status_lbl: Label = $LobbyView/HeaderBox/LobbyStatusLabel
@onready var ip_edit: LineEdit = $LobbyView/ColumnsHBox/ConnectionPanel/VBox/IpEdit
@onready var port_edit: LineEdit = $LobbyView/ColumnsHBox/ConnectionPanel/VBox/PortEdit
@onready var host_btn: Button = $LobbyView/ColumnsHBox/ConnectionPanel/VBox/HostButton
@onready var join_btn: Button = $LobbyView/ColumnsHBox/ConnectionPanel/VBox/JoinButton
@onready var disconnect_btn: Button = $LobbyView/ColumnsHBox/ConnectionPanel/VBox/DisconnectButton
@onready var conn_log_lbl: Label = $LobbyView/ColumnsHBox/ConnectionPanel/VBox/ConnectionLogLabel

@onready var role_thief_btn: Button = $LobbyView/ColumnsHBox/RolesPanel/VBox/RoleThiefButton
@onready var role_guard1_btn: Button = $LobbyView/ColumnsHBox/RolesPanel/VBox/RoleGuard1Button
@onready var role_guard2_btn: Button = $LobbyView/ColumnsHBox/RolesPanel/VBox/RoleGuard2Button
@onready var role_guard3_btn: Button = $LobbyView/ColumnsHBox/RolesPanel/VBox/RoleGuard3Button
@onready var current_role_lbl: Label = $LobbyView/ColumnsHBox/RolesPanel/VBox/CurrentRoleInfoLabel

@onready var lobby_back_btn: Button = $LobbyView/BottomActionsHBox/LobbyBackButton
@onready var start_match_btn: Button = $LobbyView/BottomActionsHBox/StartMatchButton


func _ready() -> void:
	scenario_thumb_rect = get_node("ScenarioView/ContentHBox/DetailsPanel/VBox/ThumbRect")
	players_list_container = get_node(
		"LobbyView/ColumnsHBox/PlayersPanel/VBox/Scroll/PlayersListContainer"
	)
	_bind_main_navigation()
	_bind_scenario_view()
	_bind_lobby_controls()
	_bind_net_manager_signals()
	_show_main_view()
	_populate_scenario_list()
	_select_scenario(0)


## Obtiene de forma segura el nodo Autoload NetManager si está presente
func _get_net_manager() -> NetManagerNode:
	return get_node_or_null("/root/NetManager") as NetManagerNode


func _bind_main_navigation() -> void:
	quick_play_btn.pressed.connect(_on_quick_play_pressed)
	select_stage_btn.pressed.connect(_on_select_stage_pressed)
	online_btn.pressed.connect(_on_online_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)


func _bind_scenario_view() -> void:
	back_btn.pressed.connect(_on_back_pressed)
	launch_btn.pressed.connect(_on_launch_scenario_pressed)


func _bind_lobby_controls() -> void:
	host_btn.pressed.connect(_on_host_pressed)
	join_btn.pressed.connect(_on_join_pressed)
	disconnect_btn.pressed.connect(_on_disconnect_pressed)
	lobby_back_btn.pressed.connect(_on_lobby_back_pressed)
	start_match_btn.pressed.connect(_on_start_match_pressed)

	role_thief_btn.pressed.connect(_on_role_btn_pressed.bind(NetManagerNode.ROLE_THIEF))
	role_guard1_btn.pressed.connect(_on_role_btn_pressed.bind(NetManagerNode.ROLE_GUARD_1))
	role_guard2_btn.pressed.connect(_on_role_btn_pressed.bind(NetManagerNode.ROLE_GUARD_2))
	role_guard3_btn.pressed.connect(_on_role_btn_pressed.bind(NetManagerNode.ROLE_GUARD_3))


func _bind_net_manager_signals() -> void:
	var nm: NetManagerNode = _get_net_manager()
	if nm == null:
		return
	_connect_signal_safe(nm.server_started, _on_server_started)
	_connect_signal_safe(nm.connection_succeeded, _on_connection_succeeded)
	_connect_signal_safe(nm.connection_failed, _on_connection_failed)
	_connect_signal_safe(nm.server_disconnected, _on_server_disconnected)
	_connect_signal_safe(nm.player_list_updated, _on_player_list_updated)


func _connect_signal_safe(sig: Signal, target: Callable) -> void:
	if not sig.is_connected(target):
		sig.connect(target)


# --- Navegación de Vistas ---


func _show_main_view() -> void:
	main_view.visible = true
	scenario_view.visible = false
	if lobby_view != null:
		lobby_view.visible = false


func _show_scenario_view() -> void:
	main_view.visible = false
	scenario_view.visible = true
	if lobby_view != null:
		lobby_view.visible = false


func _show_lobby_view() -> void:
	main_view.visible = false
	scenario_view.visible = false
	if lobby_view != null:
		lobby_view.visible = true
	_update_lobby_ui()


# --- Callbacks Menú Principal y Escenarios ---


func _on_quick_play_pressed() -> void:
	_load_scene("res://scenes/maps/museum_velvet_84.tscn")


func _on_select_stage_pressed() -> void:
	_show_scenario_view()


func _on_online_pressed() -> void:
	_show_lobby_view()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_back_pressed() -> void:
	_show_main_view()


func _on_launch_scenario_pressed() -> void:
	var data: Dictionary = SCENARIOS[_selected_idx]
	_load_scene(data["scene_path"])


func _populate_scenario_list() -> void:
	for child in list_container.get_children():
		list_container.remove_child(child)
		child.queue_free()

	for i: int in range(SCENARIOS.size()):
		var data: Dictionary = SCENARIOS[i]
		var btn: Button = Button.new()
		btn.text = " [ %d ]  %s" % [i + 1, data["title"]]
		btn.custom_minimum_size = Vector2(0, 52)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_scenario_btn_pressed.bind(i))
		list_container.add_child(btn)


func _select_scenario(idx: int) -> void:
	_selected_idx = clampi(idx, 0, SCENARIOS.size() - 1)
	var data: Dictionary = SCENARIOS[_selected_idx]
	scenario_title_lbl.text = data["title"]
	scenario_sub_lbl.text = data["subtitle"]
	scenario_desc_lbl.text = data["desc"]
	scenario_diff_lbl.text = "NIVEL DE ALERTA: " + data["difficulty"]
	scenario_diff_lbl.modulate = data["badge_color"]
	if ResourceLoader.exists(data["thumb"]):
		scenario_thumb_rect.texture = load(data["thumb"])


func _on_scenario_btn_pressed(idx: int) -> void:
	_select_scenario(idx)


# --- Callbacks de Lobby Multijugador ---


func _on_host_pressed() -> void:
	var nm: NetManagerNode = _get_net_manager()
	if nm == null:
		return
	var port: int = _get_port_input()
	conn_log_lbl.text = "INICIALIZANDO OPERACIÓN COMO HOST EN FRECUENCIA %d..." % port
	var err: Error = nm.start_host(port, NetManagerNode.MAX_PLAYERS)
	if err != OK:
		conn_log_lbl.text = "ERROR AL CREAR HOST EN PUERTO %d: %s" % [port, error_string(err)]
	_update_lobby_ui()


func _on_join_pressed() -> void:
	var nm: NetManagerNode = _get_net_manager()
	if nm == null:
		return
	var ip: String = ip_edit.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	var port: int = _get_port_input()
	conn_log_lbl.text = "SINTONIZANDO REPETIDOR EN %s:%d..." % [ip, port]
	var err: Error = nm.join_server(ip, port)
	if err != OK:
		conn_log_lbl.text = "ERROR AL CONECTAR A %s:%d: %s" % [ip, port, error_string(err)]
	_update_lobby_ui()


func _on_disconnect_pressed() -> void:
	var nm: NetManagerNode = _get_net_manager()
	if nm != null:
		nm.disconnect_network()
	conn_log_lbl.text = "DESCONECTADO DE LA FRECUENCIA DE RADIO."
	_update_lobby_ui()


func _on_role_btn_pressed(role: StringName) -> void:
	var nm: NetManagerNode = _get_net_manager()
	if nm == null:
		return
	print("[MainMenu] Solicitando rol: ", role)
	var ok: bool = nm.request_role(role)
	if not ok:
		conn_log_lbl.text = "ROL %s NO DISPONIBLE O RECHAZADO POR CENTRAL." % role
	_update_lobby_ui()


func _on_start_match_pressed() -> void:
	var nm: NetManagerNode = _get_net_manager()
	if nm != null and _is_network_active() and multiplayer.is_server():
		conn_log_lbl.text = "LANZANDO OPERACIÓN MULTIJUGADOR..."
		nm.launch_match()


func _on_lobby_back_pressed() -> void:
	var nm: NetManagerNode = _get_net_manager()
	if nm != null:
		nm.disconnect_network()
	_show_main_view()


# --- Señales reactivas de NetManager ---


func _on_server_started() -> void:
	conn_log_lbl.text = "SALA CREADA COMO HOST. EMITIENDO FRECUENCIA..."
	_update_lobby_ui()


func _on_connection_succeeded() -> void:
	conn_log_lbl.text = "SINTONIZADO A FRECUENCIA CON ÉXITO."
	_update_lobby_ui()


func _on_connection_failed() -> void:
	conn_log_lbl.text = "FALLO AL SINTONIZAR FRECUENCIA CON EL SERVIDOR."
	_update_lobby_ui()


func _on_server_disconnected() -> void:
	conn_log_lbl.text = "SEÑAL PERDIDA: DESCONECTADO DEL SERVIDOR."
	_update_lobby_ui()


func _on_player_list_updated() -> void:
	_update_lobby_ui()


# --- Actualización Visual Reactiva de Lobby ---


## Determina si hay una conexión de red multijugador activa (no offline)
func _is_network_active() -> bool:
	return (
		multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer is ENetMultiplayerPeer
	)


func _update_lobby_ui() -> void:
	if lobby_view == null or not is_inside_tree():
		return

	var nm: NetManagerNode = _get_net_manager()
	var is_online: bool = _is_network_active()
	var is_server: bool = is_online and multiplayer.is_server()
	var port: int = _get_port_input()

	lobby_title_lbl.text = "SALA DE TRANSMISIÓN ANALÓGICA — FRECUENCIA %d" % port

	if not is_online:
		lobby_status_lbl.text = "ESTADO: DESCONECTADO"
		lobby_status_lbl.modulate = COLOR_DIM
		host_btn.disabled = false
		join_btn.disabled = false
		disconnect_btn.disabled = true
		ip_edit.editable = true
		port_edit.editable = true
		start_match_btn.disabled = true
	elif is_server:
		lobby_status_lbl.text = "ESTADO: CONECTADO COMO HOST"
		lobby_status_lbl.modulate = COLOR_AMBER
		host_btn.disabled = true
		join_btn.disabled = true
		disconnect_btn.disabled = false
		ip_edit.editable = false
		port_edit.editable = false
		var players: Dictionary = nm.get_connected_players() if nm != null else {}
		start_match_btn.disabled = players.is_empty()
	else:
		lobby_status_lbl.text = "ESTADO: CONECTADO COMO CLIENTE"
		lobby_status_lbl.modulate = COLOR_CYAN
		host_btn.disabled = true
		join_btn.disabled = true
		disconnect_btn.disabled = false
		ip_edit.editable = false
		port_edit.editable = false
		start_match_btn.disabled = true

	var local_role: StringName = nm.get_local_role() if nm != null else &""
	if local_role == &"":
		current_role_lbl.text = "TU FRECUENCIA ASIGNADA: NINGUNA"
		current_role_lbl.modulate = COLOR_DIM
	else:
		current_role_lbl.text = "TU FRECUENCIA ASIGNADA: %s" % _format_role_name(local_role)
		current_role_lbl.modulate = COLOR_GREEN

	_update_role_button(
		role_thief_btn, NetManagerNode.ROLE_THIEF, "INFILTRADO (LADRÓN)", local_role, nm
	)
	_update_role_button(role_guard1_btn, NetManagerNode.ROLE_GUARD_1, "GUARDIA 1", local_role, nm)
	_update_role_button(role_guard2_btn, NetManagerNode.ROLE_GUARD_2, "GUARDIA 2", local_role, nm)
	_update_role_button(role_guard3_btn, NetManagerNode.ROLE_GUARD_3, "GUARDIA 3", local_role, nm)

	_populate_players_list(nm)


func _update_role_button(
	btn: Button, role: StringName, role_label: String, local_role: StringName, nm: NetManagerNode
) -> void:
	if btn == null:
		return
	var is_my_role: bool = local_role == role
	var is_avail: bool = nm.is_role_available(role) if nm != null else true

	if is_my_role:
		btn.text = "✔  %s  [TU ROL ACTUAL]" % role_label
		btn.modulate = COLOR_GREEN
		btn.disabled = false
	elif is_avail:
		btn.text = "○  %s  [DISPONIBLE]" % role_label
		btn.modulate = Color(0.9, 0.95, 1.0, 1.0)
		btn.disabled = false
	else:
		var occupant_name: String = _get_role_occupant_name(role, nm)
		btn.text = "✕  %s  [OCUPADO: %s]" % [role_label, occupant_name]
		btn.modulate = COLOR_RED
		btn.disabled = true


func _get_role_occupant_name(role: StringName, nm: NetManagerNode) -> String:
	if nm == null:
		return "OTRO AGENTE"
	var players: Dictionary = nm.get_connected_players()
	for pid: int in players:
		var p_info: Dictionary = players[pid]
		if p_info.get("role") == role:
			return p_info.get("name", "Agente_%d" % pid)
	return "OTRO AGENTE"


func _populate_players_list(nm: NetManagerNode) -> void:
	for child in players_list_container.get_children():
		players_list_container.remove_child(child)
		child.queue_free()

	var players: Dictionary = nm.get_connected_players() if nm != null else {}
	if players.is_empty():
		var empty_lbl: Label = Label.new()
		empty_lbl.text = "[ SIN EMISIONES DETECTADAS — FRECUENCIA EN ESPERA ]"
		empty_lbl.modulate = COLOR_DIM
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		players_list_container.add_child(empty_lbl)
		return

	var my_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0

	for pid: int in players:
		var p_info: Dictionary = players[pid]
		var p_name: String = p_info.get("name", "Agente_%d" % pid)
		var p_role: StringName = p_info.get("role", &"")
		var is_host: bool = pid == 1
		var is_me: bool = (
			pid == my_id or (is_host and nm != null and not nm.is_dedicated_server and my_id == 1)
		)

		var row: PanelContainer = PanelContainer.new()
		var margin: MarginContainer = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 8)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_top", 4)
		margin.add_theme_constant_override("margin_bottom", 4)
		row.add_child(margin)

		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 16)
		margin.add_child(hbox)

		var indicator: Label = Label.new()
		indicator.text = "●"
		indicator.modulate = COLOR_GREEN if is_me else COLOR_CYAN
		hbox.add_child(indicator)

		var name_lbl: Label = Label.new()
		var host_tag: String = " [HOST]" if is_host else ""
		var me_tag: String = " [TÚ]" if is_me else ""
		name_lbl.text = "%s%s%s" % [p_name, host_tag, me_tag]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.modulate = COLOR_AMBER if is_me else Color(0.9, 0.95, 1.0, 1.0)
		hbox.add_child(name_lbl)

		var role_lbl: Label = Label.new()
		role_lbl.text = _format_role_name(p_role)
		role_lbl.modulate = (
			COLOR_CYAN if p_role == NetManagerNode.ROLE_THIEF else Color(0.85, 0.75, 0.95, 1.0)
		)
		hbox.add_child(role_lbl)

		players_list_container.add_child(row)


func _format_role_name(role: StringName) -> String:
	match role:
		NetManagerNode.ROLE_THIEF:
			return "INFILTRADO (LADRÓN)"
		NetManagerNode.ROLE_GUARD_1:
			return "GUARDIA 1"
		NetManagerNode.ROLE_GUARD_2:
			return "GUARDIA 2"
		NetManagerNode.ROLE_GUARD_3:
			return "GUARDIA 3"
		_:
			return "SIN ROL ASIGNADO"


func _get_port_input() -> int:
	var port_str: String = port_edit.text.strip_edges()
	var port: int = port_str.to_int() if not port_str.is_empty() else NetManagerNode.DEFAULT_PORT
	return port if port > 0 else NetManagerNode.DEFAULT_PORT


func _load_scene(path: String) -> void:
	print("[MainMenu] Cargando escenario: ", path)
	get_tree().change_scene_to_file(path)
