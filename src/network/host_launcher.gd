## @file host_launcher.gd
## «Crear partida» (FEAT-040): arranca el servidor dedicado (FEAT-014) como otro proceso del
## mismo juego, sin ventana, para que el jugador que la crea y sus amigos se conecten a él.
## Además intenta abrir el puerto en el router con UPnP y averiguar desde ahí la IP pública.
## El servidor se cierra al llamar a close(), al cerrar el juego o, si el juego se cae, solo
## (HostWatch: cuando se desconecta quien la creó). Vive en la raíz del árbol, así que
## sobrevive a los cambios de escena.
class_name HostLauncher
extends Node

## UPnP ha terminado: ok si el puerto quedó abierto en el router
signal upnp_finished(ok: bool)

const NODE_NAME: String = "HostLauncher"
const UPNP_DESCRIPTION: String = "Velvet Heist '84"

var port: int = 0
## IP pública que da el router por UPnP ("" si no la da)
var public_ip: String = ""
## IP del equipo en la red de casa
var local_ips: PackedStringArray = []
var upnp_done: bool = false
var upnp_ok: bool = false
var _pid: int = 0
var _upnp: UPNP = null
var _thread: Thread = null


## El lanzador activo (null si no se ha creado ninguna partida)
static func current(tree: SceneTree) -> HostLauncher:
	return tree.root.get_node_or_null(NODE_NAME) as HostLauncher


## Crea la partida en el puerto dado: lanza el servidor y prueba UPnP en otro hilo
static func start(tree: SceneTree, server_port: int) -> HostLauncher:
	var old: HostLauncher = current(tree)
	if old != null:
		old.close()
	var launcher: HostLauncher = HostLauncher.new()
	launcher.name = NODE_NAME
	launcher.port = server_port
	tree.root.add_child(launcher)
	if not launcher._spawn():
		launcher.queue_free()
		return null
	return launcher


## Argumentos para lanzar el servidor con este mismo ejecutable
static func server_args(server_port: int) -> PackedStringArray:
	var args: PackedStringArray = []
	if OS.has_feature("editor"):
		args.append_array(["--path", ProjectSettings.globalize_path("res://")])
	args.append_array(["--headless", "--server", "--port", str(server_port)])
	args.append(HostWatch.ARG)
	return args


## IPv4 de redes privadas del equipo (192.168.x.x, 10.x.x.x, 172.16-31.x.x)
static func private_ips(addresses: PackedStringArray) -> PackedStringArray:
	var found: PackedStringArray = []
	for address: String in addresses:
		var parts: PackedStringArray = address.split(".")
		if parts.size() != 4 or not address.is_valid_ip_address():
			continue
		var second: int = int(parts[1])
		if (
			address.begins_with("192.168.")
			or address.begins_with("10.")
			or (parts[0] == "172" and second >= 16 and second <= 31)
		):
			found.append(address)
	return found


func is_running() -> bool:
	return _pid > 0 and OS.is_process_running(_pid)


## Cierra el servidor y el puerto del router
func close() -> void:
	name = "HostLauncherClosed"  # current() deja de encontrarlo ya, antes de liberarse
	if _pid > 0 and OS.is_process_running(_pid):
		OS.kill(_pid)
	_pid = 0
	_join_upnp()
	if _upnp != null and upnp_ok:
		_upnp.delete_port_mapping(port, "UDP")
	upnp_ok = false
	queue_free()


func _exit_tree() -> void:
	if _pid > 0:
		close()  # al salir del juego no queda ningún servidor suelto


func _spawn() -> bool:
	local_ips = private_ips(IP.get_local_addresses())
	_pid = OS.create_process(OS.get_executable_path(), server_args(port))
	if _pid <= 0:
		return false
	_thread = Thread.new()
	_thread.start(_open_port)
	return true


## En otro hilo: busca el router, abre el puerto y pregunta la IP pública
func _open_port() -> void:
	var upnp: UPNP = UPNP.new()
	var ok: bool = false
	var external: String = ""
	if upnp.discover() == UPNP.UPNP_RESULT_SUCCESS and upnp.get_gateway() != null:
		if upnp.get_gateway().is_valid_gateway():
			ok = (
				upnp.add_port_mapping(port, port, UPNP_DESCRIPTION, "UDP")
				== UPNP.UPNP_RESULT_SUCCESS
			)
			external = upnp.query_external_address()
	_upnp_result.call_deferred(upnp, ok, external)


func _upnp_result(upnp: UPNP, ok: bool, external: String) -> void:
	_join_upnp()
	_upnp = upnp
	upnp_ok = ok
	public_ip = external if external.is_valid_ip_address() else ""
	upnp_done = true
	upnp_finished.emit(ok)


func _join_upnp() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
	_thread = null
