## @file safe_dial_rules.gd
## Números del dial de la caja fuerte: cuánto tarda en repetir y acelerar al mantener la tecla.
class_name SafeDialRules
extends Resource

## Segundos con la tecla pulsada antes de que el dial empiece a girar seguido
@export var repeat_delay: float = 0.3

## Segundos entre pasos al empezar a girar seguido
@export var repeat_interval_start: float = 0.12

## Segundos entre pasos a máxima velocidad
@export var repeat_interval_min: float = 0.035

## Segundos de giro seguido hasta llegar a la velocidad máxima
@export var acceleration_time: float = 1.2
