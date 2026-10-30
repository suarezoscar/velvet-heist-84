## @file noise_surface.gd
## Suelo de un ruido para elegir su muestra: el de bajo los pies de quien lo hace o, para la
## moneda y el botín (tintineo), el del punto donde suena (#111). No cambia lo lejos que llega.
class_name NoiseSurface
extends RefCounted


static func mult_for(emitter: Node, category: StringName, pos: Vector3, world: World3D) -> float:
	if category == NoiseEmit.CLINK:
		return SurfaceDetector3D.multiplier_at(world, pos)
	var actor: PlayerBase3D = emitter as PlayerBase3D
	if actor != null and actor.surface_detector != null:
		return actor.surface_detector.get_surface_noise_multiplier()
	return 1.0
