## @file mansion_belmonte.gd
## Controlador de nivel para "Villa Belmonte - Planta Principal".
## Toda la lógica común (control local, cámara, HUD, percepción, porra y ondas) vive en
## HeistMap3D; aquí solo queda lo propio del mapa.
extends HeistMap3D


func _extra_hidden_mesh_names() -> Array[String]:
	return ["Car"]
