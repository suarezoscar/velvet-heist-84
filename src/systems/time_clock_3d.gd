## @file time_clock_3d.gd
## Reloj de fichar de la ronda de los guardias (interaction.md, parte R).
## Cuenta atrás desde round_duration; vencido apunta faltas en la hoja de ronda, suena la
## campana y baja una banderola roja. Solo el servidor (o la partida sin red) simula.
class_name TimeClock3D
extends Area3D

## Emitida cuando un guardia gira su llave en la ranura
signal clock_punched(clock_id: int, guard_peer_id: int)

## Emitida cuando el tiempo de ronda expira sin haber fichado
signal clock_expired(clock_id: int)

const RULES: TimeClockRules = preload("res://data/balance/time_clock_rules.tres")
const FLAG_COLOR: Color = Color(0.85, 0.08, 0.06)
const FLAG_SIZE: Vector3 = Vector3(0.35, 0.5, 0.04)
const FLAG_HEIGHT: float = 2.15

## Identificador del reloj en el mapa
@export var clock_id: int = 1

## Ventana de ronda (global, de time_clock_rules.tres)
var round_duration: float = RULES.round_duration

## Tiempo restante antes de vencer
var time_left: float = RULES.round_duration

## Indica si el reloj está vencido
var is_expired: bool = false

## Faltas que este reloj ha apuntado en la hoja de ronda; nunca bajan en la partida
var faults: int = 0

var _alert_pulse_timer: float = 0.0
var _expired_time: float = 0.0
## Faltas ya apuntadas en el episodio de vencimiento actual
var _episode_faults: int = 0
var _flag: MeshInstance3D = null


func _ready() -> void:
	add_to_group(&"net_state")
	add_to_group(&"time_clock")
	collision_layer = 4  # Interactuable
	collision_mask = 1  # Guardias y entorno
	monitoring = true
	time_left = round_duration
	_build_flag()


func _physics_process(delta: float) -> void:
	if GameManager.current_state != GameManager.MatchState.IN_PROGRESS:
		return
	if not GameManager.is_simulating():
		return
	_update_countdown(delta)


## Vuelve al estado de inicio de partida: ventana completa y hoja limpia
func reset_round() -> void:
	time_left = round_duration
	is_expired = false
	faults = 0
	_alert_pulse_timer = 0.0
	_expired_time = 0.0
	_episode_faults = 0
	_update_flag()


func _update_countdown(delta: float) -> void:
	if is_expired:
		_expired_time += delta
		var due: int = 1 + int(floor(_expired_time / round_duration))
		if due > _episode_faults:
			faults += due - _episode_faults
			_episode_faults = due
		_alert_pulse_timer += delta
		if _alert_pulse_timer >= RULES.alarm_pulse_interval:
			_alert_pulse_timer = 0.0
			_emit_alarm_noise(RULES.alarm_noise_radius)
		return
	time_left -= delta
	if time_left <= 0.0:
		var overshoot: float = -time_left
		time_left = 0.0
		is_expired = true
		_expired_time = 0.0
		_episode_faults = 0
		_update_flag()
		clock_expired.emit(clock_id)
		print("[TimeClock3D #%d] ¡Alarma de ronda! Guardias no ficharon a tiempo." % clock_id)
		_update_countdown(overshoot)


## Contrato de interacción: solo los guardias pueden fichar en los relojes de ronda
func can_interact(actor: Node3D = null) -> bool:
	return actor is GuardController3D


## Devuelve el texto del prompt para el HUD del guardia
func get_interaction_text(_actor: Node3D = null) -> String:
	if is_expired:
		return "¡ALARMA DE RONDA ACTIVA! Fichar Reloj [E]"
	return "Fichar Ronda Mecanica (%ds restantes) [E]" % int(ceil(time_left))


## Ejecuta el fichaje de llave del guardia: la ventana vuelve a empezar, las faltas se quedan
func interact(actor: Node3D) -> void:
	if not actor is GuardController3D:
		return

	time_left = round_duration
	is_expired = false
	_alert_pulse_timer = 0.0
	_expired_time = 0.0
	_episode_faults = 0
	_update_flag()

	var peer_id: int = 1
	if multiplayer != null and multiplayer.has_multiplayer_peer():
		peer_id = multiplayer.get_unique_id()

	clock_punched.emit(clock_id, peer_id)
	print("[TimeClock3D #%d] Fichado por guardia %d (%.0fs)" % [clock_id, peer_id, round_duration])

	SignalBus.time_clock_punched.emit(clock_id, peer_id)
	NoiseEmit.emit(global_position, RULES.punch_noise_radius, &"guard", NoiseEmit.MECHANISM, actor)


func _emit_alarm_noise(radius: float) -> void:
	NoiseEmit.emit(global_position, radius, &"guard", NoiseEmit.MECHANISM, self)


## Estado público para red: solo si está vencido (lo ve todo el mundo por la banderola)
func get_net_state() -> Dictionary:
	return {"expired": is_expired}


## Estado privado de los guardias: segundos restantes y faltas (nunca al ladrón)
func get_net_state_private() -> Dictionary:
	return {"time_left": snappedf(time_left, 0.1), "faults": faults}


## Audiencia del estado privado (NetPrivateStates)
func net_private_audience() -> StringName:
	return &"guard"


## Aplica el snapshot de estado recibido por red
func apply_net_state(state: Dictionary) -> void:
	if state.has("time_left"):
		time_left = float(state["time_left"])
	if state.has("expired"):
		is_expired = bool(state["expired"])
		_update_flag()
	if state.has("faults"):
		faults = int(state["faults"])


func _build_flag() -> void:
	_flag = MeshInstance3D.new()
	_flag.name = "ExpiredFlag"
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = FLAG_SIZE
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = FLAG_COLOR
	material.emission_enabled = true
	material.emission = FLAG_COLOR
	material.emission_energy_multiplier = 0.6
	mesh.material = material
	_flag.mesh = mesh
	_flag.position = Vector3(0.0, FLAG_HEIGHT, -0.25)
	add_child(_flag)
	_update_flag()


func _update_flag() -> void:
	if _flag != null:
		_flag.visible = is_expired
