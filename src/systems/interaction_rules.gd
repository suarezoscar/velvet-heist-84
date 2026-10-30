## @file interaction_rules.gd
## Alcance y abanico comunes para elegir un objeto interactivo (#113).
class_name InteractionRules
extends Resource

## Distancia horizontal máxima al punto interactivo, en metros
@export var reach_distance: float = 2.0

## Ángulo total del abanico situado delante del personaje, en grados
@export var fan_angle_degrees: float = 120.0
