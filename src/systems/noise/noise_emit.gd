## @file noise_emit.gd
## Emisor desacoplado de eventos sonoros 3D.
## Emite la señal acústica general (noise_emitted_3d) y el evento categorizado (noise_event_3d).
class_name NoiseEmit
extends RefCounted

const STEP: StringName = &"step"
const IMPACT: StringName = &"impact"
const MECHANISM: StringName = &"mechanism"
## Tintineo metálico del ladrón (#111): la moneda al caer y coger botín suenan igual, para que
## el guardia no sepa cuál de las dos es. Suena según el suelo del punto donde se produce
const CLINK: StringName = &"clink"


## Emite noise_emitted_3d(pos, radius, team) y después
## noise_event_3d(pos, radius, team, category, emitter)
static func emit(
	pos: Vector3, radius: float, team: StringName, category: StringName, emitter: Node
) -> void:
	if NetManager.is_online():
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		if tree != null and not tree.get_multiplayer().is_server():
			return

	SignalBus.noise_emitted_3d.emit(pos, radius, team)
	SignalBus.noise_event_3d.emit(pos, radius, team, category, emitter)
