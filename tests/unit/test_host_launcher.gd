## @file test_host_launcher.gd
## «Crear partida» (FEAT-040): argumentos del servidor, IP de casa, texto para los amigos, el
## vigilante del servidor y, de verdad, crear una partida, conectarse y cerrarla.
extends GutTest

const PORT: int = 7811


func before_each() -> void:
	HostLauncher.upnp_enabled = false  # los tests no tocan el router de verdad


func after_each() -> void:
	HostPanel84.close_hosted(get_tree())
	NetManager.disconnect_network()
	HostLauncher.upnp_enabled = true


func test_server_args_include_port_and_hosted() -> void:
	var args: PackedStringArray = HostLauncher.server_args(7777)
	for expected: String in ["--headless", "--server", "--port", "7777", HostWatch.ARG]:
		assert_true(args.has(expected), "Lleva %s" % expected)
	assert_eq(NetConfig.cli_port(args, 1), 7777, "El servidor lee el puerto")
	assert_true(HostWatch.requested(args), "Y se vigila a sí mismo")
	assert_false(HostWatch.requested(PackedStringArray(["--server"])), "servidor.bat no")


func test_host_is_whoever_connects_from_this_computer() -> void:
	assert_true(HostWatch.is_local("127.0.0.1"))
	assert_true(HostWatch.is_local("::1"))
	assert_false(HostWatch.is_local("192.168.1.20"), "Un amigo en casa no es quien la creó")


func test_private_ips_are_the_home_network_ones() -> void:
	var found: PackedStringArray = (
		HostLauncher
		. private_ips(
			PackedStringArray(
				[
					"127.0.0.1",
					"192.168.1.20",
					"10.0.0.5",
					"172.20.1.2",
					"172.40.1.2",
					"83.45.12.9",
					"fe80::1",
				]
			)
		)
	)
	assert_eq(Array(found), ["192.168.1.20", "10.0.0.5", "172.20.1.2"])


func test_friends_text_and_copy() -> void:
	var text: String = HostPanel84.friends_text("83.45.12.9", 7777)
	assert_string_contains(text, "83.45.12.9:7777")
	assert_false(text.contains("red"), "Sin red local")
	assert_eq(HostPanel84.friends_text("", 7777), "", "Sin IP pública no hay texto")
	assert_eq(HostPanel84.copy_text("83.45.12.9", 7777), "83.45.12.9:7777")


## De verdad: arranca el servidor en otro proceso, se conecta y al cerrar no queda nada
func test_create_join_and_close_a_real_match() -> void:
	var launcher: HostLauncher = HostLauncher.start(get_tree(), PORT)
	assert_not_null(launcher, "Arranca el servidor")
	assert_true(launcher.is_running())
	var connected: Array = [false]
	var on_ok: Callable = func() -> void: connected[0] = true
	NetManager.connection_succeeded.connect(on_ok)
	for attempt: int in range(8):
		await wait_seconds(1.5)
		NetManager.join_server("127.0.0.1", PORT)
		await wait_seconds(1.5)
		if connected[0]:
			break
		NetManager.disconnect_network()
	NetManager.connection_succeeded.disconnect(on_ok)
	assert_true(connected[0], "Se conecta a la partida creada")
	assert_true(launcher.is_running())
	# Quien la creó se va sin cerrarla (como si se le cayera el juego): el servidor se cierra solo
	NetManager.disconnect_network()
	var gone: bool = false
	for check: int in range(20):
		await wait_seconds(0.5)
		if not launcher.is_running():
			gone = true
			break
	assert_true(gone, "Sin quien la creó, el servidor se ha cerrado solo")
	HostPanel84.close_hosted(get_tree())
	await wait_frames(2)
	assert_null(HostLauncher.current(get_tree()), "Ya no hay partida creada")


func test_ports_and_public_ips() -> void:
	assert_true(HostLauncher.valid_port(7777))
	for bad: int in [-5, 0, 80, 99999]:
		assert_false(HostLauncher.valid_port(bad), "Puerto %d" % bad)
	assert_true(HostLauncher.is_public("83.45.12.9"))
	for not_public: String in ["192.168.1.1", "10.2.3.4", "100.64.1.1", "127.0.0.1", "", "x"]:
		assert_false(HostLauncher.is_public(not_public), "No es pública: %s" % not_public)


## Si el puerto está ocupado, el servidor creado desde el juego se cierra enseguida
func test_hosted_server_closes_when_port_is_taken() -> void:
	var first: int = OS.create_process(OS.get_executable_path(), HostLauncher.server_args(PORT + 2))
	await wait_seconds(3.0)
	var second: int = OS.create_process(
		OS.get_executable_path(), HostLauncher.server_args(PORT + 2)
	)
	var closed: bool = false
	for check: int in range(16):
		await wait_seconds(0.5)
		if not OS.is_process_running(second):
			closed = true
			break
	assert_true(closed, "Con el puerto ocupado se cierra solo")
	for pid: int in [first, second]:
		if OS.is_process_running(pid):
			OS.kill(pid)


## Si el servidor creado desaparece, la sala vuelve a dejar unirse y crear
func test_lobby_recovers_when_the_server_is_gone() -> void:
	var menu: Node = (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate()
	add_child_autofree(menu)
	await wait_frames(5)
	var panel: HostPanel84 = menu.find_child("HostPanel", true, false) as HostPanel84
	var dead: HostLauncher = HostLauncher.new()  # sin proceso: como un servidor que se cayó
	dead.name = HostLauncher.NODE_NAME
	get_tree().root.add_child(dead)
	await wait_frames(3)
	assert_null(HostLauncher.current(get_tree()), "Se olvida de la partida muerta")
	assert_false(panel.host_button.disabled, "Se puede crear otra")
	var join: Control = panel.host_button.get_parent().get_node("JoinButton") as Control
	assert_true(join.visible, "Y unirse a otra")
	assert_string_contains(panel.log_label.text, "La partida se ha cerrado")
