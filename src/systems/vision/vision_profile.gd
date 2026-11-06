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

## Brillo y desaturación de lo que se alza del suelo en la niebla (#163): muros, muebles,
## pedestales. Solo un oscurecido suave, para que el borde de la vista no los barra al andar
@export var fog_raised_brightness: float = 0.8
@export var fog_raised_desaturation: float = 0.3

## Altura (m) sobre el suelo hasta la que un punto es suelo y desde la que es alzado (#163)
@export var fog_raised_from: float = 0.08
@export var fog_raised_to: float = 0.2

## Anchura (m) del borde suave entre lo visible y la niebla
@export var fog_edge_feather: float = 1.0

## Rayos con los que se calcula el polígono de la zona visible
@export var fog_rays: int = 256

## Segundos en que el borde de la niebla se funde al moverse (#161: sin saltos al andar). Lo
## oculto en la niebla sigue este mismo borde fundido
@export var fog_fade_time: float = 0.3

## Quitar las rendijas de un solo rayo: cuñas finas que saltan por los huecos lejanos (#161)
@export var fog_drop_slivers: bool = true
