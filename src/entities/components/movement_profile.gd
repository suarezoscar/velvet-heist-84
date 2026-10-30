## Perfil de movimiento de un bando (velocidades y modos de movimiento).
## Valores en data/balance/movement_*.tres; diseño en docs/gdd/systems/stealth.md.
class_name MovementProfile
extends Resource

enum Mode { WALK = 0, SNEAK = 1, SPRINT = 2, CROUCH = 3 }

@export var walk_speed: float = 4.5
@export var sneak_ratio: float = 0.48
@export var sprint_ratio: float = 1.5
@export var crouch_ratio: float = 0.40
@export var can_crouch: bool = true
@export var team_noise_mult: float = 1.0
@export var acceleration: float = 18.0
@export var friction: float = 22.0


## walk_speed × (1 | sneak_ratio | sprint_ratio | crouch_ratio) según el modo
func speed_for(mode: Mode) -> float:
	match mode:
		Mode.SNEAK:
			return walk_speed * sneak_ratio
		Mode.SPRINT:
			return walk_speed * sprint_ratio
		Mode.CROUCH:
			return walk_speed * crouch_ratio
		_:
			return walk_speed
