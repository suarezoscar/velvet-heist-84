## @file noise_feedback_profile.gd
## Perfil de balance para la retroalimentación de ruido (vúmetro, audio y HUD).
class_name NoiseFeedbackProfile
extends Resource

@export var pulse_interval: float = 0.6
@export var meter_full_scale: float = 10.0
@export var meter_hold_time: float = 0.15
@export var meter_fall_time: float = 0.4
@export var audio_edge_floor: float = 0.2
@export var own_step_volume_db: float = -22.0
@export var pitch_jitter: float = 0.06
@export var thief_hearing_mult: float = 1.5
@export var offscreen_marker_time: float = 2.0
