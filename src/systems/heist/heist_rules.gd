## @file heist_rules.gd
## Números del golpe (heist.md): piezas del encargo según los guardias y robo a lo bruto.
class_name HeistRules
extends Resource

## Piezas del encargo con 1, 2, 3… guardias (heist.md R1); más guardias, menos piezas
@export var pieces_by_guards: Array[int] = [4, 3, 2]

## Radio (m) del ruido de la campana al robar a lo bruto (R9)
@export var brute_radius: float = 15.0

## R6: distancia (m) a la que un guardia descubre un pedestal vacío que tiene a la vista
@export var trace_sight: float = 10.0
## R7: rastros descubiertos para pasar a «alarma» (1 basta para «sospecha»)
@export var alarm_traces: int = 2
## R7: luces de alarma: radio (m), duración (s) y espera del equipo entre usos (s)
@export var flood_radius: float = 14.0
@export var flood_time: float = 30.0
@export var flood_cooldown: float = 60.0

## R9: segundos del cambiazo, de examinar una pieza, de cortar y de restablecer la corriente
@export var swap_time: float = 2.0
@export var inspect_time: float = 2.0
@export var cut_time: float = 3.0
@export var restore_time: float = 3.0
## R9: distancia (m) que se puede alejar el actor sin cancelar una acción que tarda
@export var task_leash: float = 1.5
## R9: distancia (m) del panel de pilotos a la que un guardia se entera de un corte
@export var pilot_sight: float = 4.0

## R8: monedas del ladrón, alcance del lanzamiento (m) y radio del ruido al caer (m)
@export var coins: int = 3
@export var throw_range: float = 10.0
@export var coin_radius: float = 9.0

## R8: walkie: segundos que dura la marca, radio del chasquido (m) y espera entre usos (s)
@export var ping_time: float = 8.0
@export var walkie_radius: float = 6.0
@export var walkie_cooldown: float = 10.0

## R3: peso del botín: el ladrón pierde esta parte de su velocidad por cada pieza que lleva
@export var loot_slow: float = 0.05
## R3: velocidad mínima con todo el botín (parte de la normal)
@export var loot_min_speed: float = 0.7


## Piezas del encargo para guard_count guardias, sin pasar de las candidatas
func pieces_for(guard_count: int, candidates: int) -> int:
	if pieces_by_guards.is_empty():
		return mini(3, candidates)
	var index: int = clampi(guard_count - 1, 0, pieces_by_guards.size() - 1)
	return clampi(pieces_by_guards[index], 1, candidates)
