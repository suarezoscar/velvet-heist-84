## @file thief_exposure.gd
## Cálculo del estado de exposición del ladrón (beam, lit o shadow).
## Determina la visibilidad del ladrón ante linternas o iluminación ambiental.
class_name ThiefExposure
extends RefCounted


## &"beam" si algún guardia con flashlight_on lo tiene en el cono con rayo libre desde
## flashlight_height a algún punto de visibilidad; si no, &"lit" si algún punto está iluminado
## (LightingRules.is_point_lit); si no, &"shadow"
static func compute(
	thief: ThiefController3D, guards: Array[GuardController3D], lamps: Array[Lamp3D]
) -> StringName:
	if thief == null:
		return &""

	for guard: GuardController3D in guards:
		if guard != null and GuardSenses.cone_sees(guard, thief):
			return &"beam"

	if GuardSenses.light_point_lit(thief, lamps):
		return &"lit"

	return &"shadow"
