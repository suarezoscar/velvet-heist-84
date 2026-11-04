## @file guard_patrol_rules.gd
## Números de la patrulla libre de la IA de guardia (heist.md R5c, #116).
class_name GuardPatrolRules
extends Resource

## Peso de una sala al elegir la siguiente: 1 + piezas × esto (más piezas, más visitas)
@export var ai_piece_weight: float = 1.5
## Salas recientes que no repite
@export var ai_room_memory: int = 3
## Segundos que se queda en cada sala, una pasada de linterna
@export var ai_room_dwell: float = 4.0
