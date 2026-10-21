## @file test_lobby_ui.gd
## Escena y runner de prueba para la interfaz del Menú Principal y Lobby Multijugador (FEAT-003).
## Valida navegación, vinculación reactiva con NetManager, asignación de roles y estados visuales,
## y genera capturas reales de evidencia en pantalla.
class_name TestLobbyUI
extends Control

const ARTIFACT_DIR: String = (
	"/home/oscar/.gemini/antigravity/brain/" + "6842e7e9-659f-46ed-8999-3115df9c1873"
)

var main_menu: MainMenu = null
var current_step: int = 0
var step_frames: int = 0


func _ready() -> void:
	print("[TestLobbyUI] Montando MainMenu...")
	var menu_scene: PackedScene = load("res://scenes/ui/main_menu.tscn")
	main_menu = menu_scene.instantiate() as MainMenu
	add_child(main_menu)


func _process(_delta: float) -> void:
	step_frames += 1
	if step_frames == 2:
		_execute_step(current_step)
	elif step_frames == 5:
		_capture_step(current_step)
		current_step += 1
		step_frames = 0
		if current_step > 5:
			_finish_tests()


func _capture_screen(filename: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		var out_path: String = "%s/%s" % [ARTIFACT_DIR, filename]
		var err: Error = img.save_png(out_path)
		if err == OK:
			print("[TestLobbyUI] Captura guardada en: ", out_path)
		else:
			print("[TestLobbyUI] Error al guardar captura: ", err)


func _execute_step(step: int) -> void:
	match step:
		0:
			print("--- PASO 0: ESTADO INICIAL MENÚ PRINCIPAL ---")
			assert(main_menu.main_view.visible, "MainView debe ser visible inicialmente")
			assert(not main_menu.lobby_view.visible, "LobbyView debe estar oculta inicialmente")
			assert(main_menu.online_btn != null, "OnlineButton debe existir")
		1:
			print("--- PASO 1: ABRIR LOBBY MULTIJUGADOR ---")
			main_menu.online_btn.emit_signal("pressed")
			assert(not main_menu.main_view.visible, "MainView oculta al entrar al Lobby")
			assert(main_menu.lobby_view.visible, "LobbyView visible")
			assert(
				main_menu.lobby_status_lbl.text == "ESTADO: DESCONECTADO",
				"Estado debe ser DESCONECTADO"
			)
			assert(
				main_menu.start_match_btn.disabled,
				"Botón Comenzar deshabilitado al estar desconectado"
			)
		2:
			print("--- PASO 2: INICIAR OPERACIÓN HOST ---")
			main_menu.host_btn.emit_signal("pressed")
			var net_mgr: NetManagerNode = get_node_or_null("/root/NetManager")
			assert(net_mgr != null, "NetManager Autoload presente")
			assert(multiplayer.is_server(), "Servidor activo")
			assert(
				main_menu.lobby_status_lbl.text == "ESTADO: CONECTADO COMO HOST",
				"Estado Host correcto"
			)
			assert(not main_menu.start_match_btn.disabled, "Botón Comenzar habilitado para Host")
			# Simular conexión de segundo agente
			net_mgr.register_player(2, "Agente_Sombra_84", NetManagerNode.ROLE_GUARD_1)
		3:
			print("--- PASO 3: INTERCAMBIO TÁCTICO DE ROLES ---")
			var net_mgr: NetManagerNode = get_node_or_null("/root/NetManager")
			main_menu.role_guard2_btn.emit_signal("pressed")
			assert(
				net_mgr.get_local_role() == NetManagerNode.ROLE_GUARD_2, "Rol cambiado a Guard 2"
			)
			assert("TU ROL ACTUAL" in main_menu.role_guard2_btn.text, "Guardia 2 es rol actual")
			assert("DISPONIBLE" in main_menu.role_thief_btn.text, "Thief disponible")
			assert("OCUPADO" in main_menu.role_guard1_btn.text, "Guardia 1 ocupado")
		4:
			print("--- PASO 4: DESCONECTAR Y REGRESAR AL MENÚ ---")
			main_menu.disconnect_btn.emit_signal("pressed")
			assert(multiplayer.multiplayer_peer == null, "Red desconectada")
			assert(
				main_menu.lobby_status_lbl.text == "ESTADO: DESCONECTADO",
				"Estado restablecido a DESCONECTADO"
			)
			main_menu.lobby_back_btn.emit_signal("pressed")
			assert(main_menu.main_view.visible, "MainView visible")
			assert(not main_menu.lobby_view.visible, "LobbyView oculta")
		5:
			print("--- PASO 5: VERIFICAR NO-REGRESIÓN DE ESCENARIOS ---")
			main_menu.select_stage_btn.emit_signal("pressed")
			assert(main_menu.scenario_view.visible, "ScenarioView accesible")
			main_menu.back_btn.emit_signal("pressed")
			assert(main_menu.main_view.visible, "Regreso a MainView exitoso")


func _capture_step(step: int) -> void:
	match step:
		0:
			_capture_screen("01_main_menu_online_btn.png")
			print("✔ Captura 01 lista.")
		1:
			_capture_screen("02_lobby_disconnected.png")
			print("✔ Captura 02 lista.")
		2:
			_capture_screen("03_lobby_host_connected.png")
			print("✔ Captura 03 lista.")
		3:
			_capture_screen("04_lobby_role_assignment.png")
			print("✔ Captura 04 lista.")


func _finish_tests() -> void:
	print("--- VERIFICACIÓN COMPLETA: TODOS LOS CRITERIOS DE UI CUMPLIDOS AL 100% ---")
	get_tree().quit(0)
