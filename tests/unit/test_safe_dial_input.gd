## @file test_safe_dial_input.gd
## Girando el dial de la caja fuerte, las teclas de movimiento no mueven al ladrón (A/D giran
## el dial); al salir con Esc o abrir la caja vuelve a moverse.
extends GutTest

const THIEF_SCENE: PackedScene = preload("res://scenes/entities/thief_player.tscn")


func _setup() -> Array:
	var safe: SafeBox3D = SafeBox3D.new()
	add_child_autofree(safe)
	var thief: ThiefController3D = THIEF_SCENE.instantiate() as ThiefController3D
	add_child_autofree(thief)
	return [safe, thief]


func test_moving_keys_do_not_move_thief_while_cracking() -> void:
	var nodes: Array = _setup()
	var safe: SafeBox3D = nodes[0]
	var thief: ThiefController3D = nodes[1]
	safe.interact(thief)
	assert_true(thief.is_cracking_safe(), "Está con el dial")
	thief.apply_input({"movement_vector": Vector2(1.0, 0.0), "is_sprinting": true})
	assert_eq(thief.current_input_dir, Vector2.ZERO, "A/D no lo mueven")
	assert_false(thief.is_sprinting)
	safe.step_dial(1)
	assert_eq(safe.current_dial_val, 1, "El dial sí gira")


func test_moves_again_after_leaving_the_dial() -> void:
	var nodes: Array = _setup()
	var safe: SafeBox3D = nodes[0]
	var thief: ThiefController3D = nodes[1]
	safe.interact(thief)
	safe.cancel_cracking()
	assert_false(thief.is_cracking_safe())
	thief.apply_input({"movement_vector": Vector2(1.0, 0.0)})
	assert_eq(thief.current_input_dir, Vector2(1.0, 0.0), "Tras Esc vuelve a moverse")
