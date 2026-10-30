## @file test_guard_capture.gd
## Tests de captura del ladrón mediante dos impactos de porra (Criterio 6 / GSD 1.0).
extends GutTest


func _create_guard(pos: Vector3 = Vector3.ZERO) -> GuardController3D:
	var guard: GuardController3D = autofree(GuardController3D.new())
	guard.position = pos
	guard.is_ai_controlled = true
	guard.look_target_position = pos + Vector3(0.0, 0.0, 3.0)  # mira hacia el ladrón (#112)
	add_child_autofree(guard)
	return guard


func _create_thief(pos: Vector3) -> ThiefController3D:
	var thief: ThiefController3D = autofree(ThiefController3D.new())
	thief.position = pos
	add_child_autofree(thief)
	return thief


## Criterio 6: Constantes de captura y cooldown
func test_capture_constants() -> void:
	assert_eq(ThiefController3D.REQUIRED_HITS_TO_CAPTURE, 2, "2 impactos para capturar")
	assert_almost_eq(
		GuardController3D.BATON_COOLDOWN_TIME, 0.75, 0.001, "Cooldown de porra es 0.75s"
	)


## Criterio 6: Golpe fuera del alcance melee (1.6m) falla y no cuenta como impacto
func test_swing_baton_misses_beyond_melee_range() -> void:
	var guard: GuardController3D = _create_guard(Vector3(0.0, 0.0, 0.0))
	# Ladrón a 2.5m de distancia (> 1.6m alcance melee)
	var thief: ThiefController3D = _create_thief(Vector3(0.0, 0.0, 2.5))
	await wait_physics_frames(1)

	var hit: bool = guard.swing_baton(thief)
	assert_false(hit, "El golpe falla a 2.5m (fuera de melee_range)")
	assert_eq(thief.baton_hits_taken, 0, "No se registra impacto en el ladrón")


## Criterio 6: Un solo impacto a 1.5m no captura al ladrón
func test_single_baton_impact_at_1_5m_does_not_capture() -> void:
	var guard: GuardController3D = _create_guard(Vector3(0.0, 0.0, 0.0))
	var thief: ThiefController3D = _create_thief(Vector3(0.0, 0.0, 1.5))
	var bus: Node = SignalBus
	watch_signals(bus)
	await wait_physics_frames(1)

	var hit: bool = guard.swing_baton(thief)
	assert_true(hit, "Primer impacto conecta con éxito a 1.5m")
	assert_eq(thief.baton_hits_taken, 1, "Ladrón registra exactamente 1 impacto recibido")
	assert_signal_not_emitted(bus, "thief_captured", "No se emite captura con 1 impacto")


## Criterio 6: El cooldown de porra impide golpes consecutivos instantáneos
func test_baton_cooldown_prevents_spam() -> void:
	var guard: GuardController3D = _create_guard(Vector3(0.0, 0.0, 0.0))
	var thief: ThiefController3D = _create_thief(Vector3(0.0, 0.0, 1.5))
	await wait_physics_frames(1)

	var hit1: bool = guard.swing_baton(thief)
	assert_true(hit1, "Primer impacto conecta")

	# Intento inmediato sin esperar el cooldown
	var hit2: bool = guard.swing_baton(thief)
	assert_false(hit2, "Segundo impacto inmediato es rechazado por cooldown activo")
	assert_eq(thief.baton_hits_taken, 1, "Sigue con 1 solo impacto registrado")


## Criterio 6: Dos impactos de porra a 1.5m atrapan al ladrón
func test_two_baton_impacts_at_1_5m_captures_thief() -> void:
	var guard: GuardController3D = _create_guard(Vector3(0.0, 0.0, 0.0))
	var thief: ThiefController3D = _create_thief(Vector3(0.0, 0.0, 1.5))
	var bus: Node = SignalBus
	watch_signals(bus)
	await wait_physics_frames(1)

	# Primer impacto
	var hit1: bool = guard.swing_baton(thief)
	assert_true(hit1, "Primer golpe conecta a 1.5m")
	assert_eq(thief.baton_hits_taken, 1, "1 impacto registrado")
	assert_signal_not_emitted(bus, "thief_captured", "Aún no capturado tras golpe 1")

	# Simular fin de cooldown
	guard.baton_cooldown = 0.0

	# Segundo impacto
	var hit2: bool = guard.swing_baton(thief)
	assert_true(hit2, "Segundo golpe conecta a 1.5m")
	assert_eq(thief.baton_hits_taken, 2, "2 impactos acumulados")
	assert_signal_emitted(bus, "thief_captured", "Señal thief_captured tras 2 impactos")

	var gm: Node = GameManager
	if gm != null:
		assert_eq(gm.get("current_state"), 3, "GameManager cambia a THIEF_CAPTURED (estado 3)")


## Criterio 6: Reinicio de impactos de porra acumulados
func test_reset_baton_hits() -> void:
	var thief: ThiefController3D = _create_thief(Vector3.ZERO)
	await wait_physics_frames(1)

	thief.register_baton_hit()
	assert_eq(thief.baton_hits_taken, 1, "Impacto registrado")

	thief.reset_baton_hits()
	assert_eq(thief.baton_hits_taken, 0, "Impactos reseteados a 0")
