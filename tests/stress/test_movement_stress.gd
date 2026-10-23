## @file test_movement_stress.gd
## Pruebas de estrés y casos límite para modos de movimiento (FEAT-007).
extends GutTest


func _create_thief(pos: Vector3 = Vector3.ZERO) -> ThiefController3D:
	var thief: ThiefController3D = ThiefController3D.new()
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "CollisionShape3D"
	thief.add_child(col)
	thief.position = pos
	add_child_autofree(thief)
	return thief


func _create_floor() -> StaticBody3D:
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	floor_body.set_meta("noise_multiplier", 1.0)
	var col: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(20.0, 0.2, 20.0)
	col.shape = box
	floor_body.add_child(col)
	floor_body.position = Vector3(0.0, -0.1, 0.0)
	add_child_autofree(floor_body)
	return floor_body


## Criterio 16: 1.000 cambios alternos de agachado en 1.000 ticks no dejan tamaño intermedio.
func test_crouch_toggle_spam() -> void:
	_create_floor()
	var thief: ThiefController3D = _create_thief(Vector3(0.0, 0.05, 0.0))
	thief.set_physics_process(false)
	await wait_physics_frames(2)

	var capsule: CapsuleShape3D = thief.collision_shape.shape as CapsuleShape3D
	assert_not_null(capsule, "thief tiene CapsuleShape3D")

	watch_signals(thief)

	for i in range(1000):
		thief.apply_input({"movement_vector": Vector2(0.0, 1.0), "crouch": true})
		thief.simulate_movement(1.0 / 60.0)
		var exp_h: float = (
			CrouchCollision.CROUCH_HEIGHT if thief.is_crouching else CrouchCollision.STAND_HEIGHT
		)
		assert_almost_eq(capsule.height, exp_h, 0.001)

	assert_signal_emit_count(thief, "crouch_changed", 1000)
	assert_false(thief.is_crouching)


## Criterio 16: CharacterAnimator3D sin AnimationPlayer no falla.
func test_animator_without_animation_player() -> void:
	var player: PlayerBase3D = PlayerBase3D.new()
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
