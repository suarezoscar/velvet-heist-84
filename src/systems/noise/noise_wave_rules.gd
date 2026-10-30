## @file noise_wave_rules.gd
## Reglas puras de las miniondas de ruido (#114, stealth.md P2.4): quién ve la onda de un ruido
## y de qué tamaño. Sin nodos ni escena, para poder probarlas solas.
class_name NoiseWaveRules
extends RefCounted


## true si el jugador local debe ver la onda: el ruido le alcanza (misma regla que el audio),
## no lo hace él y viene del bando contrario (los guardias ven los del ladrón y el ladrón los de
## los guardias). Lo propio y lo del propio bando no hace onda.
static func should_show(
	local: PlayerBase3D,
	pos: Vector3,
	radius: float,
	team: StringName,
	emitter: Node,
	hearing_mult: float
) -> bool:
	if local == null or radius <= 0.0 or emitter == local:
		return false
	if team == local.team_id or not (team == &"thief" or team == &"guard"):
		return false
	return PerceptionRules.noise_reaches(local, pos, radius, team, hearing_mult)


## Radio final (m) de la onda: crece con el radio del ruido, dentro de [mínimo, máximo]
static func wave_radius(radius: float, profile: NoiseFeedbackProfile) -> float:
	return clampf(
		radius * profile.wave_radius_scale, profile.wave_min_radius, profile.wave_max_radius
	)
