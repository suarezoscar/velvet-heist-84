## @file test_steal_minigames_2.gd
## Revisión de #119: lo que cierra el minijuego de robo (golpe de porra, Q sobre otra pieza),
## soltar E en el mismo instante en que se abre y la tecla que ya se mantenía al abrirlo.
extends GutTest

const MAP_SCENE: PackedScene = preload("res://scenes/maps/museum_v2.tscn")

var _saved_state: GameManager.MatchState


func before_each() -> void:
	_saved_state = GameManager.current_state
	GameManager.current_state = GameManager.MatchState.IN_PROGRESS


func after_each() -> void:
	GameManager.current_state = _saved_state


## Mapa con la primera pieza de presión sin candado en el encargo y el ladrón a su lado
func _setup() -> Array:
	var map: HeistMap3D = MAP_SCENE.instantiate() as HeistMap3D
	add_child_autofree(map)
	for guard: GuardController3D in map.guards:
		guard.set_physics_process(false)
	await wait_physics_frames(2)
	var found: TargetPiece3D = null
	for node: Node in get_tree().get_nodes_in_group(&"heist_targets"):
		var piece: TargetPiece3D = node as TargetPiece3D
		if piece.protection == &"pressure" and piece.lock == null:
			found = piece
			break
	GameManager.heist.targets.assign([found.piece_id])
	map.thief.global_position = found.global_position + Vector3(1.0, 0.05, 0.0)
	return [map, found]


func test_baton_hit_cancels_the_minigame() -> void:
	var setup: Array = await _setup()
	var thief: ThiefController3D = (setup[0] as HeistMap3D).thief
	var piece: TargetPiece3D = setup[1]
	piece.interact(thief)
	assert_true(piece.is_playing())
	thief.register_baton_hit()
	assert_null(piece.game, "Un golpe de porra lo cancela")
	assert_false(piece.stolen)


func test_release_in_the_same_frame_pauses_the_scale() -> void:
	var setup: Array = await _setup()
	var thief: ThiefController3D = (setup[0] as HeistMap3D).thief
	var piece: TargetPiece3D = setup[1]
	piece.interact(thief)
	assert_true(thief.perform_action(&"interact_release"), "Soltar E va a su pieza")
	assert_false(piece.game.holding, "Un toque de E deja la balanza en pausa")


func test_force_elsewhere_closes_the_minigame() -> void:
	var setup: Array = await _setup()
	var thief: ThiefController3D = (setup[0] as HeistMap3D).thief
	var piece: TargetPiece3D = setup[1]
	piece.interact(thief)
	thief.perform_action(&"force")
	assert_null(piece.game, "Q suelta el minijuego aunque robe otra pieza")


func test_key_held_when_opening_does_not_cancel() -> void:
	var actor: Node3D = Node3D.new()
	add_child_autofree(actor)
	var game: StealMinigame = StealMinigame.start(StealMinigame.Kind.BRIDGE, actor)
	game.steer(Vector2(0, -1))
	assert_eq(game.tick(0.05), StealMinigame.Result.RUNNING, "La tecla de antes no cancela")
	game.steer(Vector2.ZERO)
	game.steer(Vector2(0, -1))
	assert_eq(game.tick(0.05), StealMinigame.Result.CANCELLED, "Una pulsación nueva sí")


func test_cancel_for_without_minigame_does_nothing() -> void:
	var setup: Array = await _setup()
	var thief: ThiefController3D = (setup[0] as HeistMap3D).thief
	StealMinigame.cancel_for(thief)
	assert_false((setup[1] as TargetPiece3D).is_playing())
