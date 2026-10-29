## @file time_clock_rules.gd
## Números de los relojes de ronda (interaction.md, parte R). Uno global por partida.
class_name TimeClockRules
extends Resource

## Tramo de ronda (s) cuando no se puede medir el camino (FEAT-034: cada tramo se mide)
@export var round_duration: float = 90.0

## Faltas que tolera el equipo por cada guardia (FEAT-034: 2 guardias, 4 faltas)
@export var allowed_misses: int = 2

## FEAT-034: relojes de la ruta de cada guardia
@export var route_length: int = 4
## FEAT-034: un tramo dura el tiempo andando por el camino, por este factor, más el margen (s)
@export var leg_walk_factor: float = 1.8
@export var leg_margin: float = 15.0

## Segundos restantes del tramo a partir de los cuales la tablilla pasa a ámbar
@export var warning_time: float = 20.0

## Radio en metros del ruido de fichar
@export var punch_noise_radius: float = 5.5

## Radio en metros de la campana del reloj al que un guardia llega tarde
@export var alarm_noise_radius: float = 14.0

## Segundos entre campanadas de un reloj vencido
@export var alarm_pulse_interval: float = 3.0
