## @file host_panel_84.gd
## «CREAR PARTIDA» en la sala de espera (FEAT-040). El botón arranca el servidor en este equipo
## (HostLauncher), conecta al jugador con él y le enseña qué pasar a sus amigos: la IP pública
## (si el router la da por UPnP) y la de casa, con el puerto y un botón para copiarlas. Si el
## router no deja abrir el puerto solo, lo dice. Al salir de la sala, la partida se cierra.
class_name HostPanel84
extends VBoxContainer

## Primer intento de conexión (s): lo que tarda el servidor en arrancar
const FIRST_TRY: float = 2.5
const RETRY: float = 2.0
const MAX_TRIES: int = 6
const HIDDEN_WHILE_HOSTING: PackedStringArray = ["IpLabel", "IpEdit", "JoinButton"]

var host_button: Button = null
var port_edit: LineEdit = null
var log_label: Label = null
var info_label: Label = null
var copy_button: Button = null
var _tries: int = 0
var _retry_timer: Timer = null


## Crea el panel debajo de host_button, que pasa a ser «CREAR PARTIDA»
static func attach(button: Button, port: LineEdit, log: Label) -> HostPanel84:
	var panel: HostPanel84 = HostPanel84.new()
	panel.host_button = button
	panel.port_edit = port
	panel.log_label = log
	button.add_sibling(panel)
	return panel


## Cierra la partida creada en este equipo, si hay una
static func close_hosted(tree: SceneTree) -> void:
	var launcher: HostLauncher = HostLauncher.current(tree)
	if launcher != null:
		launcher.close()


## Texto para los amigos: dónde conectarse
static func friends_text(public_ip: String, local_ips: PackedStringArray, port: int) -> String:
	var lines: PackedStringArray = ["Pásale esto a tu amigo:"]
	if not public_ip.is_empty():
		lines.append("Por internet: %s · puerto %d" % [public_ip, port])
	if not local_ips.is_empty():
		lines.append("En tu misma red: %s · puerto %d" % [local_ips[0], port])
	return "\n".join(lines)


## Lo que se copia: la dirección por internet si se sabe; si no, la de casa
static func copy_text(public_ip: String, local_ips: PackedStringArray, port: int) -> String:
	var ip: String = (
		public_ip
		if not public_ip.is_empty()
		else (local_ips[0] if not local_ips.is_empty() else "127.0.0.1")
	)
	return "%s:%d" % [ip, port]


func _ready() -> void:
	name = "HostPanel"
	add_theme_constant_override("separation", 6)
	host_button.text = "CREAR PARTIDA"
	host_button.visible = true
	host_button.pressed.connect(_on_create_pressed)
	info_label = Label.new()
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.visible = false
	add_child(info_label)
	copy_button = Button.new()
	copy_button.text = "COPIAR"
	copy_button.visible = false
	copy_button.pressed.connect(_on_copy_pressed)
	add_child(copy_button)
	_retry_timer = Timer.new()
	_retry_timer.one_shot = true
	_retry_timer.timeout.connect(_try_join)
	add_child(_retry_timer)
	NetManager.connection_succeeded.connect(_on_connected)
	NetManager.connection_failed.connect(_on_failed)
	_show_launcher(HostLauncher.current(get_tree()))


func _process(_delta: float) -> void:
	var hosting: bool = HostLauncher.current(get_tree()) != null
	host_button.disabled = NetManager.is_online() or hosting
	# Con la partida creada aquí, la IP y «UNIRSE» sobran: queda sitio para lo de los amigos
	for sibling: String in HIDDEN_WHILE_HOSTING:
		var node: Control = host_button.get_parent().get_node_or_null(sibling) as Control
		if node != null:
			node.visible = not hosting
	var close_button: Button = host_button.get_parent().get_node_or_null("DisconnectButton")
	if close_button != null:
		close_button.text = "CERRAR PARTIDA" if hosting else "DESCONECTAR"


func _on_create_pressed() -> void:
	var port: int = (
		int(port_edit.text) if port_edit.text.is_valid_int() else NetManager.DEFAULT_PORT
	)
	var launcher: HostLauncher = HostLauncher.start(get_tree(), port)
	if launcher == null:
		log_label.text = "No se pudo crear la partida. Inténtalo de nuevo."
		return
	log_label.text = "Creando la partida… Si Windows pregunta, pulsa Permitir."
	_tries = 0
	_retry_timer.start(FIRST_TRY)
	_show_launcher(launcher)


func _try_join() -> void:
	var launcher: HostLauncher = HostLauncher.current(get_tree())
	if launcher == null or NetManager.is_online():
		return
	if not launcher.is_running():
		log_label.text = "La partida no ha podido arrancar. Prueba con otro puerto."
		launcher.close()
		return
	_tries += 1
	NetManager.join_server("127.0.0.1", launcher.port)


func _on_connected() -> void:
	_retry_timer.stop()


func _on_failed() -> void:
	if HostLauncher.current(get_tree()) != null and _tries < MAX_TRIES:
		_retry_timer.start(RETRY)  # el servidor aún estaba arrancando


func _show_launcher(launcher: HostLauncher) -> void:
	if launcher == null:
		return
	if not launcher.upnp_finished.is_connected(_on_upnp):
		launcher.upnp_finished.connect(_on_upnp)
	_refresh_info(launcher)


func _on_upnp(_ok: bool) -> void:
	_refresh_info(HostLauncher.current(get_tree()))


func _refresh_info(launcher: HostLauncher) -> void:
	if launcher == null:
		return
	var text: String = friends_text(launcher.public_ip, launcher.local_ips, launcher.port)
	if not launcher.upnp_done:
		text += "\nBuscando tu router para abrir el puerto…"
	elif not launcher.upnp_ok:
		text += (
			"\nTu router no ha dejado abrir el puerto solo. Para jugar por internet, ábrelo a"
			+ (
				" mano (puerto %d, UDP) y busca «cuál es mi IP» para saber tu IP pública."
				% launcher.port
			)
		)
	info_label.text = text
	info_label.visible = true
	copy_button.visible = true


func _on_copy_pressed() -> void:
	var launcher: HostLauncher = HostLauncher.current(get_tree())
	if launcher != null:
		DisplayServer.clipboard_set(
			copy_text(launcher.public_ip, launcher.local_ips, launcher.port)
		)
		copy_button.text = "COPIADO"
