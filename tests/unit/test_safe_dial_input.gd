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


## #164: llega a la caja en diagonal, gira el dial y el ladrón ya no la tiene delante: la E
## confirma igual (antes iba a lo que tuviera delante el interactor, o a nada)
func test_e_confirms_the_safe_even_if_the_thief_looks_away() -> void:
	var nodes: Array = _setup()
	var safe: SafeBox3D = nodes[0]
	var thief: ThiefController3D = nodes[1]
	safe.combination.assign([1, 2, 3])
	safe.global_position = Vector3(0.0, 0.0, -1.2)
	thief.global_position = Vector3.ZERO
	safe.interact(thief)
	thief.rotation.y = PI * 0.5  # mirando a otro lado: la caja fuera de su abanico
	await wait_physics_frames(2)
	assert_ne(thief.interactor.current_target, safe, "No la tiene delante")
	safe.step_dial(1)
	assert_true(thief.perform_action(&"interact"))
	assert_eq(safe.current_stage, 1, "La E confirma el número")


func test_dial_keys_do_not_turn_the_thief() -> void:
	var nodes: Array = _setup()
	var safe: SafeBox3D = nodes[0]
	var thief: ThiefController3D = nodes[1]
	safe.interact(thief)
	thief.look_target_position = Vector3(0.0, 0.0, -5.0)
	thief.apply_input(
		{"movement_vector": Vector2(-1.0, 0.0), "look_target": Vector3(-5.0, 0.0, 0.0)}
	)
	assert_eq(thief.look_target_position, Vector3(0.0, 0.0, -5.0), "Sigue mirando a la caja")
	safe.cancel_cracking()
	thief.apply_input(
		{"movement_vector": Vector2(-1.0, 0.0), "look_target": Vector3(-5.0, 0.0, 0.0)}
	)
	assert_eq(
		thief.look_target_position, Vector3(-5.0, 0.0, 0.0), "Fuera del dial, vuelve a girarse"
	)


## #164, con red: el cliente gira su dial al mandar el paso y no deja que el estado viejo del
## servidor (de hace un viaje de ida y vuelta) lo haga retroceder
func test_client_predicts_the_dial_and_ignores_stale_server_state() -> void:
	var nodes: Array = _setup()
	var safe: SafeBox3D = nodes[0]
	safe.current_state = SafeBox3D.SafeState.CRACKING
	SafeBox3D.predict_local(get_tree(), 1)
	SafeBox3D.predict_local(get_tree(), 1)
	assert_eq(safe.current_dial_val, 2, "Se ve al instante")
	safe.apply_net_state({"cracking": true, "dial": 1})  # llega el estado de tras el primer paso
	assert_eq(safe.current_dial_val, 2, "No retrocede")
	safe._predict_until = 0  # pasado el margen
	safe.apply_net_state({"cracking": true, "dial": 2})
	assert_eq(safe.current_dial_val, 2, "Y luego manda el servidor")
