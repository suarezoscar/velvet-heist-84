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

## Canal más brillante a partir del cual un píxel (piloto, bombilla) atraviesa la niebla (D5)
@export var fog_light_keep: float = 0.9

## Altura (m) sobre el suelo hasta la que un punto es suelo y desde la que es alzado (#163)
@export var fog_raised_from: float = 0.08
@export var fog_raised_to: float = 0.2

## Anchura (m) del borde suave entre lo visible y la niebla, en el suelo (#186: corto)
@export var fog_edge_feather: float = 0.4

## Anchura (m) del mismo borde en lo que se alza del suelo: más ancho, para que no barra las
## paredes con un salto al andar (#161, #163)
@export var fog_raised_feather: float = 1.5

## Plano en la niebla (#186): tintas de la sombra a la luz del suelo y de lo alzado, y contorno
@export var fog_ink_floor_dark: Color = Color(0.02, 0.035, 0.09)
@export var fog_ink_floor_light: Color = Color(0.07, 0.13, 0.27)
@export var fog_ink_raised_dark: Color = Color(0.06, 0.1, 0.22)
@export var fog_ink_raised_light: Color = Color(0.2, 0.32, 0.58)
@export var fog_ink_line: Color = Color(0.55, 0.75, 1.0)

## Fuerza del contorno del plano (0 lo quita)
@export var fog_line_strength: float = 0.2

## Sin contorno a menos de esta distancia (m) del jugador: el tramado de rayos X dejaría puntos
@export var fog_line_clear_near: float = 2.0

## Rayos con los que se calcula el polígono de la zona visible
@export var fog_rays: int = 256

## Segundos en que el borde de la niebla se funde al moverse (#161: sin saltos al andar). Lo
## oculto en la niebla sigue este mismo borde fundido
@export var fog_fade_time: float = 0.3

## Quitar las rendijas de un solo rayo: cuñas finas que saltan por los huecos lejanos (#161)
@export var fog_drop_slivers: bool = true
