## @file sabotage_session.gd
## El minijuego de sabotear la caja de la reja (heist.md R7c, #121), en tres pasos: quitar los
## tornillos de la tapa (mantener E), cortar los cables por orden de borne (← → eligen, E corta)
## y volver a atornillar la tapa. Lo hecho se guarda en la caja (GateBox3D): cancelar solo
## pierde el tornillo a medias. Cortar el cable que no toca hace un chispazo
## (fail_noise_radius) y cuesta box_splice_time s. Lo avanza quien tiene la autoridad.
class_name SabotageSession
extends RefCounted

enum Result { RUNNING, DONE, CANCELLED }

const RULES: HeistRules = preload("res://data/balance/heist_rules.tres")
const STEAL: StealMinigameRules = preload("res://data/balance/steal_minigames.tres")

var actor: Node3D = null
var box: GateBox3D = null
## E pulsada (pasos 1 y 3)
var holding: bool = true
## Punta de cable elegida (paso 2)
var selected: int = 0
## Lo que lleva el tornillo a medias, de 0 a 1 (se pierde al cancelar)
var screw_progress: float = 0.0
## Segundos que quedan empalmando tras un fallo
var splice_left: float = 0.0
var _origin: Vector3 = Vector3.ZERO
var _cancelled: bool = false
var _armed: bool = false
var _last_side: int = 0


static func start(target: GateBox3D, who: Node3D) -> SabotageSession:
	var session: SabotageSession = SabotageSession.new()
	session.box = target
	session.actor = who
	session._origin = who.global_position
	if target.step == GateBox3D.Step.WHOLE:
		target.step = GateBox3D.Step.UNSCREW
	session.selected = session._first_uncut()
	return session


## E: en los tornillos vuelve a sujetar; en los cables, corta el elegido
func press() -> void:
	if box.step != GateBox3D.Step.CUT:
		holding = true
	elif splice_left <= 0.0 and not box.cut_tips.has(selected):
		if box.terminal_of[selected] == box.cut_tips.size():
			box.cut_tips.append(selected)
			_noise(STEAL.work_noise_radius)
			selected = _first_uncut()
		else:
			box.fails += 1
			splice_left = RULES.box_splice_time
			_noise(STEAL.fail_noise_radius)  # chispazo: nunca alarma


func release() -> void:
	holding = false


## Teclas de movimiento de pantalla: en los cables, ← → eligen (una por pulsación) y W S cancelan;
## con los tornillos, cualquiera cancela. La que ya se mantenía al abrirlo no cuenta
func steer(move: Vector2) -> void:
	var cutting: bool = box.step == GateBox3D.Step.CUT
	var cancels: bool = absf(move.y) >= 0.5 if cutting else move.length() >= 0.5
	if not cancels:
		_armed = true
	elif _armed:
		_cancelled = true
		return
	var side: int = signi(roundi(move.x)) if absf(move.x) >= 0.5 else 0
	if cutting and side != 0 and side != _last_side:
		selected = _next_uncut(side)
	_last_side = side


func cancel() -> void:
	_cancelled = true


func tick(delta: float) -> Result:
	if _cancelled or GameManager.is_match_over() or not is_instance_valid(actor):
		return Result.CANCELLED
	if actor.global_position.distance_to(_origin) > RULES.task_leash or not box.can_sabotage():
		return Result.CANCELLED
	match box.step:
		GateBox3D.Step.UNSCREW, GateBox3D.Step.SCREW:
			_tick_screws(delta)
		GateBox3D.Step.CUT:
			splice_left = maxf(0.0, splice_left - delta)
			if box.cut_tips.size() >= RULES.box_wires:
				box.step = GateBox3D.Step.SCREW
				holding = false  # hay que volver a mantener E para cerrar
	return Result.DONE if box.step == GateBox3D.Step.SABOTAGED else Result.RUNNING


## Estado para el panel del ladrón (y su estado privado de red)
func to_view() -> Dictionary:
	return {
		"game": 1,
		"step": int(box.step),
		"screws": box.screws_out if box.step == GateBox3D.Step.UNSCREW else box.screws_in,
		"screw": snappedf(screw_progress, 0.01),
		"holding": holding,
		"terminals": box.terminal_of.duplicate(),
		"cut": box.cut_tips.duplicate(),
		"selected": selected,
		"splice": snappedf(splice_left, 0.01),
		"fails": box.fails,
	}


func _tick_screws(delta: float) -> void:
	if not holding:
		return
	screw_progress += delta / RULES.box_screw_time
	if screw_progress < 1.0:
		return
	screw_progress = 0.0
	_noise(STEAL.work_noise_radius)
	if box.step == GateBox3D.Step.UNSCREW:
		box.screws_out += 1
		if box.screws_out >= RULES.box_screws:
			box.step = GateBox3D.Step.CUT
	else:
		box.screws_in += 1
		if box.screws_in >= RULES.box_screws:
			box.step = GateBox3D.Step.SABOTAGED


func _first_uncut() -> int:
	for tip: int in range(box.terminal_of.size()):
		if not box.cut_tips.has(tip):
			return tip
	return 0


func _next_uncut(direction: int) -> int:
	var count: int = box.terminal_of.size()
	for i: int in range(1, count + 1):
		var tip: int = posmod(selected + direction * i, count)
		if not box.cut_tips.has(tip):
			return tip
	return selected


func _noise(radius: float) -> void:
	if is_instance_valid(actor) and actor.is_inside_tree():
		NoiseEmit.emit(actor.global_position, radius, &"thief", NoiseEmit.MECHANISM, actor)
