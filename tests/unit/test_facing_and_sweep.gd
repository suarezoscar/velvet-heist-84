## @file test_facing_and_sweep.gd
## Pruebas de la orientación por movimiento, la linterna que se mantiene y el porrazo
## delante (#112).
extends GutTest


func before_each() -> void:
	LocalInput3D._facing = Vector3.ZERO
	LocalInput3D._facing_owner = 0
	GuardFlashlight.held = false


func after_each() -> void:
	LocalInput3D._facing = Vector3.ZERO
	LocalInput3D._facing_owner = 0
	GuardFlashlight.held = false


func _spawn_guard(ai: bool = false) -> GuardController3D:
	var guard: GuardController3D = autofree(GuardController3D.new())
	guard.is_ai_controlled = ai
	add_child_autofree(guard)
	return guard


func test_look_target_follows_movement_rotated_45() -> void:
	var player: PlayerBase3D = autofree(PlayerBase3D.new())
	add_child_autofree(player)
	var target: Vector3 = LocalInput3D.look_target(player, Vector2(1, 0), false, null)
	var expected: Vector3 = (
		player.global_position
		+ Vector3(1, 0, 0).rotated(Vector3.UP, deg_to_rad(45.0)) * LocalInput3D.FACING_DISTANCE
	)
	assert_true(
		target.is_equal_approx(expected), "El punto mirado queda en la dirección rotada 45°"
	)
	assert_almost_eq(
		player.global_position.distance_to(target),
		LocalInput3D.FACING_DISTANCE,
		0.001,
		"A FACING_DISTANCE del jugador"
	)


func test_look_target_keeps_last_side_when_still() -> void:
	var player: PlayerBase3D = autofree(PlayerBase3D.new())
	add_child_autofree(player)
	var walking: Vector3 = LocalInput3D.look_target(player, Vector2(1, 0), false, null)
	var still: Vector3 = LocalInput3D.look_target(player, Vector2.ZERO, false, null)
	assert_true(still.is_equal_approx(walking), "Parado mantiene el último lado")


func test_look_target_aiming_without_camera_returns_stored_target() -> void:
	var player: PlayerBase3D = autofree(PlayerBase3D.new())
	add_child_autofree(player)
	player.look_target_position = Vector3(4, 0, -2)
	var target: Vector3 = LocalInput3D.look_target(player, Vector2(1, 0), true, null)
	assert_eq(target, Vector3(4, 0, -2), "Apuntando sin cámara se queda el punto guardado")


func test_flashlight_step_transitions() -> void:
	assert_eq(GuardFlashlight.step(true), GuardFlashlight.TURN_ON, "Pulsar enciende")
	assert_eq(GuardFlashlight.step(true), &"", "Mantener no pide nada")
	assert_eq(GuardFlashlight.step(false), GuardFlashlight.TURN_OFF, "Soltar apaga")
	assert_eq(GuardFlashlight.step(false), &"", "Sin pulsar no pide nada")


func test_human_guard_starts_with_flashlight_off() -> void:
	var guard: GuardController3D = _spawn_guard()
	assert_false(guard.flashlight_on, "El guardia humano empieza con la linterna apagada")
	assert_true(guard.perform_action(&"flashlight_on"), "flashlight_on se ejecuta")
	assert_true(guard.flashlight_on, "Queda encendida")


func test_ai_guard_starts_with_flashlight_on() -> void:
	var guard: GuardController3D = _spawn_guard(true)
	assert_true(guard.flashlight_on, "La IA lleva la linterna encendida")


func test_sweeping_guard_cannot_sprint() -> void:
	var guard: GuardController3D = _spawn_guard()
	guard.perform_action(&"flashlight_on")
	guard.is_sprinting = true
	guard.simulate_movement(0.016)
	assert_false(guard.is_sprinting, "Barriendo no corre")
	assert_true(guard.is_sneaking, "Barriendo va en modo sigilo")


func _thief_at(guard: GuardController3D, offset: Vector3) -> ThiefController3D:
	var thief: ThiefController3D = autofree(ThiefController3D.new())
	add_child_autofree(thief)
	thief.global_position = guard.global_position + offset
	return thief


func test_baton_hits_in_front_but_not_behind() -> void:
	var guard: GuardController3D = _spawn_guard()
	guard.look_target_position = guard.global_position + Vector3(0, 0, -3)
	var front: ThiefController3D = _thief_at(guard, Vector3(0, 0, -1))
	assert_true(guard.validate_melee_hit(front), "Un ladrón a 1 m delante recibe el porrazo")
	front.global_position = guard.global_position + Vector3(0, 0, 1)
	assert_false(guard.validate_melee_hit(front), "Uno a 1 m detrás no")
