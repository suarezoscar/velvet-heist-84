## @file noise_audio_rules.gd
## Reglas matemáticas puras de ganancia y atenuación de audio acústico.
class_name NoiseAudioRules
extends RefCounted


## f + (1 - f) × (1 - d / r) si d <= r y r > 0; 0.0 en otro caso
static func gain(d: float, r: float, edge_floor: float) -> float:
	if r <= 0.0 or d > r or d < 0.0:
		return 0.0
	return edge_floor + (1.0 - edge_floor) * (1.0 - d / r)
