## @file heist_lockdown.gd
## La cuenta atrás de las rejas (heist.md R7b, #120): la primera alarma da lockdown_time s para
## huir con lo puesto. A gate_drop_time s del final las rejas empiezan a bajar (con chirrido) y
## al tocar el suelo se cierran: si el ladrón no ha huido y no queda ninguna salida abierta, gana
## la guardia («ENCERRADO» dentro, «SIN BOTÍN» en el callejón). No se para ni se reinicia.
## #121 (R7c): la reja de una caja saboteada al empezar a bajar se queda arriba (held); si un
## guardia la repara después, baja sola en gate_drop_time (late). Con alguna abierta, la partida
## sigue hasta que huya, lo atrapen o amanezca. La lleva quien tiene la autoridad;
## los clientes la reciben por la red (para la cifra grande y las rejas).
class_name HeistLockdown
extends Node

const RULES: HeistRules = preload("res://data/balance/heist_rules.tres")

## Segundos hasta que las rejas tocan el suelo (-1: aún no ha saltado la alarma)
var left: float = -1.0
## Las rejas ya tocaron el suelo
var closed: bool = false
## Salidas cuya reja se quedó arriba (caja saboteada): id → true
var held: Dictionary = {}
## Salidas cuya reja baja tarde (caja reparada tras empezar a bajar): id → segundos que faltan
var late: Dictionary = {}
## El ladrón huyó por una salida que seguía abierta gracias al sabotaje (informe, R11)
var sabotage_escape: bool = false


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
	_tick_late(delta)
	if closed:
		return
	var before: float = left
	left = maxf(0.0, left - delta)
	if before > RULES.gate_drop_time and left <= RULES.gate_drop_time:
		_hold_sabotaged()
		_gate_noise()  # el chirrido al empezar a bajar (y el chasquido de las frenadas)
	if left <= 0.0:
		closed = true
		_gate_noise()  # el golpe seco al tocar el suelo
		_close()


## true mientras corre la cuenta atrás (las rejas aún no han tocado el suelo)
func is_running() -> bool:
	return left >= 0.0 and not closed


## Las rejas ya empezaron a bajar: qué cajas cuentan ya está decidido (R7c)
func gates_committed() -> bool:
	return left >= 0.0 and left <= RULES.gate_drop_time


## La salida id se puede cruzar: antes de cerrarse, todas; después, las frenadas o bajando tarde
func exit_open(exit_id: String) -> bool:
	return not closed or held.has(exit_id) or late.has(exit_id)


## Salidas que siguen abiertas con las rejas cerradas
func open_count() -> int:
	return held.size() + late.size() if closed else 0


## Aún se puede huir con lo puesto: corre la cuenta atrás o queda alguna salida abierta
func escapes_open() -> bool:
	return is_running() or open_count() > 0


## De 0 (recogida) a 1 (en el suelo) para la reja de la salida id
func gate_progress(exit_id: String) -> float:
	if held.has(exit_id):
		return 0.0
	if late.has(exit_id):
		return clampf(1.0 - float(late[exit_id]) / maxf(RULES.gate_drop_time, 0.01), 0.0, 1.0)
	return drop_progress()


## Un guardia ha reparado la caja de exit_id: si su reja estaba frenada, baja ahora
func on_box_repaired(exit_id: String) -> void:
	if not held.has(exit_id):
		return
	held.erase(exit_id)
	late[exit_id] = RULES.gate_drop_time
	_gate_noise(exit_id)


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
	if lockdown != null and lockdown.escapes_open() and not heist.stolen.is_empty():
		return GameManager.MatchState.THIEF_ESCAPED_PARTIAL
	return -1


func get_net_state() -> Dictionary:
	return {"left": snappedf(left, 0.01), "closed": closed, "held": held.keys(), "late": late}


func apply_net_state(state: Dictionary) -> void:
	left = float(state.get("left", left))
	closed = bool(state.get("closed", closed))
	if state.has("held"):
		held.clear()
		for exit_id: Variant in state["held"]:
			held[String(exit_id)] = true
	if state.has("late"):
		late = (state["late"] as Dictionary).duplicate()


## Las rejas en el suelo, ninguna salida abierta y el ladrón sin huir: dentro, encerrado; en el
## callejón, sin botín
func _close() -> void:
	if open_count() > 0:
		return  # R7c: con alguna salida abierta la partida sigue
	var thief: Node3D = get_tree().get_first_node_in_group(&"thief") as Node3D
	var outside: bool = false
	for node: Node in get_tree().get_nodes_in_group(&"heist_exits"):
		var zone: ExitZone3D = node as ExitZone3D
		if zone != null and zone.outdoor and thief != null and zone.overlaps_body(thief):
			outside = true
	GameManager.end_match(
		GameManager.MatchState.THIEF_NO_LOOT if outside else GameManager.MatchState.THIEF_LOCKED_IN
	)


func _tick_late(delta: float) -> void:
	for exit_id: String in late.keys():
		late[exit_id] = float(late[exit_id]) - delta
		if float(late[exit_id]) <= 0.0:
			late.erase(exit_id)
			_gate_noise(exit_id)  # toca el suelo
			if closed:
				_close()


## Al empezar a bajar, las rejas de las cajas saboteadas se quedan arriba
func _hold_sabotaged() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"gate_boxes"):
		var box: GateBox3D = node as GateBox3D
		if box != null and box.is_sabotaged():
			held[box.exit_id] = true


func _gate_noise(only: String = "") -> void:
	for node: Node in get_tree().get_nodes_in_group(&"heist_exits"):
		var zone: ExitZone3D = node as ExitZone3D
		if zone != null and not zone.outdoor and (only == "" or zone.exit_id == only):
			NoiseEmit.emit(
				zone.global_position, RULES.gate_radius, &"world", NoiseEmit.MECHANISM, null
			)
