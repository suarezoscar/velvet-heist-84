## @file noise_feedback_profile.gd
## Perfil de balance para la retroalimentación de ruido (vúmetro, audio y HUD).
class_name NoiseFeedbackProfile
extends Resource

## Intervalo en segundos entre pulsos para fuentes continuas de ruido
@export var pulse_interval: float = 0.6

## Radio de ruido en metros que corresponde a la escala completa del vúmetro (100%)
@export var meter_full_scale: float = 10.0

## Tiempo en segundos de retención del valor pico en el vúmetro antes de iniciar la caída
@export var meter_hold_time: float = 0.15

## Tiempo en segundos de la caída lineal del vúmetro desde el pico hasta cero
@export var meter_fall_time: float = 0.4

## Suelo mínimo de ganancia lineal para audio en el límite exterior del radio
@export var audio_edge_floor: float = 0.2

## Volumen base en dB para la reproducción de los pasos del jugador local
@export var own_step_volume_db: float = -22.0

## Variación aleatoria de tono (pitch) aplicada a las muestras de audio
@export var pitch_jitter: float = 0.06

## Multiplicador de radio de audición del ladrón para ruidos de guardias
@export var thief_hearing_mult: float = 1.5

## Duración en segundos del indicador chevron para ruidos fuera de pantalla
@export var offscreen_marker_time: float = 2.0

## Volumen mínimo en dB de cualquier ruido que se oye, para que no se pierda en la mezcla
@export var min_audible_db: float = -28.0

## Proporción mínima (0..1) del volumen de los pasos propios aunque sean muy silenciosos
@export var own_step_min_ratio: float = 0.35

## Duración en segundos de la minionda en el origen de un ruido oído (#114)
@export var wave_time: float = 0.8

## Metros de onda por metro de radio del ruido: más fuerte, más grande
@export var wave_radius_scale: float = 0.14

## Radio mínimo en metros de la minionda (el ruido más flojo que se oye)
@export var wave_min_radius: float = 0.35

## Radio máximo en metros de la minionda (sigue siendo pequeña con ruidos muy fuertes)
@export var wave_max_radius: float = 1.1

## De oído no se sabe el punto exacto: la onda sale al azar dentro de un círculo de radio
## distancia × wave_error_ratio, como mucho wave_error_max metros (#114)
@export var wave_error_ratio: float = 0.15
@export var wave_error_max: float = 1.5
