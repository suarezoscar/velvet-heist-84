## @file cctv_rules.gd
## Números de los monitores CCTV de la garita (interaction.md, parte M).
class_name CCTVRules
extends Resource

## Segundos que tarda un guardia en sentarse y empezar a mirar los monitores
@export var monitor_enter_time: float = 0.4

## Alto de cada imagen de cámara en el HUD, como fracción del alto de la pantalla
@export var feed_height_frac: float = 0.40
