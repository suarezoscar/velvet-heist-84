## @file vision_profile.gd
## Números de la visión y la niebla de guerra (vision.md).
class_name VisionProfile
extends Resource

## Radio (m) de la zona visible del ladrón
@export var thief_view_radius: float = 18.0

## Radio (m) de la zona visible de un guardia
@export var guard_view_radius: float = 12.0

## Distancia (m) a la que el ladrón ve a un guardia a oscuras y con la linterna apagada
@export var dark_sight_radius: float = 6.0

## Brillo de lo que queda en la niebla (1 = sin oscurecer)
@export var fog_brightness: float = 0.35

## Desaturación de lo que queda en la niebla (1 = gris)
@export var fog_desaturation: float = 0.7

## Canal más brillante a partir del cual un píxel (piloto, bombilla) atraviesa la niebla (D5)
@export var fog_light_keep: float = 0.9

## Anchura (m) del borde suave entre lo visible y la niebla
@export var fog_edge_feather: float = 1.0

## Rayos con los que se calcula el polígono de la zona visible
@export var fog_rays: int = 256
