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
