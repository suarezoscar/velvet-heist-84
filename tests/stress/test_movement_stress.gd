## @file test_movement_stress.gd
## Pruebas de estrés y casos límite para modos de movimiento (FEAT-007).
extends GutTest


func _create_thief(pos: Vector3 = Vector3.ZERO) -> ThiefController3D:
	var thief: ThiefController3D = autofree(ThiefController3D.new())
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "CollisionShape3D"
	thief.add_child(col)
	thief.global_position = pos
	add_child_autofree(thief)
	return thief


func _create_floor() -> StaticBody3D:
	var floor_body: StaticBody3D = autofree(StaticBody3D.new())
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	floor_body.set_meta("noise_multiplier", 1.0)
	var col: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(20.0, 0.2, 20.0)
	col.shape = box
	floor_body.add_child(col)
	floor_body.global_position = Vector3(0.0, -0.1, 0.0)
	add_child_autofree(floor_body)
	return floor_body


## Criterio 16: 1.000 cambios alternos de agachado en 1.000 ticks no dejan tamaño intermedio.
func test_crouch_toggle_spam() -> void:
	_create_floor()
	var thief: ThiefController3D = _create_thief(Vector3(0.0, 0.05, 0.0))
	await wait_physics_frames(2)

	var capsule: CapsuleShape3D = thief.collision_shape.shape as CapsuleShape3D
	assert_not_null(capsule, "thief tiene CapsuleShape3D")

	for i in range(1000):
		thief.apply_input({"movement_vector": Vector2(0.0, 1.0), "crouch": true})
		thief.simulate_movement(1.0 / 60.0)
		var h: float = capsule.height
		var is_stand: bool = is_equal_approx(h, CrouchCollision.STAND_HEIGHT)
		var is_crouch: bool = is_equal_approx(h, CrouchCollision.CROUCH_HEIGHT)
		if not is_stand and not is_crouch:
			assert_true(false, "Altura intermedia detectada en tick %d: %f" % [i, h])
			return

	var expected_h: float = CrouchCollision.STAND_HEIGHT
	if thief.is_crouching:
		expected_h = CrouchCollision.CROUCH_HEIGHT
	assert_almost_eq(capsule.height, expected_h, 0.001, "Altura final de cápsula válida")
	assert_almost_eq(
		thief.collision_shape.transform.origin.y,
		expected_h * 0.5,
		0.001,
		"Origen Y es la mitad de altura",
	)
	assert_almost_eq(
		capsule.radius,
		CrouchCollision.CAPSULE_RADIUS,
		0.001,
		"Radio se mantiene inalterado",
	)


## Criterio 16: CharacterAnimator3D sin AnimationPlayer no falla.
func test_animator_without_animation_player() -> void:
	var player: PlayerBase3D = autofree(PlayerBase3D.new())
	add_child_autofree(player)

	var animator: CharacterAnimator3D = autofree(CharacterAnimator3D.new())
	player.add_child(animator)
	animator.animation_player = null

	animator._process(0.016)

	var walk_anim: StringName = animator.resolve_animation_name(MovementProfile.Mode.WALK, 2.0)
	assert_eq(walk_anim, &"walk", "Animador resuelve walk sin AnimationPlayer")

	var idle_anim: StringName = animator.resolve_animation_name(MovementProfile.Mode.CROUCH, 0.0)
	assert_eq(idle_anim, &"idle_crouch", "Animador resuelve idle_crouch sin AnimationPlayer")

	animator.play_action(&"punch")
	assert_true(true, "CharacterAnimator3D sin AnimationPlayer no falla")
