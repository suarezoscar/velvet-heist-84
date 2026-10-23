## @file hud_palette.gd
## Paleta de colores para el HUD con estética analógica de 1984.
## Define colores de fósforo para ruido propio, guardias, terceros y los niveles del vúmetro.
class_name HudPalette
extends Resource

## Color de ruido propio (#F2B84B - ámbar de fósforo)
@export var color_own: Color = Color("f2b84b")

## Color de ruido de guardia visto por el ladrón (#4FC3F7 - cian)
@export var color_guard: Color = Color("4fc3f7")

## Color de ruido ajeno visto por un guardia (#B8E6C1 - verde fósforo pálido)
@export var color_other: Color = Color("b8e6c1")

## Color de segmentos bajos del vúmetro (1-7: #B8E6C1)
@export var color_meter_low: Color = Color("b8e6c1")

## Color de segmentos medios del vúmetro (8-9: #F2B84B)
@export var color_meter_mid: Color = Color("f2b84b")

## Color de segmentos altos del vúmetro y LED de saturación (10: #FF6B5A)
@export var color_meter_high: Color = Color("ff6b5a")


## Devuelve el color correspondiente al papel del emisor del ruido
func get_color_for_role(role: StringName) -> Color:
	match role:
		&"own":
			return color_own
		&"guard":
			return color_guard
		_:
			return color_other
