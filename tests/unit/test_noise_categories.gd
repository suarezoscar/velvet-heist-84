## @file test_noise_categories.gd
## Tests de aceptación para categorías y emisores de ruidos (FEAT-012 Criterio 1).
## Comprueba que cada emisor de la tabla emite con su categoría y emisor correctos.
extends GutTest

var _recorded: Array[Dictionary] = []


func after_each() -> void:
	GameManager.current_state = GameManager.MatchState.LOBBY
	_recorded.clear()


func _on_noise(pos: Vector3, r: float, team: StringName, cat: StringName, em: Node) -> void:
	_recorded.append({"pos": pos, "radius": r, "team": team, "category": cat, "emitter": em})


## Criterio 1: Cada ruido lleva categoría y emisor según la tabla de emisores
func test_each_emitter_category() -> void:
	SignalBus.noise_event_3d.connect(_on_noise)

	# 1. player_base_3d.gd (paso) -> step, self
	var thief: ThiefController3D = autofree(ThiefController3D.new())
	add_child_autofree(thief)
	thief.set_physics_process(false)
	thief._emit_step_sound()
	assert_gt(_recorded.size(), 0, "Paso debe emitir ruido")
	var ev: Dictionary = _recorded.back()
	assert_eq(ev.category, &"step", "Paso debe tener categoría 'step'")
	assert_eq(ev.emitter, thief, "Emisor del paso debe ser self (el jugador)")

	# 2. guard_controller_3d.gd (linterna) -> mechanism, self
	var guard: GuardController3D = autofree(GuardController3D.new())
	add_child_autofree(guard)
	guard.set_physics_process(false)
	guard.set_flashlight(false)
	ev = _recorded.back()
	assert_eq(ev.category, &"mechanism", "Linterna debe tener categoría 'mechanism'")
	assert_eq(ev.emitter, guard, "Emisor de linterna debe ser el guardia")

	# 3. guard_controller_3d.gd (porra) -> impact, self
	guard.swing_baton(null)
	ev = _recorded.back()
	assert_eq(ev.category, &"impact", "Porra debe tener categoría 'impact'")
	assert_eq(ev.emitter, guard, "Emisor de porra debe ser el guardia")

	# 4. guard_controller_3d.gd (captura) -> impact, self
	guard._capture_thief()
	ev = _recorded.back()
	assert_eq(ev.category, &"impact", "Captura debe tener categoría 'impact'")
	assert_eq(ev.emitter, guard, "Emisor de captura debe ser el guardia")

	# 5. loot_item_3d.gd (ligero 2.5 m) -> impact, el ladrón
	var loot_light: LootItem3D = autofree(LootItem3D.new())
	loot_light.is_heavy = false
	add_child_autofree(loot_light)
	loot_light.interact(thief)
	ev = _recorded.back()
	assert_eq(ev.category, &"impact", "Recogida de botín ligero debe ser 'impact'")
	assert_eq(ev.emitter, thief, "Emisor de recogida debe ser el ladrón")
	assert_almost_eq(ev.radius, 2.5, 0.01, "Radio de recogida ligera debe ser 2.5 m")

	# 6. loot_item_3d.gd (depósito pesado 3.5 m) -> impact, el ladrón
	var loot_heavy: LootItem3D = autofree(LootItem3D.new())
	loot_heavy.is_heavy = true
	loot_heavy.holder_thief = thief
	add_child_autofree(loot_heavy)
	loot_heavy.deposit_into_trunk(Vector3.ZERO)
	ev = _recorded.back()
	assert_eq(ev.category, &"impact", "Depósito de botín pesado debe ser 'impact'")
	assert_eq(ev.emitter, thief, "Emisor de depósito pesado debe ser el ladrón")
	assert_almost_eq(ev.radius, 3.5, 0.01, "Radio de depósito pesado debe ser 3.5 m")

	# 7. safe_box_3d.gd (con ladrón activo y sin él) -> mechanism
	var safe: SafeBox3D = autofree(SafeBox3D.new())
	add_child_autofree(safe)
	safe.active_thief = thief
	safe._emit_acoustic_noise(1.8)
	ev = _recorded.back()
	assert_eq(ev.category, &"mechanism", "Caja fuerte debe ser 'mechanism'")
	assert_eq(ev.emitter, thief, "Emisor de caja con ladrón activo debe ser el ladrón")

	safe.active_thief = null
	safe._emit_acoustic_noise(6.0)
	ev = _recorded.back()
	assert_eq(ev.category, &"mechanism", "Caja fuerte debe ser 'mechanism'")
	assert_eq(ev.emitter, safe, "Emisor de caja sin ladrón debe ser self")

	# 8. escape_car_3d.gd -> mechanism, self
	var car: EscapeCar3D = autofree(EscapeCar3D.new())
	add_child_autofree(car)
	car._execute_escape()
	ev = _recorded.back()
	assert_eq(ev.category, &"mechanism", "Coche de fuga debe ser 'mechanism'")
	assert_eq(ev.emitter, car, "Emisor de coche de fuga debe ser self")

	# 9. time_clock_3d.gd (fichar y alarma) -> mechanism
	var clock: TimeClock3D = autofree(TimeClock3D.new())
	add_child_autofree(clock)
	clock.interact(guard)
	ev = _recorded.back()
	assert_eq(ev.category, &"mechanism", "Fichar debe ser 'mechanism'")
	assert_eq(ev.emitter, guard, "Emisor al fichar debe ser el guardia que ficha")

	clock._emit_alarm_noise(14.0)
	ev = _recorded.back()
	assert_eq(ev.category, &"mechanism", "Alarma de fichador debe ser 'mechanism'")
	assert_eq(ev.emitter, clock, "Emisor de alarma debe ser self")

	# 10. lamp_3d.gd (desenroscar) -> mechanism, el actor
	var lamp: Lamp3D = autofree(Lamp3D.new())
	var lamp_prof: LampProfile = LampProfile.new()
	lamp_prof.unscrewable = true
	lamp.profile = lamp_prof
	lamp.is_unscrewed = false
	add_child_autofree(lamp)
	lamp.interact(thief)
	ev = _recorded.back()
	assert_eq(ev.category, &"mechanism", "Desenroscar lámpara debe ser 'mechanism'")
	assert_eq(ev.emitter, thief, "Emisor al desenroscar debe ser el actor")

	# 11. light_switch_3d.gd -> mechanism, el actor
	var switch: LightSwitch3D = autofree(LightSwitch3D.new())
	add_child_autofree(switch)
	switch._complete_switch(guard)
	ev = _recorded.back()
	assert_eq(ev.category, &"mechanism", "Interruptor debe ser 'mechanism'")
	assert_eq(ev.emitter, guard, "Emisor del interruptor debe ser el actor")

	SignalBus.noise_event_3d.disconnect(_on_noise)
