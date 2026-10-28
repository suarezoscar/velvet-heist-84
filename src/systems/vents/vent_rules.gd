## @file vent_rules.gd
## Números de la ventilación (FEAT-034, heist.md R10).
class_name VentRules
extends Resource

## Segundos para colarse por una rejilla y para salir por otra
@export var enter_time: float = 1.5
## Radio (m) del ruido metálico al entrar y al salir
@export var hatch_radius: float = 4.0
## Velocidad (m/s) por el conducto, en línea recta entre rejillas
@export var travel_speed: float = 2.0
## Segundos que una rejilla usada se queda abierta (un rastro que los guardias pueden cerrar)
@export var open_time: float = 20.0
## Radio (m) del retumbar que suena en las rejillas de la red mientras el ladrón la recorre
@export var rumble_radius: float = 5.0
