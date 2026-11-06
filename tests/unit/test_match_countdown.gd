## @file test_match_countdown.gd
## Arranque de la partida (#165): sin red, el 3-2-1 empieza al cerrar la tarjeta del rol y
## mientras dura nadie se mueve ni corre el reloj; después, «¡YA!» y a jugar.
extends GutTest

const MAP_SCENE: PackedScene = preload("res://scenes/maps/museum_v2.tscn")

var _saved_state: GameManager.MatchState
var _saved_timer: float


func before_each() -> void:
	_saved_state = GameManager.current_state
	_saved_timer = GameManager.match_timer


func after_each() -> void:
	GameManager.current_state = _saved_state
	GameManager.match_timer = _saved_timer


func test_offline_countdown_freezes_then_starts() -> void:
	var map: HeistMap3D = MAP_SCENE.instantiate() as HeistMap3D
	add_child_autofree(map)
	for guard: GuardController3D in map.guards:
		guard.set_physics_process(false)
	await wait_physics_frames(2)
	var countdown: MatchCountdown = MatchCountdown.of(get_tree())
	assert_eq(countdown.phase, MatchCountdown.Phase.WAITING)
	assert_false(MatchCountdown.frozen(get_tree()), "Sin red, tras la tarjeta como siempre")
	for node: Node in map.find_children("*", "RoleBriefing84", true, false):
		node.call("close")
	assert_eq(countdown.phase, MatchCountdown.Phase.COUNTING, "Al cerrar la tarjeta, 3-2-1")
	assert_true(MatchCountdown.frozen(get_tree()))
	var timer: float = GameManager.match_timer
	var start: Vector3 = map.thief.global_position
	for i: int in range(20):
		map.thief.apply_world_move(Vector3(1.0, 0.0, 0.0))
		await wait_physics_frames(1)
	assert_almost_eq(GameManager.match_timer, timer, 0.001, "El reloj no corre")
	var moved: Vector3 = map.thief.global_position - start
	assert_lt(Vector2(moved.x, moved.z).length(), 0.05, "Nadie se mueve")
	var hud: MatchCountdown84 = map.hud.countdown_hud
	hud.refresh()
	assert_true(hud.visible)
	assert_eq(hud.number_label.text, str(ceili(countdown.left)))
	countdown.left = 0.05
	await wait_physics_frames(3)
	assert_eq(countdown.phase, MatchCountdown.Phase.GO)
	assert_false(MatchCountdown.frozen(get_tree()))
	hud.refresh()
	assert_eq(hud.number_label.text, "¡YA!")
