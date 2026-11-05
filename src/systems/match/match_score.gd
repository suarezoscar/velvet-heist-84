## @file match_score.gd
## Puntos de cada jugador a partir del informe de MatchRecorder (FEAT-041), con su desglose:
## [{"label": String, "count": int, "points": int}] y el total. Lógica pura: cada cliente la
## calcula con el mismo informe y las mismas reglas.
class_name MatchScore
extends RefCounted

const RULES: ScoreRules = preload("res://data/balance/score_rules.tres")


## Desglose y total del ladrón: {"lines": [...], "total": int}
static func thief(report: Dictionary, rules: ScoreRules = RULES) -> Dictionary:
	var stolen: int = 0
	for piece: Dictionary in report.get("pieces", []):
		if bool(piece.get("stolen", false)):
			stolen += 1
	return _sum(
		[
			_line("Piezas robadas", stolen, rules.thief_piece),
			_line("Huida", 1 if bool(report.get("escaped", false)) else 0, rules.thief_escape),
			_line(
				"Huida a medias",
				1 if bool(report.get("partial", false)) else 0,
				rules.thief_partial_escape
			),
			_line(
				"Cajas de reja saboteadas", int(report.get("sabotaged", 0)), rules.thief_sabotage
			),
			_line(
				"Huida por una reja saboteada",
				1 if bool(report.get("sabotage_escape", false)) else 0,
				rules.thief_sabotage_escape
			),
			_line("Alarmas", int(report.get("alarms", 0)), rules.thief_alarm),
			_line("Visto por un guardia", int(report.get("seen", 0)), rules.thief_seen),
		]
	)


## Desglose y total de un guardia
static func guard(report: Dictionary, rules: ScoreRules = RULES) -> Dictionary:
	return _sum(
		[
			_line("Veces que vio al ladrón", int(report.get("seen", 0)), rules.guard_seen),
			_line("Golpes de porra", int(report.get("hits", 0)), rules.guard_hit),
			_line("Captura", 1 if bool(report.get("capture", false)) else 0, rules.guard_capture),
			_line("Cabezadas", int(report.get("naps", 0)), rules.guard_nap),
			_line("Piezas protegidas", int(report.get("protected", 0)), rules.guard_protect),
			_line("Cajas reparadas", int(report.get("repairs", 0)), rules.guard_repair),
			_line(
				"Encerrado", 1 if bool(report.get("locked_in", false)) else 0, rules.guard_lockdown
			),
		]
	)


## Quién gana la huida a medias (heist.md R4b): el total del ladrón contra la media (redondeada)
## de los totales de los guardias. {"winner": &"thief" | &"guards" | &"", "thief", "guards"}
static func partial_result(report: Dictionary, rules: ScoreRules = RULES) -> Dictionary:
	var thief_total: int = int(thief(report.get("thief", {}), rules)["total"])
	var guards: Array = report.get("guards", [])
	var guards_total: int = 0
	if not guards.is_empty():
		var sum: int = 0
		for entry: Dictionary in guards:
			sum += int(guard(entry, rules)["total"])
		guards_total = floori(float(sum) / guards.size() + 0.5)  # los ,5 hacia arriba (R4b)
	var winner: StringName = &""
	if thief_total > guards_total:
		winner = &"thief"
	elif thief_total < guards_total:
		winner = &"guards"
	return {"winner": winner, "thief": thief_total, "guards": guards_total}


## Quién tiene más puntos: &"thief", el índice del guardia (como String) o &"" sin informe.
## Si empatan, gana el ladrón (o el guardia de número más bajo)
static func best(report: Dictionary, rules: ScoreRules = RULES) -> String:
	if report.is_empty():
		return ""
	var best_key: String = "thief"
	var best_total: int = int(thief(report.get("thief", {}), rules)["total"])
	var guards: Array = report.get("guards", [])
	for index: int in range(guards.size()):
		var total: int = int(guard(guards[index], rules)["total"])
		if total > best_total:
			best_total = total
			best_key = str(index)
	return best_key


static func _line(label: String, count: int, each: int) -> Dictionary:
	return {"label": label, "count": count, "points": count * each}


static func _sum(lines: Array) -> Dictionary:
	var total: int = 0
	var shown: Array[Dictionary] = []
	for line: Dictionary in lines:
		total += int(line["points"])
		if int(line["count"]) != 0:
			shown.append(line)
	return {"lines": shown, "total": total}
