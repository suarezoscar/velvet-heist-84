## @file test_step_cadence.gd
## Cadencia de los pasos (#109): el intervalo sale de la animación y el primer paso es inmediato.
extends GutTest

const THIEF_PROFILE_PATH: String = "res://data/balance/movement_thief.tres"
const DELTA: float = 1.0 / 60.0

var _steps: int = 0


func _on_noise(
	_pos: Vector3, _radius: float, _team: StringName, category: StringName, _emitter: Node
) -> void:
	if category == NoiseEmit.STEP:
		_steps += 1


func before_each() -> void:
	_steps = 0
	SignalBus.noise_event_3d.connect(_on_noise)


func after_each() -> void:
	SignalBus.noise_event_3d.disconnect(_on_noise)


func _create_thief() -> ThiefController3D:
	var thief: ThiefController3D = ThiefController3D.new()
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "CollisionShape3D"
	thief.add_child(col)
	add_child_autofree(thief)
	return thief


func test_step_interval_values() -> void:
	var walk: MovementProfile.Mode = MovementProfile.Mode.WALK
	assert_almost_eq(CharacterAnimator3D.step_interval(walk, 1.6), 0.533, 0.002, "WALK 1,6 m/s")
	assert_almost_eq(
		CharacterAnimator3D.step_interval(walk, 5.0), 1.0667 / 6.0, 0.002, "WALK 5 m/s satura"
	)
	assert_almost_eq(
		CharacterAnimator3D.step_interval(MovementProfile.Mode.SNEAK, 1.2), 0.55, 0.002, "SNEAK"
	)
	assert_almost_eq(
		CharacterAnimator3D.step_interval(MovementProfile.Mode.CROUCH, 1.2), 0.533, 0.002, "CROUCH"
	)
	assert_almost_eq(
		CharacterAnimator3D.step_interval(walk, 0.0),
		1.0667 / (2.0 * CharacterAnimator3D.MIN_PLAYBACK_SPEED),
		0.002,
		"Velocidad 0 usa la reproducción mínima"
	)


func test_first_step_is_immediate_after_start_and_after_stop() -> void:
	var thief: ThiefController3D = _create_thief()
	thief.current_input_dir = Vector2(1.0, 0.0)
	thief.simulate_movement(DELTA)
	assert_eq(_steps, 1, "El primer paso suena en el primer tick con input")

	thief.current_input_dir = Vector2.ZERO
	for i: int in 10:
		thief.simulate_movement(DELTA)
	_steps = 0
	thief.current_input_dir = Vector2(1.0, 0.0)
	thief.simulate_movement(DELTA)
	assert_eq(_steps, 1, "Tras parar y volver a andar, suena otra vez al instante")


func test_step_count_matches_interval() -> void:
	var thief: ThiefController3D = _create_thief()
	thief.current_input_dir = Vector2(1.0, 0.0)
	for i: int in 30:  # termina de acelerar
		thief.simulate_movement(DELTA)
	_steps = 0
	var speed: float = thief.velocity.slide(Vector3.UP).length()
	var interval: float = CharacterAnimator3D.step_interval(thief.get_move_mode(), speed)
	for i: int in 120:  # 2 s
		thief.simulate_movement(DELTA)
	assert_almost_eq(float(_steps), 2.0 / interval, 1.0, "Pasos en 2 s ≈ 2 / intervalo")
