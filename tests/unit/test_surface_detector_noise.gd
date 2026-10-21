## @file test_surface_detector_noise.gd
## Pruebas de caracterización para el cálculo acústico de superficies (Criterio 3 / GSD 4.1).
extends GutTest


## Verifica que las constantes de multiplicador acústico coinciden con la especificación GSD 4.1
func test_surface_detector_constants() -> void:
	assert_eq(SurfaceDetector3D.CARPET_NOISE_MULTIPLIER, 0.2, "Alfombra reduce el ruido a 0.2")
	assert_eq(SurfaceDetector3D.WOOD_PARQUET_NOISE_MULTIPLIER, 1.5, "Parqué amplifica ruido a 1.5")
	assert_eq(SurfaceDetector3D.MARBLE_NOISE_MULTIPLIER, 1.2, "Mármol amplifica ruido a 1.2")
	assert_eq(SurfaceDetector3D.DEFAULT_NOISE_MULTIPLIER, 1.0, "Multiplicador neutro 1.0")


## Verifica que los recursos de balance en data/balance/ definen los multiplicadores exactos
func test_data_balance_surface_resources() -> void:
	var carpet_res: Resource = load("res://data/balance/surface_carpet.tres")
	assert_not_null(carpet_res, "El recurso de balance de alfombra existe")
	assert_eq(carpet_res.get("surface_id"), &"carpet", "ID alfombra correcto")
	var carpet_mult: float = float(carpet_res.get("noise_multiplier"))
	assert_almost_eq(carpet_mult, 0.2, 0.001, "Multiplicador alfombra 0.2")

	var parquet_res: Resource = load("res://data/balance/surface_wood_parquet.tres")
	assert_not_null(parquet_res, "El recurso de balance de parqué existe")
	assert_eq(parquet_res.get("surface_id"), &"wood_parquet", "ID parqué correcto")
	var parquet_mult: float = float(parquet_res.get("noise_multiplier"))
	assert_almost_eq(parquet_mult, 1.5, 0.001, "Multiplicador parqué 1.5")

	var marble_res: Resource = load("res://data/balance/surface_marble.tres")
	assert_not_null(marble_res, "El recurso de balance de mármol existe")
	assert_eq(marble_res.get("surface_id"), &"marble", "ID mármol correcto")
	var marble_mult: float = float(marble_res.get("noise_multiplier"))
	assert_almost_eq(marble_mult, 1.2, 0.001, "Multiplicador mármol 1.2")


## Verifica el comportamiento por defecto de SurfaceDetector3D cuando no hay colisión
func test_surface_detector_default_without_collision() -> void:
	var detector: SurfaceDetector3D = autofree(SurfaceDetector3D.new())
	add_child_autofree(detector)

	var mult: float = detector.get_surface_noise_multiplier()
	assert_eq(mult, 1.0, "Sin colisión de suelo devuelve DEFAULT_NOISE_MULTIPLIER (1.0)")

	var base_radius: float = 3.5
	var walk_noise: float = detector.calculate_step_noise_radius(base_radius, false, false)
	assert_almost_eq(walk_noise, 3.5, 0.001, "Ruido base sin superficie es 3.5m")

	var sprint_noise: float = detector.calculate_step_noise_radius(base_radius, true, false)
	assert_almost_eq(sprint_noise, 7.0, 0.001, "Correr duplica el ruido base (7.0m)")

	var sneak_noise: float = detector.calculate_step_noise_radius(base_radius, false, true)
	assert_almost_eq(sneak_noise, 1.05, 0.001, "Sigilo reduce un 70% el ruido base (1.05m)")


## Verifica la detección física de alfombra (0.2) en el mundo 3D
func test_surface_carpet_detection_and_acoustics() -> void:
	var floor_body: StaticBody3D = autofree(StaticBody3D.new())
	floor_body.collision_layer = SurfaceDetector3D.ENVIRONMENT_COLLISION_MASK
	floor_body.set_meta("noise_multiplier", 0.2)
	var col_shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(10.0, 0.2, 10.0)
	col_shape.shape = box
	floor_body.add_child(col_shape)
	floor_body.position = Vector3(0.0, -0.1, 0.0)
	add_child_autofree(floor_body)

	var detector: SurfaceDetector3D = autofree(SurfaceDetector3D.new())
	detector.position = Vector3(0.0, 0.5, 0.0)
	add_child_autofree(detector)

	await wait_physics_frames(2)

	var mult: float = detector.get_surface_noise_multiplier()
	assert_almost_eq(mult, 0.2, 0.01, "Detecta multiplicador 0.2 para alfombra")

	var base: float = 3.5
	var walk: float = detector.calculate_step_noise_radius(base, false, false)
	assert_almost_eq(walk, 0.7, 0.01, "Paso normal en alfombra: 3.5 * 0.2 = 0.7m")

	var sprint: float = detector.calculate_step_noise_radius(base, true, false)
	assert_almost_eq(sprint, 1.4, 0.01, "Sprint en alfombra: 7.0 * 0.2 = 1.4m")

	var sneak: float = detector.calculate_step_noise_radius(base, false, true)
	assert_almost_eq(sneak, 0.21, 0.01, "Sigilo en alfombra: 1.05 * 0.2 = 0.21m")


## Verifica la detección física de parqué de madera (1.5) en el mundo 3D
func test_surface_parquet_detection_and_acoustics() -> void:
	var floor_body: StaticBody3D = autofree(StaticBody3D.new())
	floor_body.collision_layer = SurfaceDetector3D.ENVIRONMENT_COLLISION_MASK
	floor_body.set_meta("noise_multiplier", 1.5)
	var col_shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(10.0, 0.2, 10.0)
	col_shape.shape = box
	floor_body.add_child(col_shape)
	floor_body.position = Vector3(0.0, -0.1, 0.0)
	add_child_autofree(floor_body)

	var detector: SurfaceDetector3D = autofree(SurfaceDetector3D.new())
	detector.position = Vector3(0.0, 0.5, 0.0)
	add_child_autofree(detector)

	await wait_physics_frames(2)

	var mult: float = detector.get_surface_noise_multiplier()
	assert_almost_eq(mult, 1.5, 0.01, "Detecta multiplicador 1.5 para parqué")

	var base: float = 3.5
	var walk: float = detector.calculate_step_noise_radius(base, false, false)
	assert_almost_eq(walk, 5.25, 0.01, "Paso normal en parqué: 3.5 * 1.5 = 5.25m")

	var sprint: float = detector.calculate_step_noise_radius(base, true, false)
	assert_almost_eq(sprint, 10.5, 0.01, "Sprint en parqué: 7.0 * 1.5 = 10.5m")

	var sneak: float = detector.calculate_step_noise_radius(base, false, true)
	assert_almost_eq(sneak, 1.575, 0.01, "Sigilo en parqué: 1.05 * 1.5 = 1.575m")


## Verifica la detección física de mármol (1.2) en el mundo 3D
func test_surface_marble_detection_and_acoustics() -> void:
	var floor_body: StaticBody3D = autofree(StaticBody3D.new())
	floor_body.collision_layer = SurfaceDetector3D.ENVIRONMENT_COLLISION_MASK
	floor_body.set_meta("noise_multiplier", 1.2)
	var col_shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(10.0, 0.2, 10.0)
	col_shape.shape = box
	floor_body.add_child(col_shape)
	floor_body.position = Vector3(0.0, -0.1, 0.0)
	add_child_autofree(floor_body)

	var detector: SurfaceDetector3D = autofree(SurfaceDetector3D.new())
	detector.position = Vector3(0.0, 0.5, 0.0)
	add_child_autofree(detector)

	await wait_physics_frames(2)

	var mult: float = detector.get_surface_noise_multiplier()
	assert_almost_eq(mult, 1.2, 0.01, "Detecta multiplicador 1.2 para mármol")

	var base: float = 3.5
	var walk: float = detector.calculate_step_noise_radius(base, false, false)
	assert_almost_eq(walk, 4.2, 0.01, "Paso normal en mármol: 3.5 * 1.2 = 4.2m")

	var sprint: float = detector.calculate_step_noise_radius(base, true, false)
	assert_almost_eq(sprint, 8.4, 0.01, "Sprint en mármol: 7.0 * 1.2 = 8.4m")

	var sneak: float = detector.calculate_step_noise_radius(base, false, true)
	assert_almost_eq(sneak, 1.26, 0.01, "Sigilo en mármol: 1.05 * 1.2 = 1.26m")
