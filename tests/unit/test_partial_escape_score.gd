## @file test_partial_escape_score.gd
## Huida a medias (#120; puntos de #123, heist.md R4b y R11): bolsas, puntuación individual,
## de equipo y en vivo, quién gana, veredicto y sellos (con los ejemplos de la tabla de escenarios).
extends GutTest

const S: Variant = GameManager.MatchState


## Informe de una huida a medias (heist.md, «Puntos (#123)»): encargo de k, el ladrón roba
## stolen piezas, con extra en su ficha y personales para cada guardia
func _report(k: int, stolen: int, thief_extra: Dictionary, guards: Array) -> Dictionary:
	var pieces: Array[Dictionary] = []
	for i: int in range(k):
		pieces.append({"stolen": i < stolen})
	var thief: Dictionary = {"pieces": pieces, "partial": true, "guards": guards.size()}
	thief.merge(thief_extra)
	var entries: Array = []
	for personal: Dictionary in guards:
		var entry: Dictionary = {"protected": k - stolen, "k": k, "guards": guards.size()}
		entry.merge(personal)
		entries.append(entry)
	return {"thief": thief, "guards": entries}


## Huida limpia: una alarma (la da un guardia viéndolo) y nada más
func _calm(k: int, stolen: int, guards: int) -> Dictionary:
	var personals: Array = [{"alarm": true}]
	for i: int in range(guards - 1):
		personals.append({})
	return _report(k, stolen, {"alarms": 1, "seen": 1}, personals)


func test_calm_escape_ties_at_half_the_contract() -> void:
	var one: Dictionary = MatchScore.partial_result(_calm(4, 2, 1))
	assert_eq([one["thief"], one["guards"]], [200, 200], "1 guardia, 2 de 4")
	var three: Dictionary = MatchScore.partial_result(_calm(2, 1, 3))
	assert_eq([three["thief"], three["guards"]], [179, 179], "3 guardias, 1 de 2")
	assert_eq(three["winner"], &"")
	assert_eq(MatchSummary.partial_line(_calm(2, 1, 3)), "Huida a medias: empate a 179")


func test_calm_escape_with_two_guards() -> void:
	var low: Dictionary = MatchScore.partial_result(_calm(3, 1, 2))
	assert_eq([low["thief"], low["guards"], low["winner"]], [135, 235, &"guards"])
	assert_eq(
		MatchSummary.partial_line(_calm(3, 1, 2)), "Huida a medias: ganan los guardias, 235 a 135"
	)
	var high: Dictionary = MatchScore.partial_result(_calm(3, 2, 2))
	assert_eq([high["thief"], high["guards"], high["winner"]], [235, 135, &"thief"])


func test_average_match_example() -> void:
	# Media, 2 guardias, 2 de 3: 235 a 227
	var thief: Dictionary = {"alarms": 2, "seen": 2, "hits_taken": 1, "lost": 1, "fast": 10}
	var guards: Array = [
		{"alarm": true, "seen": 1, "hits": 1, "naps": 1},
		{"repairs": 1, "walkie": 1},
	]
	var result: Dictionary = MatchScore.partial_result(_report(3, 2, thief, guards))
	assert_eq([result["thief"], result["guards"], result["winner"]], [235, 227, &"thief"])
	assert_eq([result["pieces"], result["play"]], [100, 127], "Equipo: piezas + juego")


func test_a_guard_leaves_and_it_still_ties() -> void:
	# 3 guardias y encargo de 2; se va uno: G = 2
	var result: Dictionary = MatchScore.partial_result(_calm(2, 1, 2))
	assert_eq([result["thief"], result["guards"]], [185, 185])


func test_no_guards_is_the_protect_pool() -> void:
	var report: Dictionary = _report(2, 1, {}, [])
	assert_eq(MatchScore.partial_result(report)["guards"], 150)


func test_individual_guard_takes_its_share_of_the_pools() -> void:
	var guard: Dictionary = MatchScore.guard(
		{"protected": 2, "k": 3, "guards": 2, "locked_in": true}
	)
	assert_eq(int(guard["total"]), 100 + 75, "300 × 2/3 / 2 y 150 / 2")
	assert_eq(MatchScore.personal({"protected": 2, "k": 3, "guards": 2, "seen": 1}), 25)


func test_partial_escape_depends_on_the_guards() -> void:
	var rules: ScoreRules = MatchScore.RULES
	assert_eq(
		[1, 2, 3, 4, 5].map(func(g: int) -> int: return rules.partial_escape_for(g)),
		[75, 60, 54, 50, 50]
	)


func test_live_score_hides_what_would_give_away_information() -> void:
	var thief: Dictionary = MatchScore.live(
		MatchScore.thief({"clean": 1, "sabotaged": 1, "seen": 1, "lost": 1})
	)
	assert_eq(thief["total"], -10 + 25, "Sin robo limpio ni rejas saboteadas")
	assert_false((thief["lines"] as Dictionary).has("Robo limpio"))
	var guard: Dictionary = MatchScore.live(
		MatchScore.guard({"protected": 1, "k": 2, "guards": 1, "near_theft": 1, "seen": 1})
	)
	assert_eq(guard["total"], 25, "Sin proteger ni robos cerca")


func test_live_score_notes_each_change() -> void:
	var live: LiveScore = autofree(LiveScore.create(&"guard_1"))
	live.update(MatchScore.live(MatchScore.guard({"seen": 1})))
	live.update(MatchScore.live(MatchScore.guard({"seen": 1, "naps": 1})))
	assert_eq(live.total, 10)
	assert_eq(live.notes, [[1, "+25 VISTO"], [2, "−15 CABEZADA"]])
	assert_eq(live.net_private_audience(), &"guard_1", "Solo a su jugador")


func test_winner_and_verdict_of_new_states() -> void:
	assert_eq(MatchSummary.winner(S.THIEF_LOCKED_IN), &"guards")
	assert_eq(MatchSummary.winner(S.THIEF_NO_LOOT), &"guards")
	assert_eq(MatchSummary.winner(S.THIEF_ESCAPED_PARTIAL, _calm(3, 2, 2)), &"thief")
	assert_eq(MatchSummary.winner(S.THIEF_ESCAPED_PARTIAL, _calm(3, 1, 2)), &"guards")
	assert_eq(MatchSummary.verdict(S.THIEF_ESCAPED_PARTIAL, &"thief", _calm(3, 2, 2)), "HAS GANADO")
	assert_eq(
		MatchSummary.verdict(S.THIEF_ESCAPED_PARTIAL, &"thief", _calm(3, 1, 2)), "HAS PERDIDO"
	)
	assert_eq(MatchSummary.verdict(S.THIEF_ESCAPED_PARTIAL, &"thief", _calm(2, 1, 3)), "EMPATE")
	assert_eq(MatchSummary.verdict(S.THIEF_LOCKED_IN, &"guards"), "HAS GANADO")
	assert_eq(MatchSummary.verdict(S.THIEF_NO_LOOT, &""), "GANAN LOS GUARDIAS")


func test_stamps() -> void:
	assert_eq(MatchReport84.stamp_for(S.THIEF_ESCAPED_PARTIAL)[0], "HUIDA A MEDIAS")
	assert_eq(MatchReport84.stamp_for(S.THIEF_LOCKED_IN)[0], "ENCERRADO")
	assert_eq(MatchReport84.stamp_for(S.THIEF_NO_LOOT)[0], "SIN BOTÍN")
