## @file timed_task.gd
## Una acción que tarda (heist.md R9: dar el cambiazo, examinar, cortar o restablecer la
## corriente): el actor tiene que quedarse cerca (RULES.task_leash) hasta que acabe; si se
## aleja, se cancela. Lo avanza quien tiene la autoridad. Lógica pura.
class_name TimedTask
extends RefCounted

var actor: Node3D = null
var left: float = 0.0
var _origin: Vector3 = Vector3.ZERO
var _leash: float = 1.5
var _done: Callable = Callable()


static func start(who: Node3D, seconds: float, leash: float, on_done: Callable) -> TimedTask:
	var task: TimedTask = TimedTask.new()
	task.actor = who
	task.left = seconds
	task._origin = who.global_position
	task._leash = leash
	task._done = on_done
	return task


## Avanza; true si ha terminado (completada o cancelada)
func tick(delta: float) -> bool:
	if GameManager.is_match_over():
		return true  # con la partida acabada no termina nada
	if not is_instance_valid(actor) or actor.global_position.distance_to(_origin) > _leash:
		return true
	left -= delta
	if left > 0.0:
		return false
	_done.call(actor)
	return true
