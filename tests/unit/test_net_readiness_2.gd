## @file test_net_readiness_2.gd
## Tests de preparación de arquitectura de red (FEAT-002), parte 2: autoridad sobre botín
## pesado e impactos de porra. El resto está en test_net_readiness.gd.
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
	guard.look_target_position = Vector3(0.0, 0.0, 3.0)  # mira hacia el ladrón (#112)
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
	guard.look_target_position = Vector3(0.0, 0.0, 3.0)  # mira hacia el ladrón (#112)
	var thief: ThiefController3D = _create_thief(Vector3(0.0, 0.0, 1.2))
	watch_signals(SignalBus)
	await wait_physics_frames(1)

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
