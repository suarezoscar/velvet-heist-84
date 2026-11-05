## @file match_score.gd
## Puntos de cada jugador a partir del informe de MatchRecorder (FEAT-041; #123, heist.md R4b y
## R11), con su desglose: [{"label", "count", "points", "note", "hidden", "team"}] y el total.
## - Individual: la ficha completa de cada jugador (cada guardia con su parte de las bolsas de
##   equipo). Da «MEJOR DE LA NOCHE» y es la que sumarían las rondas.
## - De equipo (solo la huida a medias): bolsas de equipo una vez + Σ personales / √G.
## - En vivo: el total sin las líneas ocultas (hidden), que darían información al jugador.
## Lógica pura: cada cliente la calcula con el mismo informe y las mismas reglas.
class_name MatchScore
extends RefCounted

const RULES: ScoreRules = preload("res://data/balance/score_rules.tres")


## Desglose y total del ladrón: {"lines": [...], "total": int}
static func thief(report: Dictionary, rules: ScoreRules = RULES) -> Dictionary:
	var pieces: Array = report.get("pieces", [])
	var stolen: int = _stolen(pieces)
	var guards: int = int(report.get("guards", 1))
	var partial: int = 1 if bool(report.get("partial", false)) else 0
	return _sum(
		[
			_total(
				"Piezas robadas",
				stolen,
				_pool(rules.thief_piece_pool, stolen, pieces.size()),
				"PIEZA"
			),
			_hide(_line("Robo limpio", int(report.get("clean", 0)), rules.thief_clean_piece, "")),
			_line("Huida", 1 if bool(report.get("escaped", false)) else 0, rules.thief_escape, ""),
			_line("Huida a medias", partial, rules.partial_escape_for(guards), ""),
			_line("Huida rápida (s)", int(report.get("fast", 0)), rules.thief_fast_escape, ""),
			_hide(
				_line("Rejas saboteadas", int(report.get("sabotaged", 0)), rules.thief_sabotage, "")
			),
			_line(
				"Huida por una reja saboteada",
				1 if bool(report.get("sabotage_escape", false)) else 0,
				rules.thief_sabotage_escape,
				""
			),
			_line("Despistes", int(report.get("lost", 0)), rules.thief_lose_them, "DESPISTADOS"),
			_line("Alarmas", int(report.get("alarms", 0)), rules.thief_alarm, "ALARMA"),
			_line("Visto por un guardia", int(report.get("seen", 0)), rules.thief_seen, "VISTO"),
			_line(
				"Golpes recibidos", int(report.get("hits_taken", 0)), rules.thief_hit_taken, "GOLPE"
			),
		]
	)


## Desglose y total (individual) de un guardia: sus personales y su parte de las bolsas
static func guard(report: Dictionary, rules: ScoreRules = RULES) -> Dictionary:
	var guards: int = maxi(1, int(report.get("guards", 1)))
	var protect: float = _pool_raw(
		rules.team_protect_pool, int(report.get("protected", 0)), int(report.get("k", 0))
	)
	var locked: bool = bool(report.get("locked_in", false))
	var lines: Array = _personal_lines(report, rules)
	lines.append(
		_team(
			_hide(
				_total(
					"Piezas protegidas",
					int(report.get("protected", 0)),
					_round(protect / guards),
					""
				)
			)
		)
	)
	lines.append(
		_team(
			_total(
				"Encerrado",
				1 if locked else 0,
				_round(float(rules.team_lockdown_pool) / guards) if locked else 0,
				""
			)
		)
	)
	return _sum(lines)


## Lo que hizo el guardia (sin las bolsas de equipo)
static func personal(report: Dictionary, rules: ScoreRules = RULES) -> int:
	return int(_sum(_personal_lines(report, rules))["total"])


## Puntuación de equipo (R4b): {"total", "pieces", "play"}. pieces: la bolsa de «proteger» (y la
## de «encerrado»); play: Σ personales / √G. Un solo redondeo, al final (los ,5 hacia arriba)
static func team(report: Dictionary, rules: ScoreRules = RULES) -> Dictionary:
	var pieces: Array = report.get("thief", {}).get("pieces", [])
	var guards: Array = report.get("guards", [])
	var k: int = pieces.size()
	var pools: float = _pool_raw(rules.team_protect_pool, k - _stolen(pieces), k)
	if not guards.is_empty() and bool(guards[0].get("locked_in", false)):
		pools += rules.team_lockdown_pool
	var play: float = 0.0
	if not guards.is_empty():
		var sum: int = 0
		for entry: Dictionary in guards:
			sum += personal(entry, rules)
		play = sum / sqrt(guards.size())
	return {"total": _round(pools + play), "pieces": _round(pools), "play": _round(play)}


## Quién gana la huida a medias (heist.md R4b): el total del ladrón contra la puntuación de
## equipo. {"winner": &"thief" | &"guards" | &"", "thief", "guards", "pieces", "play"}
static func partial_result(report: Dictionary, rules: ScoreRules = RULES) -> Dictionary:
	var thief_total: int = int(thief(report.get("thief", {}), rules)["total"])
	var team_score: Dictionary = team(report, rules)
	var guards_total: int = int(team_score["total"])
	var winner: StringName = &""
	if thief_total > guards_total:
		winner = &"thief"
	elif thief_total < guards_total:
		winner = &"guards"
	return {
		"winner": winner,
		"thief": thief_total,
		"guards": guards_total,
		"pieces": team_score["pieces"],
		"play": team_score["play"],
	}


## Quién tiene más puntos (individuales): &"thief", el índice del guardia (como String) o &""
## sin informe. Si empatan, gana el ladrón (o el guardia de número más bajo)
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


## Lo que ve el jugador en vivo: {"total": int, "lines": {label: [points, note]}} sin las líneas
## ocultas (robo limpio, rejas saboteadas, proteger y robos cerca)
static func live(score: Dictionary) -> Dictionary:
	var total: int = 0
	var lines: Dictionary = {}
	for line: Dictionary in score.get("lines", []):
		if bool(line.get("hidden", false)):
			continue
		total += int(line["points"])
		lines[line["label"]] = [int(line["points"]), String(line.get("note", ""))]
	return {"total": total, "lines": lines}


static func _personal_lines(report: Dictionary, rules: ScoreRules) -> Array:
	return [
		_line("Alarma", 1 if bool(report.get("alarm", false)) else 0, rules.guard_alarm, "ALARMA"),
		_line("Veces que vio al ladrón", int(report.get("seen", 0)), rules.guard_seen, "VISTO"),
		_line(
			"Falsificaciones descubiertas",
			int(report.get("examined", 0)),
			rules.guard_examine_fake,
			"FALSIFICACIÓN"
		),
		_line("Walkie que acertó", int(report.get("walkie", 0)), rules.guard_walkie, "WALKIE"),
		_hide(
			_line("Robos cerca de él", int(report.get("near_theft", 0)), rules.guard_near_theft, "")
		),
		_line("Golpes de porra", int(report.get("hits", 0)), rules.guard_hit, "GOLPE"),
		_line(
			"Captura",
			1 if bool(report.get("capture", false)) else 0,
			rules.guard_capture,
			"CAPTURA"
		),
		_line("Cabezadas", int(report.get("naps", 0)), rules.guard_nap, "CABEZADA"),
		_line("Cajas reparadas", int(report.get("repairs", 0)), rules.guard_repair, "REPARADA"),
	]


static func _stolen(pieces: Array) -> int:
	var stolen: int = 0
	for piece: Dictionary in pieces:
		if bool(piece.get("stolen", false)):
			stolen += 1
	return stolen


## bolsa × part / whole, redondeada (0 sin encargo)
static func _pool(pool: int, part: int, whole: int) -> int:
	return _round(_pool_raw(pool, part, whole))


static func _pool_raw(pool: int, part: int, whole: int) -> float:
	return float(pool) * part / whole if whole > 0 else 0.0


## Al entero más cercano, los ,5 hacia arriba (R4b)
static func _round(value: float) -> int:
	return floori(value + 0.5)


static func _line(label: String, count: int, each: int, note: String) -> Dictionary:
	return _total(label, count, count * each, note)


static func _total(label: String, count: int, points: int, note: String) -> Dictionary:
	return {"label": label, "count": count, "points": points, "note": note}


static func _hide(line: Dictionary) -> Dictionary:
	line["hidden"] = true
	return line


static func _team(line: Dictionary) -> Dictionary:
	line["team"] = true
	return line


static func _sum(lines: Array) -> Dictionary:
	var total: int = 0
	var shown: Array[Dictionary] = []
	for line: Dictionary in lines:
		total += int(line["points"])
		if int(line["count"]) != 0:
			shown.append(line)
	return {"lines": shown, "total": total}
