## @file test_stealth_stress.gd
## Suite de pruebas de estrés, robustez destructiva y edge cases extremos para FEAT-005.
## Audita la resiliencia de PlayerBase3D y CharacterAnimator3D ante condiciones adversas:
## 1. Spam continuo de transiciones de postura a alta frecuencia.
## 2. Bloqueo de espacio superior (headroom) bajo techos bajos estáticos y dinámicos.
## 3. Preservación cinemática con move_and_slide(), deltas extremos y vectores aberrantes.
## 4. Replicación de red headless y desacoplamiento absoluto de presentación visual.
## 5. Inmunidad a interferencia entre flags de sprint/sneak y posturas tácticas.
## 6. Tolerancia a fallos en CharacterAnimator3D sin AnimationPlayer (modo servidor dedicado).
extends GutTest

func _create_test_player(pos: Vector3 = Vector3.ZERO) -> PlayerBase3D:
	var player: PlayerBase3D = autofree(PlayerBase3D.new())
	player.position = pos
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.height = 1.6
	capsule.radius = 0.35
	col.shape = capsule
	col.position = Vector3(0.0, 0.8, 0.0)
	player.add_child(col)
	add_child_autofree(player)
	return player

func _create_ceiling(pos: Vector3, size: Vector3) -> StaticBody3D:
	var ceiling: StaticBody3D = autofree(StaticBody3D.new())
	ceiling.collision_layer = 1
	ceiling.collision_mask = 0
	ceiling.position = pos
	var col: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	col.shape = box
	ceiling.add_child(col)
	add_child_autofree(ceiling)
	return ceiling

# ------------------------------------------------------------------------------
# 1. Spam destructivo de posturas en bucle continuo
# ------------------------------------------------------------------------------

func test_stress_rapid_stance_spam_loop() -> void:
	var player: PlayerBase3D = _create_test_player()
	await wait_physics_frames(1)

	var sequence: Array[PlayerBase3D.Stance] = [
		PlayerBase3D.Stance.STAND,
		PlayerBase3D.Stance.CROUCH,
		PlayerBase3D.Stance.PRONE,
		PlayerBase3D.Stance.TIPTOE,
		PlayerBase3D.Stance.WALL_COVER,
		PlayerBase3D.Stance.PRONE,
		PlayerBase3D.Stance.STAND,
		PlayerBase3D.Stance.WALL_COVER,
		PlayerBase3D.Stance.CROUCH,
	]

	# Ejecutar 500 iteraciones de cambios continuos
	for i in range(500):
		var target: PlayerBase3D.Stance = sequence[i % sequence.size()]
		player.set_stance(target)

	# Comprobar que tras el spam, la cápsula coincide exactamente con la postura final
	var final_stance: PlayerBase3D.Stance = player.get_stance()
	var capsule: CapsuleShape3D = player.collision_shape.shape as CapsuleShape3D
	assert_not_null(capsule, "CapsuleShape3D sigue siendo valida tras 500 cambios de postura")

	match final_stance:
		PlayerBase3D.Stance.STAND, PlayerBase3D.Stance.TIPTOE:
			assert_almost_eq(capsule.height, 1.60, 0.001)
			assert_almost_eq(capsule.radius, 0.35, 0.001)
			assert_almost_eq(player.collision_shape.transform.origin.y, 0.80, 0.001)
		PlayerBase3D.Stance.CROUCH:
			assert_almost_eq(capsule.height, 1.00, 0.001)
			assert_almost_eq(capsule.radius, 0.35, 0.001)
			assert_almost_eq(player.collision_shape.transform.origin.y, 0.50, 0.001)
		PlayerBase3D.Stance.PRONE:
			assert_almost_eq(capsule.height, 0.40, 0.001)
			assert_almost_eq(capsule.radius, 0.20, 0.001)
			assert_almost_eq(player.collision_shape.transform.origin.y, 0.20, 0.001)
		PlayerBase3D.Stance.WALL_COVER:
			assert_almost_eq(capsule.height, 1.60, 0.001)
			assert_almost_eq(capsule.radius, 0.25, 0.001)
			assert_almost_eq(player.collision_shape.transform.origin.y, 0.80, 0.001)

	# Alternancia estricta y rápida entre CROUCH y PRONE (prueba de clamping de radio/altura)
	for i in range(100):
		if i % 2 == 0:
			player.set_stance(PlayerBase3D.Stance.CROUCH)
			assert_almost_eq(capsule.height, 1.00, 0.001)
			assert_almost_eq(capsule.radius, 0.35, 0.001)
		else:
			player.set_stance(PlayerBase3D.Stance.PRONE)
			assert_almost_eq(capsule.height, 0.40, 0.001)
			assert_almost_eq(capsule.radius, 0.20, 0.001)

	# Intento de reasignar la misma postura 50 veces consecutivas
	watch_signals(player)
	for i in range(50):
		var res: bool = player.set_stance(PlayerBase3D.Stance.PRONE)
		assert_false(res, "set_stance con la misma postura devuelve false")
	assert_signal_emit_count(player, "stance_changed", 0, "No se emiten señales redundantes")

# ------------------------------------------------------------------------------
# 2. Restricción de espacio superior bajo techos y obstáculos dinámicos
# ------------------------------------------------------------------------------

func test_stress_headroom_boundary_and_dynamic_clearance() -> void:
	# Techo bajo a 0.55m de altura (fondo en Y = 0.45m):
	# En PRONE (altura 0.40m) cabe; en CROUCH (1.0m) y STAND (1.6m) no.
	var low_ceiling: StaticBody3D = _create_ceiling(Vector3(0.0, 0.55, 0.0), Vector3(4.0, 0.2, 4.0))
	assert_not_null(low_ceiling)

	var player: PlayerBase3D = _create_test_player(Vector3.ZERO)
	await wait_physics_frames(2)

	player.set_stance(PlayerBase3D.Stance.PRONE)
	assert_eq(player.get_stance(), PlayerBase3D.Stance.PRONE)

	# 1. Intentar CROUCH bajo techo a 0.45m debe fallar
	assert_false(
		player.can_enter_stance(PlayerBase3D.Stance.CROUCH),
		"CROUCH bloqueado bajo techo de 0.45m"
	)
	assert_false(player.set_stance(PlayerBase3D.Stance.CROUCH), "Transición a CROUCH rechazada")
	assert_eq(player.get_stance(), PlayerBase3D.Stance.PRONE, "Permanece en PRONE")

	# 2. Intentar STAND bajo techo a 0.45m debe fallar
	assert_false(
		player.can_enter_stance(PlayerBase3D.Stance.STAND),
		"STAND bloqueado bajo techo de 0.45m"
	)
	assert_false(player.set_stance(PlayerBase3D.Stance.STAND), "Transición a STAND rechazada")
	assert_eq(player.get_stance(), PlayerBase3D.Stance.PRONE, "Permanece en PRONE")

	# 3. Spam de 50 peticiones a STAND atrapado bajo el obstáculo
	for i in range(50):
		var ok: bool = player.set_stance(PlayerBase3D.Stance.STAND)
		assert_false(ok)
	assert_eq(
		player.get_stance(),
		PlayerBase3D.Stance.PRONE,
		"Permanece inmune en PRONE tras 50 intentos"
	)

	# 4. Despeje dinámico: el jugador se desplaza fuera del área cubierta por el techo
	player.global_position = Vector3(10.0, 0.0, 10.0)
	await wait_physics_frames(2)

	# Ahora el espacio superior está completamente despejado
	assert_true(
		player.can_enter_stance(PlayerBase3D.Stance.STAND),
		"can_enter_stance(STAND) habilitado en zona despejada"
	)
	var stand_ok: bool = player.set_stance(PlayerBase3D.Stance.STAND)
	assert_true(stand_ok, "Transición a STAND autorizada fuera del obstáculo")
	assert_eq(player.get_stance(), PlayerBase3D.Stance.STAND)

# ------------------------------------------------------------------------------
# 3. Cinemática y move_and_slide() con deltas y velocidades aberrantes
# ------------------------------------------------------------------------------

func test_stress_extreme_velocities_and_deltas_in_all_stances() -> void:
	var player: PlayerBase3D = _create_test_player()
	await wait_physics_frames(1)

	var stances: Array[PlayerBase3D.Stance] = [
		PlayerBase3D.Stance.STAND,
		PlayerBase3D.Stance.TIPTOE,
		PlayerBase3D.Stance.CROUCH,
		PlayerBase3D.Stance.PRONE,
		PlayerBase3D.Stance.WALL_COVER,
	]

	for st: PlayerBase3D.Stance in stances:
		player.set_stance(st)
		player.velocity = Vector3.ZERO

		# Delta nulo (0.0s)
		player.simulate_movement(0.0)
		assert_eq(player.get_stance(), st, "Delta 0 preserva postura %s" % st)

		# Delta de frame drop masivo (5.0s)
		player.apply_input({"movement_vector": Vector2(1.0, 1.0)})
		player.simulate_movement(5.0)
		assert_false(is_nan(player.velocity.x), "Velocidad X no es NaN tras lag spike de 5s")
		assert_false(is_inf(player.velocity.x), "Velocidad X no es infinita tras lag spike de 5s")

		# Sub-delta insignificante (1e-5s)
		player.simulate_movement(0.00001)
		assert_false(is_nan(player.velocity.z), "Velocidad Z no es NaN con micro delta")

		# Input saturado extremo (10000.0, -10000.0)
		# Debe normalizarse y converger a max_expected_speed sin sobreacelerar
		player.velocity = Vector3.ZERO
		player.apply_input({"movement_vector": Vector2(10000.0, -10000.0)})
		for step in range(50):
			player.simulate_movement(0.05)
		var h_speed: float = Vector2(player.velocity.x, player.velocity.z).length()
		var max_expected_speed: float = player.move_speed * player.get_stance_speed_multiplier()
		assert_almost_eq(
			h_speed,
			max_expected_speed,
			0.05,
			"Velocidad normalizada acotada a pesar de vector de entrada desmesurado"
		)

		# Velocidad inicial negativa (-30.0 m/s)
		player.velocity = Vector3(-30.0, 0.0, -30.0)
		player.apply_input({"movement_vector": Vector2.ZERO})
		# Simular fricción de frenado (friction = 22.0 m/s^2; 30 steps * 0.1s = 3s desacelera > 60 m/s)
		for step in range(30):
			player.simulate_movement(0.1)
		var remaining_speed: float = Vector2(player.velocity.x, player.velocity.z).length()
		assert_almost_eq(
			remaining_speed,
			0.0,
			0.01,
			"La friccion frena completamente la entidad hasta el reposo"
		)
		player.velocity = Vector3.ZERO

# ------------------------------------------------------------------------------
# 4. Compatibilidad de red y desacoplamiento de nodos visuales
# ------------------------------------------------------------------------------

func test_stress_netcode_replication_headless_no_visuals() -> void:
	# Simulamos entidad servidora autoritativa pura (sin VisualRoot, sin Animator)
	var server_player: PlayerBase3D = _create_test_player(Vector3(1.0, 0.0, 1.0))
	# Simulamos cliente receptor remoto
	var client_player: PlayerBase3D = _create_test_player(Vector3.ZERO)
	await wait_physics_frames(1)

	var stances_to_test: Array[PlayerBase3D.Stance] = [
		PlayerBase3D.Stance.CROUCH,
		PlayerBase3D.Stance.PRONE,
		PlayerBase3D.Stance.WALL_COVER,
		PlayerBase3D.Stance.TIPTOE,
		PlayerBase3D.Stance.STAND,
	]

	for st: PlayerBase3D.Stance in stances_to_test:
		server_player.set_stance(st)

		# Empaquetar snapshot como se transmitiría por red (posición, velocidad, uint8 postura)
		var snapshot_pos: Vector3 = server_player.global_position
		var snapshot_vel: Vector3 = server_player.velocity
		var snapshot_stance: int = int(server_player.get_stance())

		# Cliente aplica snapshot recibido
		client_player.set_net_state(snapshot_pos, snapshot_vel, snapshot_stance)

		# Comprobar replicación fiel en cliente
		assert_eq(client_player.get_stance(), st, "Postura sincronizada limpiamente en cliente")
		assert_eq(client_player.net_target_position, snapshot_pos, "Posicion sincronizada")
		assert_eq(client_player.net_target_velocity, snapshot_vel, "Velocidad sincronizada")

		var s_capsule: CapsuleShape3D = server_player.collision_shape.shape as CapsuleShape3D
		var c_capsule: CapsuleShape3D = client_player.collision_shape.shape as CapsuleShape3D
		assert_almost_eq(
			c_capsule.height,
			s_capsule.height,
			0.001,
			"Altura colision identica servidor-cliente"
		)
		assert_almost_eq(
			c_capsule.radius,
			s_capsule.radius,
			0.001,
			"Radio colision identico servidor-cliente"
		)

	# Replicación con valor de postura anómalo / fuera de rango (-1 o 99)
	# No debe colapsar la simulación ni generar crashes
	client_player.set_net_state(Vector3.ZERO, Vector3.ZERO, 99)
	assert_not_null(
		client_player.collision_shape.shape,
		"Entidad sobrevive a postura invalida sin corromperse"
	)

# ------------------------------------------------------------------------------
# 5. Inmunidad a interferencia entre sprint/sneak y posturas tácticas
# ------------------------------------------------------------------------------

func test_stress_concurrent_crouch_sprint_sneak_interference() -> void:
	var player: PlayerBase3D = _create_test_player()
	await wait_physics_frames(1)

	# 1. En CROUCH, el flag is_sprinting no debe acelerar al jugador a velocidad de sprint (7.0 m/s)
	player.set_stance(PlayerBase3D.Stance.CROUCH)
	player.apply_input({
		"movement_vector": Vector2(0.0, 1.0),
		"is_sprinting": true,
	})
	for i in range(25):
		player.simulate_movement(0.05)

	var h_speed_crouch: float = Vector2(player.velocity.x, player.velocity.z).length()
	var expected_crouch_speed: float = player.move_speed * 0.55
	assert_almost_eq(
		h_speed_crouch,
		expected_crouch_speed,
		0.1,
		"En CROUCH con sprint activo, la velocidad sigue limitada al 55%"
	)

	# 2. En PRONE, sprint o sneak no deben anular la velocidad reducida al 25% (1.2 m/s)
	player.set_stance(PlayerBase3D.Stance.PRONE)
	player.apply_input({
		"movement_vector": Vector2(0.0, 1.0),
		"is_sprinting": true,
	})
	for i in range(25):
		player.simulate_movement(0.05)

	var h_speed_prone: float = Vector2(player.velocity.x, player.velocity.z).length()
	var expected_prone_speed: float = player.move_speed * 0.25
	assert_almost_eq(
		h_speed_prone,
		expected_prone_speed,
		0.1,
		"En PRONE con sprint activo, la velocidad sigue limitada al 25%"
	)

# ------------------------------------------------------------------------------
# 6. Tolerancia a fallos en CharacterAnimator3D sin AnimationPlayer (Headless Server)
# ------------------------------------------------------------------------------

func test_stress_character_animator_no_animation_player_crash_proof() -> void:
	var animator: CharacterAnimator3D = autofree(CharacterAnimator3D.new())
	add_child_autofree(animator)

	# No asignamos animation_player (escenario típico de servidor dedicado headless)
	assert_null(animator.animation_player, "animation_player es null")

	# Llamar a resolve_animation_name para todas las posturas y velocidades extremas
	var stances: Array[PlayerBase3D.Stance] = [
		PlayerBase3D.Stance.STAND,
		PlayerBase3D.Stance.TIPTOE,
		PlayerBase3D.Stance.CROUCH,
		PlayerBase3D.Stance.PRONE,
		PlayerBase3D.Stance.WALL_COVER,
	]

	for st: PlayerBase3D.Stance in stances:
		var track_idle: StringName = animator.resolve_animation_name(st, 0.0)
		assert_ne(track_idle, &"", "Retorna nombre valido en reposo para postura %s" % st)

		var track_moving: StringName = animator.resolve_animation_name(st, 3.5, true, false, 1.0)
		assert_ne(track_moving, &"", "Retorna nombre valido en movimiento para postura %s" % st)

	# Métodos de acción deben operar de forma segura sin lanzar error
	animator.play_action(&"walk")
	animator._play_if_not_active(&"walk")
	pass_test("CharacterAnimator3D opera de forma 100% segura en modo headless sin AnimationPlayer")
