## Percepción cercana del guardia: proximidad, arco ciego, puntos de visibilidad, porra y oído.
## Valores en data/balance/perception_guard.tres; diseño en docs/gdd/systems/stealth.md.
class_name PerceptionProfile
extends Resource

@export var proximity_radius: float = 1.8
@export var rear_blind_arc_deg: float = 120.0
## Alturas (m) sobre los pies del objetivo: [cabeza, pecho] de pie y [alto, bajo] agachado
@export var stand_points: PackedFloat32Array = PackedFloat32Array([1.6, 1.2])
@export var crouch_points: PackedFloat32Array = PackedFloat32Array([0.9, 0.6])
@export var melee_range: float = 1.5
@export var ai_hearing_factor: float = 1.0
## Geometría del guardia (no es balance): ojos para la vista, torso para la porra
@export var eye_height: float = 1.5
@export var torso_height: float = 1.0
