## @file test_match_report.gd
## Informe final (FEAT-041): cómo se robó cada pieza, la cuenta de la partida, los puntos con
## su desglose, el mejor de la noche y que nadie se mueva con la partida acabada.
extends GutTest

const MAP_SCENE: PackedScene = preload("res://scenes/maps/museum_v2.tscn")

var _saved_state: GameManager.MatchState


func before_each() -> void:
	_saved_state = GameManager.current_state


func after_each() -> void:
	GameManager.current_state = _saved_state


func _map() -> HeistMap3D:
	var map: HeistMap3D = MAP_SCENE.instantiate() as HeistMap3D
	add_child_autofree(map)
	return map


func test_how_each_piece_was_stolen() -> void:
	var none: TargetPieceLook.Flaw = TargetPieceLook.Flaw.NONE
	assert_eq(TargetPiece3D.steal_method(true, none, &"combination"), &"brute")
	assert_eq(TargetPiece3D.steal_method(false, none, &"combination"), &"dial")
	assert_eq(TargetPiece3D.steal_method(false, none, &"sensor"), &"power")
	var flawed: TargetPieceLook.Flaw = TargetPieceLook.Flaw.values()[1]
	assert_eq(TargetPiece3D.steal_method(false, flawed, &"pressure"), &"swap")


func test_points_with_breakdown() -> void:
	var rules: ScoreRules = ScoreRules.new()
	var thief: Dictionary = MatchScore.thief(
		{
			"pieces": [{"stolen": true}, {"stolen": true}, {"stolen": false}],
			"escaped": false,
			"alarms": 1,
			"seen": 2
		},
		rules
	)
	assert_eq(int(thief["total"]), 2 * 100 - 25 - 2 * 10)
	assert_eq((thief["lines"] as Array).size(), 3, "Solo lo que ha pasado (sin huida)")
	var guard: Dictionary = MatchScore.guard(
		{"clocks": 4, "faults": 1, "seen": 2, "hits": 2, "capture": true, "naps": 1}, rules
	)
	assert_eq(int(guard["total"]), 40 - 20 + 50 + 100 + 150 - 15)


func test_best_of_the_night() -> void:
	var report: Dictionary = {
		"thief": {"pieces": [{"stolen": true}], "escaped": false},
		"guards": [{"clocks": 2}, {"hits": 2, "capture": true}],
	}
	assert_eq(MatchScore.best(report), "1", "El guardia que lo atrapó")
	report["thief"] = {"pieces": [{"stolen": true}, {"stolen": true}], "escaped": true}
	report["guards"] = [{"clocks": 2}]
	assert_eq(MatchScore.best(report), "thief")
	assert_eq(MatchScore.best({}), "")


func test_recorder_counts_the_match() -> void:
	var map: HeistMap3D = _map()
	await wait_physics_frames(3)
	var heist: HeistDirector = GameManager.heist
	var piece: TargetPiece3D = heist.piece(heist.targets[0])
	piece.steal(true)
	var guard: GuardController3D = map.guards[0]
	var recorder: MatchRecorder = MatchRecorder.of(get_tree())
	var key: String = String(guard.name)
	recorder.track(key, true, false, 100.0)
	recorder.track(key, true, false, 100.5)  # lo sigue viendo: no cuenta otra vez
	recorder.track(key, false, true, 101.0)  # lo pierde y da una cabezada
	recorder.track(key, true, false, 101.5)  # vuelve a verlo enseguida: no cuenta
	recorder.track(key, true, true, 110.0)  # tras más de SEEN_GAP s, sí; y otra cabezada
	guard.is_ai_controlled = false
	map.thief.is_locally_controlled = false
	GameManager.end_match(GameManager.MatchState.THIEF_CAPTURED)
	await wait_physics_frames(2)
	var report: Dictionary = MatchRecorder.of(get_tree()).report
	assert_false(report.is_empty(), "Informe al acabar")
	var thief: Dictionary = report["thief"]
	assert_eq((thief["pieces"] as Array).size(), heist.contract_size)
	var first: Dictionary = thief["pieces"][0]
	assert_true(first["stolen"])
	assert_eq(first["how"], "a lo bruto")
	assert_gte(int(thief["alarms"]), 1, "Robar a lo bruto hace saltar la alarma")
	assert_eq(int(report["guards"][0]["seen"]), 2, "Dos veces, no cada fotograma")
	assert_eq(int(thief["seen"]), 2)
	assert_eq(int(report["guards"][0]["naps"]), 2, "Cada cabezada que empieza")
	assert_false(bool(thief["escaped"]))


func test_nobody_moves_once_the_match_is_over() -> void:
	var map: HeistMap3D = _map()
	await wait_physics_frames(3)
	var thief: ThiefController3D = map.thief
	thief.is_locally_controlled = false
	GameManager.end_match(GameManager.MatchState.TIME_EXPIRED)
	var start: Vector3 = thief.global_position
	for i: int in range(30):
		thief.apply_world_move(Vector3(1.0, 0.0, 0.0), true)
		await wait_physics_frames(1)
	var moved: Vector3 = thief.global_position - start
	assert_lt(Vector2(moved.x, moved.z).length(), 0.05, "Se queda quieto")
