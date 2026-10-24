## @file test_time_clock.gd
## Tests del reloj mecánico de fichar de 90s (Criterio 7 / GSD 3.0).
extends GutTest


func _create_time_clock(id: int = 1) -> TimeClock3D:
	var clock: TimeClock3D = autofree(TimeClock3D.new())
	clock.clock_id = id
	add_child_autofree(clock)
	return clock


func _create_guard() -> GuardController3D:
	var guard: GuardController3D = autofree(GuardController3D.new())
	guard.is_ai_controlled = true
	add_child_autofree(guard)
	return guard


func _create_thief() -> ThiefController3D:
	var thief: ThiefController3D = autofree(ThiefController3D.new())
	add_child_autofree(thief)
	return thief


## Criterio 7: El ciclo de ronda está configurado por defecto a 90 segundos
func test_time_clock_constants_and_initial_state() -> void:
	assert_almost_eq(TimeClock3D.RULES.round_duration, 90.0, 0.001, "Ronda es 90.0s según GSD")

	var clock: TimeClock3D = _create_time_clock(1)
	await wait_physics_frames(1)

	assert_almost_eq(clock.round_duration, 90.0, 0.001, "round_duration inicial es 90.0s")
	assert_almost_eq(clock.time_left, 90.0, 0.001, "time_left inicial es 90.0s")
	assert_false(clock.is_expired, "El reloj no está vencido al inicio")


## Criterio 7: Restricción de rol: solo el guardia puede fichar, el ladrón no
func test_only_guard_can_interact_with_clock() -> void:
	var clock: TimeClock3D = _create_time_clock(1)
	var guard: GuardController3D = _create_guard()
	var thief: ThiefController3D = _create_thief()
	await wait_physics_frames(1)

	assert_true(clock.can_interact(guard), "El guardia tiene llave para fichar en el reloj")
	assert_false(clock.can_interact(thief), "El ladrón no puede interactuar con el reloj de ronda")
	assert_false(clock.can_interact(null), "Null devuelve false con seguridad")


## Criterio 7: El ladrón que intenta fichar no modifica el tiempo
func test_thief_cannot_reset_clock_timer() -> void:
	var clock: TimeClock3D = _create_time_clock(1)
	var thief: ThiefController3D = _create_thief()
	clock.time_left = 45.0
	await wait_physics_frames(1)

	clock.interact(thief)

	assert_almost_eq(clock.time_left, 45.0, 0.001, "El tiempo del reloj no se reinicia con ladron")


## Criterio 7: El guardia ficha con éxito y reinicia la cuenta atrás a 90s
func test_guard_punch_clock_resets_duration() -> void:
	var clock: TimeClock3D = _create_time_clock(2)
	var guard: GuardController3D = _create_guard()
	var bus: Node = SignalBus
	watch_signals(clock)
	watch_signals(bus)

	# Simular que han transcurrido 60 segundos (quedan 30s)
	clock.time_left = 30.0
	await wait_physics_frames(1)

	clock.interact(guard)

	assert_almost_eq(
		clock.time_left, 90.0, 0.001, "El temporizador se reinicia a los 90.0s de ronda"
	)
	assert_false(clock.is_expired, "El estado permanece no vencido")
	assert_signal_emitted(clock, "clock_punched", "Señal local clock_punched emitida")
	assert_signal_emitted(
		bus, "time_clock_punched", "Señal global time_clock_punched emitida en bus"
	)


## Criterio 7: Cuando transcurren los 90 segundos completos, expira y activa alarma
func test_clock_expiration_after_90_seconds() -> void:
	var clock: TimeClock3D = _create_time_clock(3)
	watch_signals(clock)
	await wait_physics_frames(1)

	# Simular avance de 90.1 segundos
	clock._update_countdown(90.1)

	assert_almost_eq(clock.time_left, 0.0, 0.001, "El tiempo se agota y se clampa a 0.0")
	assert_true(clock.is_expired, "El reloj entra en estado vencido / alarma")
	assert_signal_emitted(clock, "clock_expired", "Señal clock_expired emitida")

	var prompt_text: String = clock.get_interaction_text()
	assert_true(prompt_text.contains("ALARMA"), "El prompt refleja el estado de alarma")


## Criterio 7: El guardia puede fichar un reloj con alarma activa para cancelarla
func test_guard_recovers_expired_clock() -> void:
	var clock: TimeClock3D = _create_time_clock(4)
	var guard: GuardController3D = _create_guard()
	await wait_physics_frames(1)

	# Forzar estado de expiración
	clock._update_countdown(90.1)
	assert_true(clock.is_expired, "Alarma activa")

	# Guardia acude y ficha
	clock.interact(guard)

	assert_false(clock.is_expired, "La alarma se cancela al fichar")
	assert_almost_eq(clock.time_left, 90.0, 0.001, "El ciclo de ronda reinicia a 90.0s")
