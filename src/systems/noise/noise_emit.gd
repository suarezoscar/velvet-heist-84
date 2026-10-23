## @file noise_emit.gd
## Emisor desacoplado de eventos sonoros 3D.
## Emite la señal acústica general (noise_emitted_3d) y el evento categorizado (noise_event_3d).
class_name NoiseEmit
extends RefCounted

const STEP: StringName = &"step"
const IMPACT: StringName = &"impact"
const MECHANISM: StringName = &"mechanism"


## Emite noise_emitted_3d(pos, radius, team) y después
## noise_event_3d(pos, radius, team, category, emitter)
static func emit(
	pos: Vector3, radius: float, team: StringName, category: StringName, emitter: Node
) -> void:
	SignalBus.noise_emitted_3d.emit(pos, radius, team)
	SignalBus.noise_event_3d.emit(pos, radius, team, category, emitter)
