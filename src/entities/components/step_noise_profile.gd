## Ruido de un paso: r = max(min_radius, base_radius × g_modo × superficie × bando).
class_name StepNoiseProfile
extends Resource

@export var base_radius: float = 3.5
@export var sneak_mult: float = 0.3
@export var sprint_mult: float = 2.0
@export var crouch_mult: float = 0.3
@export var min_radius: float = 0.5


## 1.0 para WALK; sneak_mult, sprint_mult o crouch_mult
func mode_mult(mode: MovementProfile.Mode) -> float:
	match mode:
		MovementProfile.Mode.SNEAK:
			return sneak_mult
		MovementProfile.Mode.SPRINT:
			return sprint_mult
		MovementProfile.Mode.CROUCH:
			return crouch_mult
		_:
			return 1.0


## maxf(min_radius, base_radius * mode_mult(mode) * surface_mult * team_mult)
func radius_for(mode: MovementProfile.Mode, surface_mult: float, team_mult: float) -> float:
	return maxf(min_radius, base_radius * mode_mult(mode) * surface_mult * team_mult)
