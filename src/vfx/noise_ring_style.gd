## @file noise_ring_style.gd
## Recurso de estilo visual para los anillos de ruido "radar de 1984".
## Define anchos de trazo, resplandor, opacidades y paleta de colores por papel.
class_name NoiseRingStyle
extends Resource

## Trazo base en píxeles en pantalla (2 px)
@export var stroke_px: float = 2.0

## Halo de fósforo a cada lado del trazo en píxeles (4 px)
@export var glow_px: float = 4.0

## Opacidad base del trazo (0.45)
@export var alpha: float = 0.45

## Opacidad máxima del halo de fósforo (0.15)
@export var glow_alpha: float = 0.15

## Separación entre trazos en anillos dobles en píxeles (4 px)
@export var double_gap_px: float = 4.0

## Número de segmentos en anillos discontinuos (24)
@export var dash_segments: int = 24

## Color de ruido propio (#F2B84B - ámbar de fósforo)
@export var color_own: Color = Color("f2b84b")

## Color de ruido de guardia visto por el ladrón (#4FC3F7 - cian)
@export var color_guard: Color = Color("4fc3f7")

## Color de ruido ajeno visto por un guardia (#B8E6C1 - verde fósforo pálido)
@export var color_other: Color = Color("b8e6c1")


## Devuelve el color correspondiente al papel del emisor del ruido
func get_color_for_role(role: StringName) -> Color:
	match role:
		&"own":
			return color_own
		&"guard":
			return color_guard
		_:
			return color_other
