## @file test_net_readiness.gd
## Tests de preparación de arquitectura de red (FEAT-002).
## Valida el desacoplamiento de Input, Simulación y Presentación,
## la ejecución headless en servidor dedicado y la autoridad sobre visibilidad,
## botín pesado e impactos de porra.
extends GutTest


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


func _create_guard(pos: Vector3 = Vector3.ZERO) -> GuardController3D:
	var guard: GuardController3D = autofree(GuardController3D.new())
	guard.position = pos
	guard.is_ai_controlled = true
	guard.look_target_position = pos + Vector3(0.0, 1.5, -5.0)

	var maglite: SpotLight3D = SpotLight3D.new()
	maglite.name = "Maglite"
	maglite.position = Vector3(0.0, 1.5, 0.0)
	maglite.spot_range = 10.0
	maglite.spot_angle = 35.0
	maglite.visible = false
	guard.add_child(maglite)
	guard.maglite_light = maglite

	add_child_autofree(guard)
	return guard


func _create_thief(pos: Vector3 = Vector3.ZERO) -> ThiefController3D:
	var thief: ThiefController3D = autofree(ThiefController3D.new())
	thief.position = pos
	add_child_autofree(thief)
	return thief


func _create_loot(name: String, value: int, is_heavy: bool) -> LootItem3D:
	var loot: LootItem3D = autofree(LootItem3D.new())
	loot.loot_name = name
	loot.loot_value = value
	loot.is_heavy = is_heavy
	add_child_autofree(loot)
	return loot


# ------------------------------------------------------------------------------
# 1. Simulación física en servidor headless sin Camera3D ni Viewport
# ------------------------------------------------------------------------------


func test_simulate_movement_headless_no_camera_or_viewport() -> void:
	var player: PlayerBase3D = autofree(PlayerBase3D.new())
	add_child_autofree(player)
	await wait_physics_frames(1)

	# Inyectar input hacia adelante en 2D (Y = 1 -> diagonal en XZ)
	player.apply_input({"movement_vector": Vector2(0.0, 1.0)})

	# Simular 5 frames físicos sin cámara ni viewport asignados
	for i in range(5):
		player.simulate_movement(0.05)

	assert_gt(player.velocity.x, 0.0, "Velocidad X positiva tras rotación 45°")
	assert_gt(player.velocity.z, 0.0, "Velocidad Z positiva tras rotación 45°")
	assert_almost_eq(player.velocity.x, player.velocity.z, 0.05, "Componentes simétricas a 45°")

	# Simular parada (input cero) y verificar desaceleración por fricción
	player.apply_input({"movement_vector": Vector2.ZERO})
	var vel_before_friction: float = player.velocity.length()
	player.simulate_movement(0.05)
	assert_lt(player.velocity.length(), vel_before_friction, "Fricción desacelera la entidad")


# ------------------------------------------------------------------------------
# 2. Desacoplamiento de Input y Presentación
# ------------------------------------------------------------------------------


func test_gather_input_and_apply_input_contracts() -> void:
	var player: PlayerBase3D = autofree(PlayerBase3D.new())
	add_child_autofree(player)
	await wait_physics_frames(1)

	# gather_input sin cámara devuelve un Dictionary estructurado
	var gathered: Dictionary = player.gather_input(null)
	assert_true(gathered.has("movement_vector"), "Dictionary contiene movement_vector")
	assert_true(gathered.has("is_sprinting"), "Dictionary contiene is_sprinting")
	assert_true(gathered.has("is_sneaking"), "Dictionary contiene is_sneaking")
	assert_true(gathered.has("look_target"), "Dictionary contiene look_target")

	# Inyectar paquete de input explícito
	var look_target: Vector3 = Vector3(15.0, 0.0, 20.0)
	var input_data: Dictionary = {
		"movement_vector": Vector2(1.0, 0.0),
		"is_sprinting": true,
		"is_sneaking": false,
		"look_target": look_target,
	}
	player.apply_input(input_data)

	assert_eq(player.current_input_dir, Vector2(1.0, 0.0), "current_input_dir almacenado")
	assert_true(player.is_sprinting, "is_sprinting almacenado")
	assert_false(player.is_sneaking, "is_sneaking almacenado")
	assert_eq(player.look_target_position, look_target, "look_target_position almacenado")


func test_input_injection_produces_expected_sprint_velocity() -> void:
	var thief: ThiefController3D = _create_thief(Vector3.ZERO)
	await wait_physics_frames(1)

	thief.apply_input({"movement_vector": Vector2(1.0, 0.0), "is_sprinting": true})

	# Simular tiempo suficiente para alcanzar velocidad de carrera del perfil (7.5 m/s)
	for i in range(20):
		thief.simulate_movement(0.05)

	var expected_sprint: float = thief.movement_profile.speed_for(MovementProfile.Mode.SPRINT)
	assert_eq(thief.current_speed, expected_sprint, "current_speed es sprint_speed (7.5)")
	var horizontal_speed: float = Vector2(thief.velocity.x, thief.velocity.z).length()
	assert_almost_eq(horizontal_speed, 7.5, 0.1, "Velocidad horizontal converge a 7.5 m/s")


func test_presentation_decoupling_does_not_mutate_physics() -> void:
	var player: PlayerBase3D = autofree(PlayerBase3D.new())
	add_child_autofree(player)
	await wait_physics_frames(1)

	player.position = Vector3(0.0, 0.0, 0.0)
	player.look_target_position = Vector3(5.0, 0.0, 0.0)
	player.velocity = Vector3(2.0, 0.0, 1.0)

	var prev_vel: Vector3 = player.velocity
	var prev_pos: Vector3 = player.position

	# update_presentation solo altera rotation.y, no la física
	player.update_presentation(0.1)

	assert_eq(player.velocity, prev_vel, "update_presentation no muta la velocidad física")
	assert_eq(player.position, prev_pos, "update_presentation no muta la posición")
	assert_ne(
		player.rotation.y, 0.0, "update_presentation interpola la orientación hacia el objetivo"
	)


# ------------------------------------------------------------------------------
# 3. Visibilidad autoritativa del ladrón
# ------------------------------------------------------------------------------


func test_authoritative_thief_visibility_within_proximity() -> void:
	var guard: GuardController3D = _create_guard(Vector3.ZERO)
	var thief: ThiefController3D = _create_thief(Vector3(0.0, 0.6, -1.2))
	await wait_physics_frames(2)

	# El servidor calcula la detección por proximidad
	var detected: bool = guard.check_detection_on_thief(thief)
	assert_true(detected, "Servidor detecta al ladrón en proximidad (<1.8m)")

	thief.set_stealth_visibility(detected)
	assert_true(thief.is_detected_by_guard, "Estado de detección autoritativo actualizado")
	assert_true(thief.is_visible_to_team(&"guard"), "Visible para guardias tras detección")
	assert_true(thief.is_visible_to_team(&"thief"), "Visible para equipo ladrón")


func test_authoritative_thief_hidden_behind_wall() -> void:
	var guard: GuardController3D = _create_guard(Vector3.ZERO)
	var thief: ThiefController3D = _create_thief(Vector3(0.0, 0.6, -1.4))
	_create_obstacle_wall(Vector3(0.0, 1.5, -0.7))
	await wait_physics_frames(2)

	# El servidor evalúa oclusión por muro
	var detected: bool = guard.check_detection_on_thief(thief)
	assert_false(detected, "Muro ocluye la detección en el servidor")

	thief.set_stealth_visibility(detected)
	assert_false(thief.is_detected_by_guard, "Ladrón no detectado en el servidor")
	assert_false(thief.is_visible_to_team(&"guard"), "Guardias no reciben visibilidad del ladrón")
	assert_true(
		thief.is_visible_to_team(&"thief"), "Ladrón conserva visibilidad para su propio equipo"
	)


# ------------------------------------------------------------------------------
# 4. Validación autoritativa de botín pesado y captura por porra
# ------------------------------------------------------------------------------


func test_authoritative_loot_rejection_for_non_thief() -> void:
	var guard: GuardController3D = _create_guard(Vector3.ZERO)
	var loot: LootItem3D = _create_loot("Reloj Suizo", 2500, false)
	await wait_physics_frames(1)

	assert_false(loot.can_interact(guard), "can_interact rechaza interacción de un guardia")
	loot.interact(guard)
	assert_false(loot.is_collected, "El botín no se recoge por actores no ladrones")


func test_authoritative_heavy_loot_mutual_exclusion_and_speed_penalty() -> void:
	var thief: ThiefController3D = _create_thief(Vector3.ZERO)
	var loot1: LootItem3D = _create_loot("Caja Fuerte Portatil", 8000, true)
	var loot2: LootItem3D = _create_loot("Escultura de Oro", 9000, true)
	await wait_physics_frames(1)

	# Recoger primer botín pesado
	assert_true(loot1.can_interact(thief), "Ladrón puede recoger primer botín pesado")
	loot1.interact(thief)
	assert_true(thief.is_carrying_heavy_loot, "Ladrón transporta botín pesado")
	assert_eq(thief.carried_loot, loot1, "Referencia de botín pesado activa")

	# Intentar recoger segundo botín pesado (debe ser rechazado por autoridad)
	assert_false(loot2.can_interact(thief), "can_interact rechaza segundo botín pesado")
	loot2.interact(thief)
	assert_false(loot2.is_collected, "Segundo botín permanece en el suelo")
	assert_eq(thief.carried_loot, loot1, "Ladrón mantiene solo el primer botín")

	# Simular movimiento con penalización de velocidad (-20%)
	thief.apply_input({"movement_vector": Vector2(1.0, 0.0)})
	for i in range(20):
		thief.simulate_movement(0.05)

	var horizontal_speed: float = Vector2(thief.velocity.x, thief.velocity.z).length()
	# Con move_speed = 5.0 y reducción x0.8 = 4.0
	assert_almost_eq(horizontal_speed, 4.0, 0.15, "Velocidad reducida al 80% (5.0 * 0.8 = 4.0)")

	# Soltar botín pesado restaura estado
	thief.drop_heavy_loot()
	assert_false(thief.is_carrying_heavy_loot, "Ya no transporta botín pesado")
	assert_true(thief.can_use_gadgets(), "Gadgets habilitados de nuevo")


func test_authoritative_baton_validation_los_and_range() -> void:
	var guard: GuardController3D = _create_guard(Vector3.ZERO)
	var thief: ThiefController3D = _create_thief(Vector3(0.0, 0.0, 2.5))
	await wait_physics_frames(1)

	# Fuera de rango (> 1.6m)
	assert_false(guard.validate_melee_hit(thief), "validate_melee_hit falla a 2.5m")
	assert_false(guard.swing_baton(thief), "swing_baton falla a 2.5m")
	assert_eq(thief.baton_hits_taken, 0, "No se registran impactos")

	# Acercar a 1.2m dentro del rango
	thief.position = Vector3(0.0, 0.0, 1.2)
	guard.baton_cooldown = 0.0
	await wait_physics_frames(1)

	assert_true(guard.validate_melee_hit(thief), "validate_melee_hit válido a 1.2m sin obstáculos")
	assert_true(guard.swing_baton(thief), "Primer impacto conecta")
	assert_eq(thief.baton_hits_taken, 1, "Impacto 1 registrado autoritativamente")


func test_authoritative_baton_wall_occlusion() -> void:
	var guard: GuardController3D = _create_guard(Vector3.ZERO)
	var thief: ThiefController3D = _create_thief(Vector3(0.0, 0.0, 1.2))
	# Muro intermedio bloqueando el golpe
	_create_obstacle_wall(Vector3(0.0, 1.0, 0.6))
	await wait_physics_frames(2)

	assert_false(guard.validate_melee_hit(thief), "Muro bloquea el golpe de porra")
	assert_false(guard.swing_baton(thief), "swing_baton rechazado por oclusión física")
	assert_eq(thief.baton_hits_taken, 0, "Cero impactos registrados tras muro")


func test_authoritative_baton_capture_progression() -> void:
	var guard: GuardController3D = _create_guard(Vector3.ZERO)
	var thief: ThiefController3D = _create_thief(Vector3(0.0, 0.0, 1.2))
	watch_signals(SignalBus)
	await wait_physics_frames(1)

	# Impacto 1
	var hit1: bool = guard.swing_baton(thief)
	assert_true(hit1, "Impacto 1 exitoso")
	assert_eq(thief.baton_hits_taken, 1, "1 impacto registrado")
	assert_signal_not_emitted(SignalBus, "thief_captured", "No capturado aún")

	# Spam de porra durante cooldown debe fallar
	var hit_spam: bool = guard.swing_baton(thief)
	assert_false(hit_spam, "Cooldown bloquea spam de golpes")
	assert_eq(thief.baton_hits_taken, 1, "Impactos se mantienen en 1")

	# Reset de cooldown y segundo impacto
	guard.baton_cooldown = 0.0
	var hit2: bool = guard.swing_baton(thief)
	assert_true(hit2, "Impacto 2 exitoso")
	assert_eq(thief.baton_hits_taken, 2, "2 impactos alcanzados")
	assert_signal_emitted(
		SignalBus, "thief_captured", "Señal thief_captured emitida por autoridad del servidor"
	)
