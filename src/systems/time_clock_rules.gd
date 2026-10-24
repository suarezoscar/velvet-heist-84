## @file time_clock_rules.gd
## Números de los relojes de ronda (interaction.md, parte R). Uno global por partida.
class_name TimeClockRules
extends Resource

## Ventana de ronda en segundos: cada reloj cuenta atrás desde aquí
@export var round_duration: float = 90.0

## Faltas que el equipo de guardias puede acumular sin romper la ronda
@export var allowed_misses: int = 2

## Segundos restantes a partir de los cuales la tablilla pasa a ámbar
@export var warning_time: float = 20.0

## Radio en metros del ruido de fichar
@export var punch_noise_radius: float = 5.5

## Radio en metros de la campana de un reloj vencido
@export var alarm_noise_radius: float = 14.0

## Segundos entre campanadas de un reloj vencido
@export var alarm_pulse_interval: float = 3.0
