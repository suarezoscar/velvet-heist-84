## @file net_peer_factory.gd
## Creación de peers ENet y lectura de los argumentos de línea de comandos de NetManager.
class_name NetPeerFactory
extends RefCounted


## Crea el peer servidor; null (con push_error) si ENet no puede abrir el puerto
static func create_server(port: int, max_players: int) -> ENetMultiplayerPeer:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, max_players)
	if err != OK:
		var err_str: String = error_string(err)
		push_error("[NetManager] Error al crear servidor dedicado en %d: %s" % [port, err_str])
		return null
	return peer


## Crea el peer cliente; null (con push_error) si ENet no puede conectar
static func create_client(ip: String, port: int) -> ENetMultiplayerPeer:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(ip, port)
	if err != OK:
		push_error("[NetManager] Error al conectar a %s:%d: %s" % [ip, port, error_string(err)])
		return null
	return peer


## Puerto del servidor dedicado pedido por CLI; -1 si no hay --server ni --dedicated
static func dedicated_port(args: PackedStringArray, default_port: int) -> int:
	if not (args.has("--server") or args.has("--dedicated")):
		return -1
	return NetConfig.cli_port(args, default_port)
