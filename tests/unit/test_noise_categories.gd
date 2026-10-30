## @file test_noise_categories.gd
## Tests de aceptación para categorías y emisores de ruidos (FEAT-012 Criterio 1).
## Comprueba que cada emisor de la tabla emite con su categoría y emisor correctos.
extends GutTest

var _recorded: Array[Dictionary] = []


func after_each() -> void:
	GameManager.current_state = GameManager.MatchState.LOBBY
	_recorded.clear()
	if SignalBus.noise_event_3d.is_connected(_on_noise):
		SignalBus.noise_event_3d.disconnect(_on_noise)


func _on_noise(pos: Vector3, r: float, team: StringName, cat: StringName, em: Node) -> void:
	_recorded.append({"pos": pos, "radius": r, "team": team, "category": cat, "emitter": em})


## Criterio 1: Cada ruido lleva categoría y emisor según la tabla de emisores
func test_each_emitter_category() -> void:
	if not SignalBus.noise_event_3d.is_connected(_on_noise):
		SignalBus.noise_event_3d.connect(_on_noise)

	# 1. player_base_3d.gd (paso) -> step, self
	var thief: ThiefController3D = ThiefController3D.new()
	add_child_autofree(thief)
	thief.set_physics_process(false)
	var n: int = _recorded.size()
	thief._emit_step_sound()
	assert_eq(_recorded.size(), n + 1, "Paso debe emitir 1 ruido")
	var ev: Dictionary = _recorded.back()
	assert_eq(ev.category, &"step", "Paso debe tener categoría 'step'")
	assert_eq(ev.emitter, thief, "Emisor del paso debe ser self (el jugador)")

	# 2. guard_controller_3d.gd (linterna) -> mechanism, self
	var guard: GuardController3D = GuardController3D.new()
	add_child_autofree(guard)
	guard.set_physics_process(false)
	n = _recorded.size()
	guard.set_flashlight(true)  # el guardia humano la lleva apagada (#112)
	assert_eq(_recorded.size(), n + 1, "Linterna debe emitir 1 ruido")
	ev = _recorded.back()
	assert_eq(ev.category, &"mechanism", "Linterna debe tener categoría 'mechanism'")
	assert_eq(ev.emitter, guard, "Emisor de linterna debe ser el guardia")

	# 3. guard_controller_3d.gd (porra) -> impact, self
	n = _recorded.size()
	guard.swing_baton(null)
	assert_eq(_recorded.size(), n + 1, "Porra debe emitir 1 ruido")
	ev = _recorded.back()
	assert_eq(ev.category, &"impact", "Porra debe tener categoría 'impact'")
	assert_eq(ev.emitter, guard, "Emisor de porra debe ser el guardia")

	# 4. guard_controller_3d.gd (captura) -> impact, self
	n = _recorded.size()
	guard._capture_thief()
	assert_eq(_recorded.size(), n + 1, "Captura debe emitir 1 ruido")
	ev = _recorded.back()
	assert_eq(ev.category, &"impact", "Captura debe tener categoría 'impact'")
	assert_eq(ev.emitter, guard, "Emisor de captura debe ser el guardia")

	# 5. loot_item_3d.gd (ligero 2.5 m) -> clink (suena como la moneda, #111), el ladrón
	var loot_light: LootItem3D = LootItem3D.new()
	loot_light.is_heavy = false
	add_child_autofree(loot_light)
	n = _recorded.size()
	loot_light.interact(thief)
	assert_eq(_recorded.size(), n + 1, "Recogida de botín debe emitir 1 ruido")
	ev = _recorded.back()
	assert_eq(ev.category, &"clink", "Recogida de botín ligero debe ser 'clink'")
	assert_eq(ev.emitter, thief, "Emisor de recogida debe ser el ladrón")
	assert_almost_eq(ev.radius, 2.5, 0.01, "Radio de recogida ligera debe ser 2.5 m")

	# 6. loot_item_3d.gd (depósito pesado 3.5 m) -> impact, el ladrón
	var loot_heavy: LootItem3D = LootItem3D.new()
	loot_heavy.is_heavy = true
	loot_heavy.holder_thief = thief
	add_child_autofree(loot_heavy)
	n = _recorded.size()
	loot_heavy.deposit_into_trunk(Vector3.ZERO)
	assert_eq(_recorded.size(), n + 1, "Depósito pesado debe emitir 1 ruido")
	ev = _recorded.back()
	assert_eq(ev.category, &"impact", "Depósito de botín pesado debe ser 'impact'")
	assert_eq(ev.emitter, thief, "Emisor de depósito pesado debe ser el ladrón")
	assert_almost_eq(ev.radius, 3.5, 0.01, "Radio de depósito pesado debe ser 3.5 m")

	# 7. safe_box_3d.gd (con ladrón activo) -> dial (los demás lo oyen como mecanismo), el ladrón
	var safe: SafeBox3D = SafeBox3D.new()
	add_child_autofree(safe)
	safe.interact(thief)
	safe.current_dial_val = (safe.combination[0] + 10) % 100
	n = _recorded.size()
	safe.interact(thief)
	assert_eq(_recorded.size(), n + 1, "Confirmar número erróneo debe emitir 1 ruido")
	ev = _recorded.back()
	assert_eq(ev.category, &"dial", "Caja fuerte debe ser 'dial'")
	assert_eq(ev.emitter, thief, "Emisor de caja con ladrón activo debe ser el ladrón")

	# Caso self: no hay ruta pública con active_thief == null ya que la sesión requiere un ladrón
	safe.active_thief = null
	n = _recorded.size()
	safe._emit_acoustic_noise(6.0)
	assert_eq(_recorded.size(), n + 1, "Caja fuerte sin ladrón debe emitir 1 ruido")
	ev = _recorded.back()
	assert_eq(ev.category, &"mechanism", "Abrir la caja suena a mecanismo")
	assert_eq(ev.emitter, safe, "Emisor de caja sin ladrón debe ser self")

	# 8. escape_car_3d.gd -> mechanism, self
	var car: EscapeCar3D = EscapeCar3D.new()
	add_child_autofree(car)
	n = _recorded.size()
	car._execute_escape()
	assert_eq(_recorded.size(), n + 1, "Fuga en coche debe emitir 1 ruido")
	ev = _recorded.back()
	assert_eq(ev.category, &"mechanism", "Coche de fuga debe ser 'mechanism'")
	assert_eq(ev.emitter, car, "Emisor de coche de fuga debe ser self")

	# 9. time_clock_3d.gd (fichar) y guard_round.gd (campana del reloj al que llega tarde)
	var clock: TimeClock3D = TimeClock3D.new()
	clock.clock_id = 1
	add_child_autofree(clock)
	var round_node: GuardRound = GuardRound.attach(guard)
	round_node.assign([1, 2] as Array[int], [90.0, 90.0] as Array[float])
	n = _recorded.size()
	clock.interact(guard)
	assert_eq(_recorded.size(), n + 1, "Fichar debe emitir 1 ruido")
	ev = _recorded.back()
	assert_eq(ev.category, &"mechanism", "Fichar debe ser 'mechanism'")
	assert_eq(ev.emitter, guard, "Emisor al fichar debe ser el guardia que ficha")

	round_node.assign([1, 2] as Array[int], [90.0, 90.0] as Array[float])
	round_node.step(90.0)
	n = _recorded.size()
	round_node.step(3.0)
	assert_eq(_recorded.size(), n + 1, "Campana del reloj debe emitir 1 ruido")
	ev = _recorded.back()
	assert_eq(ev.category, &"mechanism", "Campana del fichador debe ser 'mechanism'")
	assert_eq(ev.emitter, clock, "Emisor de la campana debe ser el reloj")
	round_node.free()

	# 10. lamp_3d.gd (desenroscar) -> mechanism, el actor
	var lamp: Lamp3D = Lamp3D.new()
	var lamp_prof: LampProfile = LampProfile.new()
	lamp_prof.unscrewable = true
	lamp.profile = lamp_prof
	lamp.is_unscrewed = false
	add_child_autofree(lamp)
	n = _recorded.size()
	lamp.interact(thief)
	assert_eq(_recorded.size(), n + 1, "Desenroscar lámpara debe emitir 1 ruido")
	ev = _recorded.back()
	assert_eq(ev.category, &"mechanism", "Desenroscar lámpara debe ser 'mechanism'")
	assert_eq(ev.emitter, thief, "Emisor al desenroscar debe ser el actor")

	# 11. light_switch_3d.gd -> mechanism, el actor
	var switch: LightSwitch3D = LightSwitch3D.new()
	add_child_autofree(switch)
	var rules: LightRulesProfile = load("res://data/balance/light_rules.tres") as LightRulesProfile
	switch.rules = rules
	guard.interactor.current_target = switch
	switch.interact(guard)
	n = _recorded.size()
	switch._physics_process(rules.switch_time + 0.01)
	assert_eq(_recorded.size(), n + 1, "Pulsar interruptor debe emitir 1 ruido")
	ev = _recorded.back()
	assert_eq(ev.category, &"mechanism", "Interruptor debe ser 'mechanism'")
	assert_eq(ev.emitter, guard, "Emisor del interruptor debe ser el actor")
