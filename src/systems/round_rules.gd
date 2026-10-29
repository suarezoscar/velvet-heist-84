## @file round_rules.gd
## Reglas puras de la hoja de ronda (interaction.md R2-R4; FEAT-034: una ronda por guardia):
## faltas del equipo, cuántas tolera y si la ronda está al día al acabar el tiempo.
class_name RoundRules
extends RefCounted


## Faltas del equipo: suma de las de cada ronda (GuardRound)
static func team_faults(rounds: Array) -> int:
	var total: int = 0
	for node: Node in rounds:
		if node is GuardRound:
			total += (node as GuardRound).faults
	return total


## Faltas que tolera el equipo: allowed_per_guard por cada guardia con ronda
static func allowed_faults(rounds: Array, allowed_per_guard: int) -> int:
	var guards: int = 0
	for node: Node in rounds:
		if node is GuardRound and not (node as GuardRound).route.is_empty():
			guards += 1
	return allowed_per_guard * maxi(1, guards)


## true si algún guardia llega tarde o se le acaba el tramo en este tick (borde = tarde); margin
## es el delta del tick, porque GameManager evalúa antes de que las rondas simulen ese tick
static func any_expired(rounds: Array, margin: float = 0.0) -> bool:
	for node: Node in rounds:
		var round_node: GuardRound = node as GuardRound
		if round_node != null and not round_node.route.is_empty() and not round_node.suspended:
			if round_node.late or round_node.time_left <= margin:  # con alarma no hay ronda
				return true
	return false


## R3: al día si las faltas no pasan de las toleradas y nadie sigue llegando tarde
static func is_on_time(faults: int, expired_now: bool, allowed: int) -> bool:
	return faults <= allowed and not expired_now
