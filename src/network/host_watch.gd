## @file host_watch.gd
## En un servidor lanzado por «Crear partida» (FEAT-040, HostLauncher, argumento --hosted):
## recuerda al jugador que la creó (el primero que se conecta desde este mismo equipo) y cierra
## el servidor cuando ese jugador se desconecta, porque ha salido de la sala, ha cerrado el
## juego o se le ha caído. Si nadie llega a conectarse en JOIN_WAIT segundos, también se cierra.
## Así no queda ningún servidor suelto. Sin --hosted no hace nada.
class_name HostWatch
extends Node

const ARG: String = "--hosted"
const JOIN_WAIT: float = 60.0
const LOOPBACK: PackedStringArray = ["127.0.0.1", "::1", "::ffff:127.0.0.1"]

## Jugador que creó la partida (0 hasta que se conecta)
var host_peer: int = 0


## true si este proceso es un servidor creado desde el juego
static func requested(args: PackedStringArray) -> bool:
	return args.has(ARG)


## Se engancha a la raíz si este proceso es un servidor creado desde el juego
static func attach_if_requested(tree: SceneTree) -> void:
	var args: PackedStringArray = OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	if not requested(args) or tree.root.has_node("HostWatch"):
		return
	var watch: HostWatch = HostWatch.new()
	watch.name = "HostWatch"
	tree.root.add_child.call_deferred(watch)  # la raíz aún está montando la escena principal


## true si la dirección es la de este mismo equipo
static func is_local(address: String) -> bool:
	return LOOPBACK.has(address)


func _ready() -> void:
	var api: MultiplayerAPI = get_tree().get_multiplayer()
	api.peer_connected.connect(_on_peer_connected)
	api.peer_disconnected.connect(_on_peer_disconnected)
	get_tree().create_timer(JOIN_WAIT).timeout.connect(_on_join_wait_over)


func _on_peer_connected(peer: int) -> void:
	if host_peer != 0:
		return
	var enet: ENetMultiplayerPeer = multiplayer.multiplayer_peer as ENetMultiplayerPeer
	var packet_peer: ENetPacketPeer = enet.get_peer(peer) if enet != null else null
	if packet_peer != null and is_local(packet_peer.get_remote_address()):
		host_peer = peer


func _on_peer_disconnected(peer: int) -> void:
	if peer == host_peer:
		_close("El jugador que creó la partida se ha ido")


func _on_join_wait_over() -> void:
	if host_peer == 0:
		_close("Nadie se ha conectado a la partida creada")


func _close(reason: String) -> void:
	print("[HostWatch] %s: cierro el servidor" % reason)
	get_tree().quit()
