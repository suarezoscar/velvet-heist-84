## @file noise_mix.gd
## Recurso de mezcla de audio para ruidos y pasos.
## Proporciona las familias de muestras de audio y las ganancias base por categoría.
class_name NoiseMix
extends Resource

@export var step_db: float = -14.0
@export var impact_db: float = -6.0
@export var mechanism_db: float = -10.0
## Voz de los guardias: bostezos (FEAT-029)
@export var voice_db: float = -8.0
## Cafetera de la garita (FEAT-030)
@export var coffee_db: float = -8.0
@export var soft_surface_max: float = 0.7
@export var hard_surface_min: float = 1.3
@export var step_soft: Array[AudioStream] = []
@export var step_wood: Array[AudioStream] = []
@export var step_hard: Array[AudioStream] = []
@export var impact: Array[AudioStream] = []
@export var mechanism: Array[AudioStream] = []
@export var voice: Array[AudioStream] = []
@export var coffee: Array[AudioStream] = []


## dB base de la categoría; 0.0 si la categoría no existe. El dial suena como un mecanismo
func category_db(category: StringName) -> float:
	var levels: Dictionary = {
		&"step": step_db,
		&"impact": impact_db,
		&"mechanism": mechanism_db,
		&"dial": mechanism_db,
		&"voice": voice_db,
		&"coffee": coffee_db,
	}
	return float(levels.get(category, 0.0))


## Familia de muestras: step según surface_mult y los umbrales; impact; mechanism; [] si no existe
func streams_for(category: StringName, surface_mult: float) -> Array[AudioStream]:
	var streams: Array[AudioStream] = []
	match category:
		&"step":
			streams = step_wood
			if surface_mult <= soft_surface_max:
				streams = step_soft
			elif surface_mult >= hard_surface_min:
				streams = step_hard
		&"impact":
			streams = impact
		&"mechanism", &"dial":
			streams = mechanism
		&"voice":
			streams = voice
		&"coffee":
			streams = coffee
	return streams
