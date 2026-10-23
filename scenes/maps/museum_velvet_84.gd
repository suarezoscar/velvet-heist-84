## @file museum_velvet_84.gd
## Controlador del mapa principal "Museo Metropolitano 1984" (Velvet Heist 84).
## Añade a HeistMap3D la vinculación del sistema CCTV. La sesión de red vive en
## HeistMap3D/NetSession desde la FEAT-014.
extends HeistMap3D

var guard_1: GuardController3D = null
var guard_2: GuardController3D = null


func _on_map_ready() -> void:
	guard_1 = get_node_or_null("GuardPlayer1") as GuardController3D
	guard_2 = get_node_or_null("GuardPlayer2") as GuardController3D
	_bind_cctv_monitors()


func _extra_hidden_mesh_names() -> Array[String]:
	return ["Car", "marble_bust"]


func _bind_cctv_monitors() -> void:
	var pairs: Array[Array] = [
		["Props/SecurityCamera_01", "Props/CCTVMonitor_01"],
		["Props/SecurityCamera_02", "Props/CCTVMonitor_02"],
	]
	for pair: Array in pairs:
		var cam: SecurityCamera3D = get_node_or_null(pair[0]) as SecurityCamera3D
		var monitor: CCTVMonitor3D = get_node_or_null(pair[1]) as CCTVMonitor3D
		if cam != null and monitor != null:
			monitor.bind_camera(cam)
