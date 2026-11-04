## @file steal_minigame_rules.gd
## Números de los minijuegos de robo en la pieza (heist.md R9a-R9c, #119): la balanza del
## cambiazo, el piloto del sensor y los ruidos de trabajar y de fallar.
class_name StealMinigameRules
extends Resource

## Segundos con E pulsada que tarda el cambiazo
@export var swap_time: float = 6.0
## Media anchura de la franja verde en una esfera de −1 a 1
@export var needle_green_half: float = 0.35
## Velocidad de la aguja (esfera por segundo) al empezar y al acabar el cambiazo
@export var needle_drift_start: float = 0.15
@export var needle_drift_end: float = 0.40
## Segundos entre cambios de sentido de la aguja (al azar entre los dos)
@export var needle_flip_min: float = 0.8
@export var needle_flip_max: float = 2.0
## Velocidad a la que el ladrón empuja la aguja con ← →
@export var needle_correct_speed: float = 0.9
## Segundos que el piloto del sensor está encendido (al azar entre los dos)
@export var pilot_on_min: float = 1.2
@export var pilot_on_max: float = 1.8
## Segundos que el piloto está apagado: la ventana para pulsar E
@export var pilot_off_time: float = 0.5
## Aciertos seguidos para puentear el sensor
@export var bridge_hits: int = 3
## Radio del ruido al fallar (el mismo que fallar un número del dial)
@export var fail_noise_radius: float = 7.5
## Ruido suave de trabajar: radio y segundos entre ruidos (en el puente, uno por acierto)
@export var work_noise_radius: float = 2.0
@export var work_noise_interval: float = 1.0
