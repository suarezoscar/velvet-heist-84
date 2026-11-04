## @file match_summary.gd
## Resumen de la partida para el panel de fin (FEAT-027): qué bando gana, si has ganado tú y
## las cifras (botín, Pieza Maestra y tiempo jugado) y quién jugaba en cada bando (FEAT-035).
## Lógica pura.
class_name MatchSummary
extends RefCounted


## Bando que gana: &"thief", &"guards" o &"" (empate o partida sin terminar)
## (la huida a medias se decide por puntos con el informe)
static func winner(state: GameManager.MatchState, report: Dictionary = {}) -> StringName:
	match state:
		GameManager.MatchState.THIEF_ESCAPED:
			return &"thief"
		GameManager.MatchState.THIEF_ESCAPED_PARTIAL:
			return StringName(MatchScore.partial_result(report)["winner"])
		GameManager.MatchState.THIEF_CAPTURED, GameManager.MatchState.TIME_EXPIRED:
			return &"guards"
		GameManager.MatchState.THIEF_LOCKED_IN, GameManager.MatchState.THIEF_NO_LOOT:
			return &"guards"
	return &""


## «HAS GANADO», «HAS PERDIDO» o «EMPATE» para el bando local (&"" si no juegas: servidor)
static func verdict(
	state: GameManager.MatchState, local_side: StringName, report: Dictionary = {}
) -> String:
	var side: StringName = winner(state, report)
	if side == &"":
		return "EMPATE"
	if local_side == &"":
		return "GANA EL LADRÓN" if side == &"thief" else "GANAN LOS GUARDIAS"
	return "HAS GANADO" if side == local_side else "HAS PERDIDO"


## «Huida a medias: gana el ladrón, 215 a 65» (el primer número es el del bando que gana)
static func partial_line(report: Dictionary) -> String:
	var result: Dictionary = MatchScore.partial_result(report)
	var thief: int = int(result["thief"])
	var guards: int = int(result["guards"])
	match result["winner"]:
		&"thief":
			return "Huida a medias: gana el ladrón, %d a %d" % [thief, guards]
		&"guards":
			return "Huida a medias: ganan los guardias, %d a %d" % [guards, thief]
	return "Huida a medias: empate a %d" % thief


## Cifras de la partida, una por línea
static func stats(loot: int, quota: int, masterpiece: bool, elapsed: float) -> String:
	var seconds: int = maxi(roundi(elapsed), 0)
	return (
		"\n"
		. join(
			PackedStringArray(
				[
					"Botín: %d de %d" % [loot, quota],
					"Pieza Maestra: %s" % ("robada" if masterpiece else "en su sitio"),
					"Tiempo: %d:%02d" % [seconds / 60, seconds % 60],
				]
			)
		)
	)


## «Ladrón: Diego · Guardias: Ana, Luis». En red, de la lista de jugadores; sin red, el ladrón es
## el jugador local (own_name, o «tú» si no tiene) y a los guardias los lleva el ordenador
static func players_line(players: Dictionary, own_name: String) -> String:
	if players.is_empty():
		var thief: String = own_name if not own_name.is_empty() else "tú"
		return "Ladrón: %s · Guardias: el ordenador" % thief
	var thief_name: String = "nadie"
	var guards: Array[String] = []
	for peer: int in players:
		var info: Dictionary = players[peer]
		if info.get("role", &"") == NetManagerNode.ROLE_THIEF:
			thief_name = String(info.get("name", ""))
		elif String(info.get("role", "")).begins_with("guard"):
			guards.append(String(info.get("name", "")))
	var guard_names: String = "nadie"
	if not guards.is_empty():
		guard_names = ", ".join(PackedStringArray(guards))
	return "Ladrón: %s · Guardias: %s" % [thief_name, guard_names]


## Cifras con encargo (heist.md): piezas robadas, cuáles eran y tiempo
static func heist_stats(heist: HeistDirector, elapsed: float) -> String:
	var seconds: int = maxi(roundi(elapsed), 0)
	var names: Array[String] = []
	for piece_id: StringName in heist.targets:
		var piece: TargetPiece3D = heist.piece(piece_id)
		if piece != null:
			names.append(("✔ " if heist.stolen.has(piece_id) else "✘ ") + piece.piece_name)
	return (
		"\n"
		. join(
			PackedStringArray(
				[
					"Encargo: %d de %d piezas" % [heist.stolen.size(), heist.contract_size],
					"  ".join(PackedStringArray(names)),
					"Tiempo: %d:%02d" % [seconds / 60, seconds % 60],
				]
			)
		)
	)


## Bando del jugador local en el mapa
static func local_side(map: HeistMap3D) -> StringName:
	if map == null or map.local_player == null:
		return &""
	return &"thief" if map.local_player == map.thief else &"guards"
