## @file test_thief_visibility.gd
## Tests de visibilidad y detección del ladrón (Criterio 4 / GSD 5.3).
extends GutTest


## Crea un muro estático con colisión en capa 1 (entorno) para bloquear línea de visión
func _create_obstacle_wall(pos: Vector3, size: Vector3 = Vector3(2.0, 3.0, 0.2)) -> StaticBody3D:
	var wall: StaticBody3D = autofree(StaticBody3D.new())
	wall.collision_layer = 1
	wall.collision_mask = 0
	var col: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	col.shape = box
	wall.add_child(col)
	wall.position = pos
	add_child_autofree(wall)
	return wall


## Configura un guardia con su SpotLight3D Maglite
func _create_guard(pos: Vector3 = Vector3.ZERO) -> GuardController3D:
	var guard: GuardController3D = autofree(GuardController3D.new())
	guard.position = pos
	guard.is_ai_controlled = true
	# Apuntar la mirada hacia adelante (-Z) a la altura de los ojos por defecto
	guard.look_target_position = pos + Vector3(0.0, 1.5, -5.0)

	var maglite: SpotLight3D = SpotLight3D.new()
	maglite.name = "Maglite"
	maglite.position = Vector3(0.0, 1.5, 0.0)
	maglite.spot_range = 10.0
	maglite.spot_angle = 35.0
	maglite.visible = false  # Por defecto apagada para aislar tests de proximidad
	guard.add_child(maglite)
	guard.maglite_light = maglite

	add_child_autofree(guard)
	return guard


## Configura un ladrón
func _create_thief(pos: Vector3) -> ThiefController3D:
	var thief: ThiefController3D = autofree(ThiefController3D.new())
	thief.position = pos
	add_child_autofree(thief)
	return thief


## Verifica que null devuelve false con seguridad
func test_null_thief_returns_false() -> void:
	var guard: GuardController3D = _create_guard()
	await wait_physics_frames(1)
	assert_false(guard.check_detection_on_thief(null), "Null no produce errores y devuelve false")


## Criterio 4: Detección por proximidad inmediata (1.8m) sin paredes
func test_proximity_detection_within_1_8m_no_wall() -> void:
	var guard: GuardController3D = _create_guard(Vector3(0.0, 0.0, 0.0))
	# Ojos del guardia en (0, 1.5, 0). Torso del ladrón en (0, 1.5, 1.2) -> Distancia = 1.2m <= 1.8m
	var thief: ThiefController3D = _create_thief(Vector3(0.0, 0.6, 1.2))

	await wait_physics_frames(2)

	var detected: bool = guard.check_detection_on_thief(thief)
	assert_true(detected, "Ladrón a 1.2m es detectado por proximidad inmediata (<1.8m)")


## Criterio 4: Fuera de 1.8m y sin linterna no hay detección
func test_proximity_detection_beyond_1_8m_without_light() -> void:
	var guard: GuardController3D = _create_guard(Vector3(0.0, 0.0, 0.0))
	# Torso del ladrón en (0, 1.5, 2.5) -> Distancia = 2.5m > 1.8m
	var thief: ThiefController3D = _create_thief(Vector3(0.0, 0.6, 2.5))

	await wait_physics_frames(2)

	var detected: bool = guard.check_detection_on_thief(thief)
	assert_false(detected, "Ladrón a 2.5m en oscuridad no es detectado (>1.8m)")


## Criterio 4: Proximidad bloqueada por un muro intermedio
func test_proximity_detection_blocked_by_wall() -> void:
	var guard: GuardController3D = _create_guard(Vector3(0.0, 0.0, 0.0))
	var thief: ThiefController3D = _create_thief(Vector3(0.0, 0.6, 1.4))
	# Muro intermedio a Z = 0.7m entre el guardia (Z=0) y el ladrón (Z=1.4)
	_create_obstacle_wall(Vector3(0.0, 1.5, 0.7))

	await wait_physics_frames(2)

	var detected: bool = guard.check_detection_on_thief(thief)
	assert_false(detected, "Muro intermedio bloquea la detección por proximidad")


## Criterio 4: Detección por SpotLight3D dentro del cono y rango de alcance
func test_spotlight_detection_within_cone_and_range() -> void:
	var guard: GuardController3D = _create_guard(Vector3(0.0, 0.0, 0.0))
	var thief: ThiefController3D = _create_thief(Vector3(0.0, 0.6, -5.0))
	guard.maglite_light.visible = true
	# Apuntar la linterna hacia el ladrón
	guard.look_target_position = Vector3(0.0, 1.5, -5.0)

	await wait_physics_frames(2)

	var detected: bool = guard.check_detection_on_thief(thief)
	assert_true(detected, "SpotLight3D detecta al ladrón en su haz a 5m sin paredes")


## Criterio 4: Fuera del ángulo de apertura de la linterna no hay detección
func test_spotlight_detection_outside_angle() -> void:
	var guard: GuardController3D = _create_guard(Vector3(0.0, 0.0, 0.0))
	guard.maglite_light.visible = true
	# Linterna apunta hacia -Z
	guard.look_target_position = Vector3(0.0, 1.5, -5.0)

	# Ladrón a 5m a un lado (+X), fuera del ángulo de 35 grados
	var thief: ThiefController3D = _create_thief(Vector3(5.0, 0.6, 0.0))

	await wait_physics_frames(2)

	var detected: bool = guard.check_detection_on_thief(thief)
	assert_false(detected, "Ladrón fuera del ángulo del cono SpotLight3D no es detectado")


## Criterio 4: Fuera de la distancia máxima de la linterna (spot_range) no hay detección
func test_spotlight_detection_outside_range() -> void:
	var guard: GuardController3D = _create_guard(Vector3(0.0, 0.0, 0.0))
	guard.maglite_light.visible = true
	guard.maglite_light.spot_range = 8.0
	guard.look_target_position = Vector3(0.0, 1.5, -12.0)

	# Ladrón a 12m frente a la linterna (spot_range = 8m)
	var thief: ThiefController3D = _create_thief(Vector3(0.0, 0.6, -12.0))

	await wait_physics_frames(2)

	var detected: bool = guard.check_detection_on_thief(thief)
	assert_false(detected, "Ladrón más allá de spot_range no es detectado")


## Criterio 4: Detección de SpotLight3D con RayCast3D ocluido por muro
func test_spotlight_detection_blocked_by_wall() -> void:
	var guard: GuardController3D = _create_guard(Vector3(0.0, 0.0, 0.0))
	guard.maglite_light.visible = true
	guard.look_target_position = Vector3(0.0, 1.5, -6.0)

	var thief: ThiefController3D = _create_thief(Vector3(0.0, 0.6, -6.0))
	# Muro intermedio en Z = -3.0
	_create_obstacle_wall(Vector3(0.0, 1.5, -3.0))

	await wait_physics_frames(2)

	var detected: bool = guard.check_detection_on_thief(thief)
	assert_false(detected, "Muro opaco ocluye el haz de la linterna (RayCast3D choca)")


## Criterio 4: Linterna apagada (visible = false) no detecta a larga distancia
func test_spotlight_disabled_does_not_detect() -> void:
	var guard: GuardController3D = _create_guard(Vector3(0.0, 0.0, 0.0))
	guard.maglite_light.visible = false
	guard.look_target_position = Vector3(0.0, 1.5, -5.0)

	var thief: ThiefController3D = _create_thief(Vector3(0.0, 0.6, -5.0))

	await wait_physics_frames(2)

	var detected: bool = guard.check_detection_on_thief(thief)
	assert_false(detected, "Linterna apagada no produce detección a 5m")
