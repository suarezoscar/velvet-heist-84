## @file test_guard_sprint.gd
## heist.md R5d (#116): el guardia solo corre con la alarma sonando; en calma anda.
extends GutTest

const MAP_SCENE: PackedScene = preload("res://scenes/maps/museum_v2.tscn")

var _saved_state: GameManager.MatchState


## El mapa arranca la partida: se devuelve el estado para no afectar a otros tests
func before_each() -> void:
	_saved_state = GameManager.current_state


func after_each() -> void:
	GameManager.current_state = _saved_state


func _sprint_guard() -> GuardController3D:
	var map: HeistMap3D = MAP_SCENE.instantiate() as HeistMap3D
	add_child_autofree(map)
	var guard: GuardController3D = map.guards[0]
	guard.is_ai_controlled = false
	guard.set_physics_process(false)
	guard.is_sprinting = true
	guard.current_input_dir = Vector2(0.0, -1.0)
	return guard


func test_guard_does_not_sprint_without_alarm() -> void:
	var guard: GuardController3D = _sprint_guard()
	await wait_physics_frames(1)
	guard.simulate_movement(0.016)
	assert_false(guard.is_sprinting, "En calma no corre")


func test_guard_sprints_with_alarm() -> void:
	var guard: GuardController3D = _sprint_guard()
	await wait_physics_frames(1)
	AlertDirector.of(get_tree()).level = AlertDirector.Level.ALARM
	guard.simulate_movement(0.016)
	assert_true(guard.is_sprinting, "Con la alarma sí corre")
