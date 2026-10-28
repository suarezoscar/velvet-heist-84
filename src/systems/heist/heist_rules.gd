## @file heist_rules.gd
## Números del golpe (heist.md): piezas del encargo según los guardias y robo a lo bruto.
class_name HeistRules
extends Resource

## Piezas del encargo con 1, 2, 3… guardias (heist.md R1); más guardias, menos piezas
@export var pieces_by_guards: Array[int] = [4, 3, 2]

## Radio (m) del ruido de la campana al robar a lo bruto (R9)
@export var brute_radius: float = 15.0


## Piezas del encargo para guard_count guardias, sin pasar de las candidatas
func pieces_for(guard_count: int, candidates: int) -> int:
	if pieces_by_guards.is_empty():
		return mini(3, candidates)
	var index: int = clampi(guard_count - 1, 0, pieces_by_guards.size() - 1)
	return clampi(pieces_by_guards[index], 1, candidates)
