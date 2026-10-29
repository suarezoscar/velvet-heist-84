## @file door_rules.gd
## Números de las puertas con hoja (FEAT-034): la de la garita.
class_name DoorRules
extends Resource

## Segundos que tarda el ladrón en forzar la cerradura (los guardias abren al momento)
@export var pick_time: float = 2.0
## Radio (m) del crujido al abrirse
@export var creak_radius: float = 6.0
## Segundos abierta antes de cerrarse sola (espera si hay alguien en el hueco)
@export var auto_close: float = 6.0
## Distancia (m) a la que un guardia de la IA la abre al acercarse
@export var ai_open_distance: float = 1.4
