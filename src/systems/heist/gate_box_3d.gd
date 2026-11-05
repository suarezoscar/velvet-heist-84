## @file gate_box_3d.gd
## Caja de la reja de una salida (heist.md R7c, #121): en la pared de dentro, junto a la puerta.
## El ladrón la sabotea con su minijuego (SabotageSession); lo hecho se queda en la caja. Con la
## alarma, si está saboteada cuando las rejas empiezan a bajar, la reja de su salida se queda
## arriba (HeistLockdown). Saboteada, echa una chispa de vez en cuando (un ruido pequeño que la
## IA investiga). Un guardia la repara en box_repair_time s y la deja entera con otro orden de
## cables. Lo decide quien tiene la autoridad; el aspecto vive en GateBoxLook.
class_name GateBox3D
extends Area3D

enum Step { WHOLE, UNSCREW, CUT, SCREW, SABOTAGED }

const RULES: HeistRules = preload("res://data/balance/heist_rules.tres")
const SIZE: Vector3 = Vector3(0.5, 0.6, 0.15)
const HEIGHT: float = 1.3
## Meta de cada guardia: cajas reparadas (para el informe)
const REPAIRS_META: StringName = &"box_repairs"

var exit_id: String = ""
var step: Step = Step.WHOLE
var screws_out: int = 0
var screws_in: int = 0
## Puntas de cable ya cortadas, en el orden en que se cortaron
var cut_tips: Array[int] = []
## Borne (0..box_wires-1) al que llega cada punta de cable
var terminal_of: Array[int] = []
var fails: int = 0
## Minijuego del ladrón en curso (en la autoridad) y lo que llega de él (cliente)
var game: SabotageSession = null
## Chispas echadas (las máquinas pintan un destello cuando cambia)
var sparks: int = 0
var _view: Dictionary = {}
var _repair: TimedTask = null
var _repair_noise: float = 0.0
var _spark_left: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


static func create(id: String) -> GateBox3D:
	var box: GateBox3D = GateBox3D.new()
	box.exit_id = id
	box.name = "GateBox_%s" % id
	return box


func _ready() -> void:
	add_to_group(&"net_state")
	add_to_group(&"gate_boxes")
	collision_layer = 4  # Interactuable
	collision_mask = 2
	monitoring = true
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(1.0, 1.8, 1.0)
	var col: CollisionShape3D = CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0.0, 0.9, 0.0)
	add_child(col)
	_rng.randomize()
	_shuffle()
	_spark_left = _spark_time()
	GateBoxLook.build(self)


func _physics_process(delta: float) -> void:
	if game != null and game.tick(delta) != SabotageSession.Result.RUNNING:
		game = null
	if _repair != null:
		_repair_noise -= delta
		if _repair_noise <= 0.0:
			_repair_noise = 1.0
			var radius: float = SabotageSession.STEAL.work_noise_radius
			NoiseEmit.emit(global_position, radius, &"guard", NoiseEmit.MECHANISM, _repair.actor)
		if _repair.tick(delta):
			_repair = null
	if (
		step == Step.SABOTAGED
		and _repair == null
		and GameManager.is_simulating()
		and GameManager.current_state == GameManager.MatchState.IN_PROGRESS
	):
		_spark_left -= delta
		if _spark_left <= 0.0:
			_spark_left = _spark_time()
			sparks += 1
			NoiseEmit.emit(
				global_position, RULES.box_spark_radius, &"thief", NoiseEmit.IMPACT, null
			)


func _process(_delta: float) -> void:
	GateBoxLook.update(self)


func is_sabotaged() -> bool:
	return step == Step.SABOTAGED


## Tocada: a medias o saboteada (se nota de cerca y se puede reparar)
func is_tampered() -> bool:
	return step != Step.WHOLE


## Aún se puede sabotear: su reja no ha empezado a bajar (sabotear nunca la sube)
func can_sabotage() -> bool:
	var lockdown: HeistLockdown = HeistLockdown.of(get_tree())
	return lockdown == null or not lockdown.gates_committed()


func can_interact(actor: Node3D = null) -> bool:
	if actor is GuardController3D:
		return is_tampered() and _repair == null and game == null
	if not (actor is ThiefController3D) or step == Step.SABOTAGED or _repair != null:
		return false
	if game != null:
		return game.actor == actor
	return can_sabotage()


func get_interaction_text(actor: Node3D = null) -> String:
	if actor is GuardController3D:
		return "Reparando la caja…" if _repair != null else "Reparar la caja de la reja [E]"
	if is_playing():
		return ""  # lo enseña el panel del sabotaje
	if step == Step.SABOTAGED:
		return "Reja saboteada"
	if not can_sabotage():
		return "La reja ya ha bajado"
	return "Seguir con la reja [E]" if is_tampered() else "Sabotear la reja [E]"


## E: el guardia repara; el ladrón empieza, sigue o, dentro, sujeta o corta
func interact(actor: Node3D) -> void:
	if not can_interact(actor):
		return
	if actor is GuardController3D:
		_repair = TimedTask.start(actor, RULES.box_repair_time, RULES.task_leash, _finish_repair)
		_repair_noise = 0.0
	elif game != null:
		game.press()
	else:
		game = SabotageSession.start(self, actor)


## E, soltar E o Esc dentro del sabotaje (como en las piezas)
func minigame_action(actor: Node3D, action: StringName) -> void:
	if game == null or game.actor != actor:
		return
	match action:
		&"interact":
			game.press()
		&"interact_release":
			game.release()
		&"dial_cancel":
			game = null


func steer(actor: Node3D, move: Vector2) -> void:
	if game != null and game.actor == actor:
		game.steer(move)


## true mientras el ladrón la sabotea (también en el cliente, por la red)
func is_playing() -> bool:
	return game != null or int(_view.get("game", 0)) != 0


func minigame_view() -> Dictionary:
	if game != null:
		return game.to_view()
	return _view if is_playing() else {}


## Público: el paso (para pintar la tapa: entera, fuera o torcida) y las chispas
func get_net_state() -> Dictionary:
	return {"step": int(step), "sparks": sparks}


## Privado, solo para el ladrón: su minijuego
func get_net_state_private() -> Dictionary:
	return game.to_view() if game != null else {"game": 0}


func net_private_audience() -> StringName:
	return &"thief"


func apply_net_state(state: Dictionary) -> void:
	if state.has("game"):
		_view = state.duplicate()
		return
	step = int(state.get("step", step)) as Step
	sparks = int(state.get("sparks", sparks))


func _finish_repair(actor: Node3D) -> void:
	step = Step.WHOLE
	screws_out = 0
	screws_in = 0
	cut_tips.clear()
	fails = 0
	game = null
	_shuffle()
	actor.set_meta(REPAIRS_META, int(actor.get_meta(REPAIRS_META, 0)) + 1)
	var lockdown: HeistLockdown = HeistLockdown.of(get_tree())
	if lockdown != null:
		lockdown.on_box_repaired(exit_id)


func _shuffle() -> void:
	terminal_of.clear()
	for i: int in range(RULES.box_wires):
		terminal_of.append(i)
	for i: int in range(terminal_of.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: int = terminal_of[i]
		terminal_of[i] = terminal_of[j]
		terminal_of[j] = tmp


func _spark_time() -> float:
	return _rng.randf_range(RULES.box_spark_min, RULES.box_spark_max)
