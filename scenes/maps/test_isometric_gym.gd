## @file test_isometric_gym.gd
## Controlador de nivel para el gimnasio de pruebas isométrico 3D.
## Toda la lógica común (control local, cámara, HUD, percepción, porra y ondas) vive en
## HeistMap3D. La cámara del gimnasio es fija: no sigue al personaje.
extends HeistMap3D


func _process_camera_follow(_delta: float) -> void:
	pass


func set_local_player(player: PlayerBase3D) -> void:
	var fixed_position: Vector3 = camera.global_position if camera != null else Vector3.ZERO
	super.set_local_player(player)
	if camera != null:
		camera.global_position = fixed_position
