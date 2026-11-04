## @file guard_monitor_watch.gd
## Estado «mirando monitores» de un guardia o del ladrón (interaction.md M1 y M3; el ladrón
## desde FEAT-042): sentarse tarda
## monitor_enter_time; sentado no se mueve y mira fijo a la mesa. W/S (↑ ↓), interact o el fin
## de la partida lo levantan; A/D (← →) pasan de cámara, una por pulsación (#118, M2b).
class_name GuardMonitorWatch
extends RefCounted

enum State { NONE, ENTERING, WATCHING }

const RULES: CCTVRules = preload("res://data/balance/cctv_rules.tres")

var state: State = State.NONE
var desk: CCTVDesk3D = null

var _enter_timer: float = 0.0
## Lado (-1, 0, 1) que se pulsaba en el input anterior: una cámara por pulsación
var _last_side: int = 0


## true si está sentado o sentándose
func is_active() -> bool:
	return state != State.NONE


## Empieza a sentarse ante la mesa
func start(target_desk: CCTVDesk3D) -> void:
	desk = target_desk
	state = State.ENTERING
	_enter_timer = RULES.monitor_enter_time
	_last_side = 0


## Se levanta y libera la mesa
func stop(guard: PlayerBase3D) -> void:
	if desk != null:
		desk.release(guard)
	desk = null
	state = State.NONE
	_enter_timer = 0.0


## Avanza el tiempo de sentarse; la partida terminada lo levanta
func tick(guard: PlayerBase3D, delta: float) -> void:
	if state == State.NONE:
		return
	if GameManager.current_state != GameManager.MatchState.IN_PROGRESS:
		stop(guard)
		return
	if state == State.ENTERING:
		_enter_timer -= delta
		if _enter_timer <= 0.0:
			state = State.WATCHING
			if desk != null:
				desk.notify_watching(guard)


## Input que llega al guardia: sentado no se mueve y mira a la mesa. Adelante o atrás lo
## levanta (ese mismo input no lo mueve todavía); a un lado pasa de cámara (en el servidor)
func filter_input(guard: PlayerBase3D, input_data: Dictionary) -> Dictionary:
	if state == State.NONE:
		return input_data
	var move: Vector2 = input_data.get("movement_vector", Vector2.ZERO) as Vector2
	var filtered: Dictionary = input_data.duplicate()
	filtered["movement_vector"] = Vector2.ZERO
	filtered["is_sprinting"] = false
	if absf(move.y) >= 0.5:
		stop(guard)
		return filtered
	var side: int = signi(roundi(move.x)) if absf(move.x) >= 0.5 else 0
	if side != 0 and side != _last_side and state == State.WATCHING and desk != null:
		desk.step(side)
	_last_side = side
	if desk != null:
		filtered["look_target"] = desk.look_point()
	return filtered
