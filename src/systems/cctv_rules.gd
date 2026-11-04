## @file cctv_rules.gd
## Números de los monitores CCTV de la garita (interaction.md, parte M).
class_name CCTVRules
extends Resource

## Segundos que tarda un guardia en sentarse y empezar a mirar los monitores
@export var monitor_enter_time: float = 0.4

## Alto de cada imagen de cámara en el HUD, como fracción del alto de la pantalla
@export var feed_height_frac: float = 0.40

## Segundos de nieve al pasar de cámara en la mesa (#118): la nueva no detecta hasta acabar
@export var switch_time: float = 0.25
