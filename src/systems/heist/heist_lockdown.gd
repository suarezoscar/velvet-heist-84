## @file heist_lockdown.gd
## La cuenta atrás de las rejas (heist.md R7b, #120): la primera alarma da lockdown_time s para
## huir con lo puesto. A gate_drop_time s del final las rejas empiezan a bajar (con chirrido) y
## al tocar el suelo se cierran: si el ladrón no ha huido, gana la guardia («ENCERRADO» dentro,
## «SIN BOTÍN» en el callejón). No se para ni se reinicia. La lleva quien tiene la autoridad;
## los clientes la reciben por la red (para la cifra grande y las rejas).
class_name HeistLockdown
extends Node

const RULES: HeistRules = preload("res://data/balance/heist_rules.tres")

## Segundos hasta que las rejas tocan el suelo (-1: aún no ha saltado la alarma)
var left: float = -1.0
## Las rejas ya tocaron el suelo
var closed: bool = false


static func of(tree: SceneTree) -> HeistLockdown:
	return tree.get_first_node_in_group(&"heist_lockdown") as HeistLockdown if tree else null


func _ready() -> void:
	name = "HeistLockdown"
	add_to_group(&"heist_lockdown")
	add_to_group(&"net_state")
	process_physics_priority = -1  # después de las salidas (-2): quien sale en el último tick huye


func _physics_process(delta: float) -> void:
	if (
		not GameManager.is_simulating()
		or GameManager.current_state != GameManager.MatchState.IN_PROGRESS
	):
		return
	if left < 0.0:
		var alert: AlertDirector = AlertDirector.of(get_tree())
		if alert != null and alert.level == AlertDirector.Level.ALARM:
			left = RULES.lockdown_time
		return
	if closed:
		return
	var before: float = left
	left = maxf(0.0, left - delta)
	if before > RULES.gate_drop_time and left <= RULES.gate_drop_time:
		_gate_noise()  # el chirrido al empezar a bajar
	if left <= 0.0:
		closed = true
		_gate_noise()  # el golpe seco al tocar el suelo
		_close()


## true mientras corre la cuenta atrás (las rejas aún no han tocado el suelo)
func is_running() -> bool:
	return left >= 0.0 and not closed


## Lo que enseña la cifra grande: lo que llegue antes, las rejas o el final de la partida
func shown_time() -> float:
	return minf(left, GameManager.match_timer) if left >= 0.0 else -1.0


## De 0 (recogidas) a 1 (en el suelo)
func drop_progress() -> float:
	if closed:
		return 1.0
	if left < 0.0 or RULES.gate_drop_time <= 0.0:
		return 0.0
	return clampf(1.0 - left / RULES.gate_drop_time, 0.0, 1.0)


## Cómo acaba la partida si el ladrón está en una salida (o en el callejón) ahora mismo, o -1
## si no puede huir: con el encargo completo, huida (con o sin alarma); con la cuenta atrás en
## marcha y al menos una pieza, huida a medias; sin piezas, nada (R3, decisión 2 de #120)
static func escape_state(heist: HeistDirector, lockdown: HeistLockdown) -> int:
	if heist == null:
		return -1
	if heist.is_complete():
		return GameManager.MatchState.THIEF_ESCAPED
	if lockdown != null and lockdown.is_running() and not heist.stolen.is_empty():
		return GameManager.MatchState.THIEF_ESCAPED_PARTIAL
	return -1


func get_net_state() -> Dictionary:
	return {"left": snappedf(left, 0.01), "closed": closed}


func apply_net_state(state: Dictionary) -> void:
	left = float(state.get("left", left))
	closed = bool(state.get("closed", closed))


## Las rejas en el suelo y el ladrón sin huir: dentro, encerrado; en el callejón, sin botín
func _close() -> void:
	var thief: Node3D = get_tree().get_first_node_in_group(&"thief") as Node3D
	var outside: bool = false
	for node: Node in get_tree().get_nodes_in_group(&"heist_exits"):
		var zone: ExitZone3D = node as ExitZone3D
		if zone != null and zone.outdoor and thief != null and zone.overlaps_body(thief):
			outside = true
	GameManager.end_match(
		GameManager.MatchState.THIEF_NO_LOOT if outside else GameManager.MatchState.THIEF_LOCKED_IN
	)


func _gate_noise() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"heist_exits"):
		var zone: ExitZone3D = node as ExitZone3D
		if zone != null and not zone.outdoor:
			NoiseEmit.emit(
				zone.global_position, RULES.gate_radius, &"world", NoiseEmit.MECHANISM, null
			)
