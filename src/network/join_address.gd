## @file join_address.gd
## Dirección para unirse a una partida (#110): «ip:puerto» o solo «ip» (puerto por defecto).
class_name JoinAddress
extends RefCounted

const FORMAT_ERROR: String = "Escribe la dirección como IP:puerto, por ejemplo 83.45.120.7:7777."


## {"ok": bool, "ip": String, "port": int, "error": String}
static func parse(text: String) -> Dictionary:
	var clean: String = text.strip_edges()
	if clean.is_empty():
		return _result("127.0.0.1", NetManagerNode.DEFAULT_PORT)
	var parts: PackedStringArray = clean.split(":")
	if parts.size() > 2:
		return _fail(FORMAT_ERROR)
	if parts.size() == 1:
		return _result(clean, NetManagerNode.DEFAULT_PORT)
	var ip: String = parts[0].strip_edges()
	var port_text: String = parts[1].strip_edges()
	if ip.is_empty():
		return _fail(FORMAT_ERROR)
	if not port_text.is_valid_int() or not HostLauncher.valid_port(int(port_text)):
		return _fail(
			(
				"Ese puerto no vale: usa uno entre %d y %d."
				% [HostLauncher.MIN_PORT, HostLauncher.MAX_PORT]
			)
		)
	return _result(ip, int(port_text))


static func _result(ip: String, port: int) -> Dictionary:
	return {"ok": true, "ip": ip, "port": port, "error": ""}


static func _fail(error: String) -> Dictionary:
	return {"ok": false, "ip": "", "port": 0, "error": error}
