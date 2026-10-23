## @file time_clock_3d.gd
## Reloj analógico de fichar de pared para la mecánica anti-camping de los guardias.
## Obliga al equipo de seguridad a patrullar y fichar antes de que expire la ronda de 90 segundos.
class_name TimeClock3D
extends Area3D

signal clock_punched(clock_id: int, guard_peer_id: int)
signal clock_expired(clock_id: int)

const DEFAULT_ROUND_DURATION: float = 90.0

@export var clock_id: int = 1
@export var round_duration: float = DEFAULT_ROUND_DURATION

var time_left: float = DEFAULT_ROUND_DURATION
var is_expired: bool = false
var _alert_pulse_timer: float = 0.0


func _ready() -> void:
	collision_layer = 4  # Interactuable
	collision_mask = 1  # Guardias y entorno
	monitoring = true
	time_left = round_duration


func _physics_process(delta: float) -> void:
	if GameManager.current_state != GameManager.MatchState.IN_PROGRESS:
		return

	_update_countdown(delta)


func _update_countdown(delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		if not is_expired:
			is_expired = true
			clock_expired.emit(clock_id)
			print("[TimeClock3D #%d] ¡Alarma de ronda! Guardias no ficharon a tiempo." % clock_id)

		_alert_pulse_timer += delta
		if _alert_pulse_timer >= 3.0:
			_alert_pulse_timer = 0.0
			_emit_alarm_noise(14.0)


## Contrato de interacción: solo los guardias pueden fichar en los relojes de ronda
func can_interact(actor: Node3D = null) -> bool:
	return actor is GuardController3D


## Devuelve el texto del prompt para el HUD del guardia
func get_interaction_text(_actor: Node3D = null) -> String:
	if is_expired:
		return "¡ALARMA DE RONDA ACTIVA! Fichar Reloj [E]"
	return "Fichar Ronda Mecanica (%ds restantes) [E]" % int(time_left)


## Ejecuta el fichaje de llave del guardia
func interact(actor: Node3D) -> void:
	if not actor is GuardController3D:
		return

	time_left = round_duration
	is_expired = false
	_alert_pulse_timer = 0.0

	var peer_id: int = 1
	if multiplayer != null and multiplayer.has_multiplayer_peer():
		peer_id = multiplayer.get_unique_id()

	clock_punched.emit(clock_id, peer_id)
	print("[TimeClock3D #%d] Fichado por guardia %d (%.0fs)" % [clock_id, peer_id, round_duration])

	SignalBus.time_clock_punched.emit(clock_id, peer_id)
	NoiseEmit.emit(global_position, 5.5, &"guard", NoiseEmit.MECHANISM, actor)


func _emit_alarm_noise(radius: float) -> void:
	NoiseEmit.emit(global_position, radius, &"guard", NoiseEmit.MECHANISM, self)
