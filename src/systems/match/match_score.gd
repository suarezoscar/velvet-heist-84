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
			_line("Alarmas", int(report.get("alarms", 0)), rules.thief_alarm),
			_line("Visto por un guardia", int(report.get("seen", 0)), rules.thief_seen),
		]
	)


## Desglose y total de un guardia
static func guard(report: Dictionary, rules: ScoreRules = RULES) -> Dictionary:
	return _sum(
		[
			_line("Relojes fichados", int(report.get("clocks", 0)), rules.guard_clock),
			_line("Faltas de ronda", int(report.get("faults", 0)), rules.guard_fault),
			_line("Veces que vio al ladrón", int(report.get("seen", 0)), rules.guard_seen),
			_line("Golpes de porra", int(report.get("hits", 0)), rules.guard_hit),
			_line("Captura", 1 if bool(report.get("capture", false)) else 0, rules.guard_capture),
			_line("Cabezadas", int(report.get("naps", 0)), rules.guard_nap),
		]
	)


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
