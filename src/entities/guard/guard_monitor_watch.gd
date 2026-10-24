## @file guard_monitor_watch.gd
## Estado «mirando monitores» de un guardia (interaction.md M1 y M3): sentarse tarda
## monitor_enter_time; sentado no se mueve y mira fijo a la mesa. El primer input de
## movimiento, interact o el fin de la partida lo levantan.
class_name GuardMonitorWatch
extends RefCounted

enum State { NONE, ENTERING, WATCHING }

const RULES: CCTVRules = preload("res://data/balance/cctv_rules.tres")

var state: State = State.NONE
var desk: CCTVDesk3D = null

var _enter_timer: float = 0.0


## true si está sentado o sentándose
func is_active() -> bool:
	return state != State.NONE


## Empieza a sentarse ante la mesa
func start(target_desk: CCTVDesk3D) -> void:
	desk = target_desk
	state = State.ENTERING
	_enter_timer = RULES.monitor_enter_time


## Se levanta y libera la mesa
func stop(guard: GuardController3D) -> void:
	if desk != null:
		desk.release(guard)
	desk = null
	state = State.NONE
	_enter_timer = 0.0


## Avanza el tiempo de sentarse; la partida terminada lo levanta
func tick(guard: GuardController3D, delta: float) -> void:
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


## Input que llega al guardia: sentado no se mueve y mira a la mesa. Un movimiento lo
## levanta, pero ese mismo input no lo mueve todavía
func filter_input(guard: GuardController3D, input_data: Dictionary) -> Dictionary:
	if state == State.NONE:
		return input_data
	var move: Vector2 = input_data.get("movement_vector", Vector2.ZERO) as Vector2
	var filtered: Dictionary = input_data.duplicate()
	filtered["movement_vector"] = Vector2.ZERO
	filtered["is_sprinting"] = false
	if move.length_squared() > 0.0001:
		stop(guard)
		return filtered
	if desk != null:
		filtered["look_target"] = desk.look_point()
	return filtered
