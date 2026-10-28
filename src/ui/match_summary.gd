## @file match_summary.gd
## Resumen de la partida para el panel de fin (FEAT-027): qué bando gana, si has ganado tú y
## las cifras (botín, Pieza Maestra, tiempo jugado y faltas de ronda). Lógica pura.
class_name MatchSummary
extends RefCounted


## Bando que gana: &"thief", &"guards" o &"" (empate o partida sin terminar)
static func winner(state: GameManager.MatchState) -> StringName:
	match state:
		GameManager.MatchState.THIEF_ESCAPED, GameManager.MatchState.TIME_EXPIRED_BREACH:
			return &"thief"
		GameManager.MatchState.THIEF_CAPTURED, GameManager.MatchState.TIME_EXPIRED:
			return &"guards"
	return &""


## «HAS GANADO», «HAS PERDIDO» o «EMPATE» para el bando local (&"" si no juegas: servidor)
static func verdict(state: GameManager.MatchState, local_side: StringName) -> String:
	var side: StringName = winner(state)
	if side == &"":
		return "EMPATE"
	if local_side == &"":
		return "GANA EL LADRÓN" if side == &"thief" else "GANAN LOS GUARDIAS"
	return "HAS GANADO" if side == local_side else "HAS PERDIDO"


## Cifras de la partida, una por línea
static func stats(
	loot: int, quota: int, masterpiece: bool, elapsed: float, faults: int, allowed: int
) -> String:
	var seconds: int = maxi(roundi(elapsed), 0)
	return (
		"\n"
		. join(
			PackedStringArray(
				[
					"Botín: $%d de $%d" % [loot, quota],
					"Pieza Maestra: %s" % ("robada" if masterpiece else "en su sitio"),
					"Tiempo: %d:%02d" % [seconds / 60, seconds % 60],
					"Faltas de ronda: %d de %d toleradas" % [faults, allowed],
				]
			)
		)
	)


## Bando del jugador local en el mapa
static func local_side(map: HeistMap3D) -> StringName:
	if map == null or map.local_player == null:
		return &""
	return &"thief" if map.local_player == map.thief else &"guards"
