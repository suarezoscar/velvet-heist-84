## @file test_partial_escape_score.gd
## Huida a medias (#120, heist.md R4b y R11): puntos nuevos, quién gana, veredicto y sellos.
extends GutTest

const S: Variant = GameManager.MatchState


## Informe del ejemplo de R4b: 2 guardias, encargo de 3, el ladrón roba `stolen` piezas
func _report(stolen: int) -> Dictionary:
	var pieces: Array[Dictionary] = []
	for i: int in range(3):
		pieces.append({"stolen": i < stolen})
	return {
		"thief": {"pieces": pieces, "partial": true, "alarms": 1, "seen": 1},
		"guards":
		[
			{"seen": 1, "protected": 3 - stolen},
			{"naps": 1, "protected": 3 - stolen},
		],
	}


func test_example_one_piece_guards_win() -> void:
	var result: Dictionary = MatchScore.partial_result(_report(1))
	assert_eq(result["thief"], 115)
	assert_eq(result["guards"], 125)
	assert_eq(result["winner"], &"guards")
	assert_eq(
		MatchSummary.partial_line(_report(1)), "Huida a medias: ganan los guardias, 125 a 115"
	)


func test_example_two_pieces_thief_wins() -> void:
	var result: Dictionary = MatchScore.partial_result(_report(2))
	assert_eq(result["thief"], 215)
	assert_eq(result["guards"], 65)
	assert_eq(result["winner"], &"thief")
	assert_eq(MatchSummary.partial_line(_report(2)), "Huida a medias: gana el ladrón, 215 a 65")


func test_tie() -> void:
	var report: Dictionary = {"thief": {"partial": true}, "guards": [{"hits": 1}]}  # 50 y 50
	assert_eq(MatchScore.partial_result(report)["winner"], &"")
	assert_eq(MatchSummary.partial_line(report), "Huida a medias: empate a 50")
	assert_eq(MatchSummary.winner(S.THIEF_ESCAPED_PARTIAL, report), &"")
	assert_eq(MatchSummary.verdict(S.THIEF_ESCAPED_PARTIAL, &"thief", report), "EMPATE")


func test_average_rounds_half_up() -> void:
	var report: Dictionary = {
		"thief": {},
		"guards": [{"protected": 1}, {"protected": 0}],  # 60 y 0: media 30
	}
	assert_eq(MatchScore.partial_result(report)["guards"], 30)
	report["guards"] = [{"hits": 1}, {"seen": 1}, {"seen": 1}]  # 50 + 25 + 25 = 100 / 3 = 33,3
	assert_eq(MatchScore.partial_result(report)["guards"], 33)
	report["guards"] = [{"seen": 1}, {"hits": 1}, {"hits": 1}, {"naps": 1}]
	assert_eq(MatchScore.partial_result(report)["guards"], 28)
	assert_eq(MatchScore.partial_result({"thief": {}})["guards"], 0, "Sin guardias, 0")


func test_new_score_lines() -> void:
	var thief: Dictionary = MatchScore.thief({"partial": true})
	assert_eq(int(thief["total"]), 50)
	var guard: Dictionary = MatchScore.guard({"protected": 2, "locked_in": true})
	assert_eq(int(guard["total"]), 2 * 60 + 100)
	assert_eq((guard["lines"] as Array).size(), 2)


func test_winner_and_verdict_of_new_states() -> void:
	assert_eq(MatchSummary.winner(S.THIEF_LOCKED_IN), &"guards")
	assert_eq(MatchSummary.winner(S.THIEF_NO_LOOT), &"guards")
	assert_eq(MatchSummary.winner(S.THIEF_ESCAPED_PARTIAL, _report(2)), &"thief")
	assert_eq(MatchSummary.winner(S.THIEF_ESCAPED_PARTIAL, _report(1)), &"guards")
	assert_eq(MatchSummary.verdict(S.THIEF_ESCAPED_PARTIAL, &"thief", _report(2)), "HAS GANADO")
	assert_eq(MatchSummary.verdict(S.THIEF_ESCAPED_PARTIAL, &"thief", _report(1)), "HAS PERDIDO")
	assert_eq(MatchSummary.verdict(S.THIEF_LOCKED_IN, &"guards"), "HAS GANADO")
	assert_eq(MatchSummary.verdict(S.THIEF_NO_LOOT, &""), "GANAN LOS GUARDIAS")


func test_stamps() -> void:
	assert_eq(MatchReport84.stamp_for(S.THIEF_ESCAPED_PARTIAL)[0], "HUIDA A MEDIAS")
	assert_eq(MatchReport84.stamp_for(S.THIEF_LOCKED_IN)[0], "ENCERRADO")
	assert_eq(MatchReport84.stamp_for(S.THIEF_NO_LOOT)[0], "SIN BOTÍN")
