## @file round_rules.gd
## Reglas puras de la hoja de ronda (interaction.md R2-R4): faltas del equipo y si la
## ronda está al día al acabar el tiempo.
class_name RoundRules
extends RefCounted


## Faltas del equipo: suma de las de cada reloj
static func team_faults(clocks: Array) -> int:
	var total: int = 0
	for clock: Node in clocks:
		if clock is TimeClock3D:
			total += (clock as TimeClock3D).faults
	return total


## true si algún reloj está vencido o llega a 0 en este tick (borde = vencido); margin es el
## delta del tick, porque GameManager evalúa antes de que los relojes simulen ese tick
static func any_expired(clocks: Array, margin: float = 0.0) -> bool:
	for clock: Node in clocks:
		if clock is TimeClock3D:
			var time_clock: TimeClock3D = clock as TimeClock3D
			if time_clock.is_expired or time_clock.time_left <= margin:
				return true
	return false


## R3: al día si las faltas no pasan de las toleradas y ningún reloj sigue vencido
static func is_on_time(faults: int, expired_now: bool, allowed: int) -> bool:
	return faults <= allowed and not expired_now
