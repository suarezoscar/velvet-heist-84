## @file match_recorder.gd
## Lleva la cuenta de la partida para el informe final (FEAT-041). Quien tiene la autoridad (el
## servidor o la partida sin red) mira cada fotograma cuándo empieza cada guardia a ver al
## ladrón (perderlo menos de SEEN_GAP s no cuenta otra vez) y cuándo da una cabezada; lo demás
## lo cuentan sus sistemas (HeistDirector.stolen_how, AlertDirector.alarm_triggers y alarm_by,
## los golpes y la captura en metadatos del guardia) y ScoreEvents (#123: despistes, walkie,
## falsificaciones y robos cerca). Ver al ladrón incluye la cámara en pantalla de quien la mira.
## Al acabar monta el informe y lo reparte con el resto del estado (grupo net_state); mientras,
## actualiza la puntuación en vivo de cada jugador (LiveScore, una por rol).
class_name MatchRecorder
extends Node

const HITS_META: StringName = &"match_baton_hits"
const CAPTURE_META: StringName = &"match_capture"
const HEIST_RULES: HeistRules = preload("res://data/balance/heist_rules.tres")
## Nombre de un guardia que lleva el ordenador
const AI_NAME: String = "El ordenador"
## Segundos sin ver al ladrón para que volver a verlo cuente como otra vez
const SEEN_GAP: float = 2.0
## Cada cuánto se recalcula la puntuación en vivo
const LIVE_TICK: float = 0.25
const HOW_TEXT: Dictionary = {
	&"dial": "abriendo el dial",
	&"brute": "a lo bruto",
	&"swap": "con el cambiazo",
	&"bridge": "puenteando el sensor",
}

## Informe de la partida terminada ({} mientras se juega)
var report: Dictionary = {}
## Puntos nuevos de #123
var events: ScoreEvents = ScoreEvents.new()
## Por guardia (nombre del nodo): veces que empezó a verlo, último instante en que lo vio,
## cabezadas y si estaba dando una
var _seen: Dictionary = {}
var _last_seen: Dictionary = {}
var _naps: Dictionary = {}
var _nodding: Dictionary = {}
var _time: float = 0.0
var _live_timer: float = 0.0


func _ready() -> void:
	name = "MatchRecorder"
	add_to_group(&"net_state")
	for role: StringName in NetConfig.ROLES:
		add_child(LiveScore.create(role))


## El registro del mapa actual (null si no hay)
static func of(tree: SceneTree) -> MatchRecorder:
	for node: Node in tree.get_nodes_in_group(&"net_state"):
		if node is MatchRecorder:
			return node as MatchRecorder
	return null


func _physics_process(delta: float) -> void:
	if not GameManager.is_simulating():
		return
	if GameManager.is_match_over():
		if report.is_empty():
			report = build_report()
		return
	_time += delta
	var camera: bool = SecurityCamera3D.any_detects(self)
	var seeing: Dictionary = {}
	var hits: int = 0
	for guard: GuardController3D in _guards():
		var sees: bool = guard.is_perceiving_thief or (camera and GuardSleep.sees_cameras(guard))
		if sees:
			seeing[String(guard.name)] = true
		hits += int(guard.get_meta(HITS_META, 0))
		track(String(guard.name), sees, GuardSleep.sees_nothing(guard), _time)
	var thief: Node3D = get_tree().get_first_node_in_group(&"thief") as Node3D
	if thief != null:
		events.tick(seeing, thief.global_position, hits, _time)
	_live_timer -= delta
	if _live_timer <= 0.0:
		_live_timer = LIVE_TICK
		_publish_live()


## Walkie de un guardia (HeistActions, en el servidor)
static func note_ping(tree: SceneTree, guard: GuardController3D, pos: Vector3) -> void:
	var recorder: MatchRecorder = of(tree)
	if recorder != null:
		recorder.events.on_ping(String(guard.name), pos, recorder._time)


## Un guardia descubre una falsificación examinándola (TargetPiece3D, en el servidor): suma a
## sus puntos y, si es el último rastro que hace saltar la alarma, la alarma es suya
static func note_examined(tree: SceneTree, guard: Node, piece: TargetPiece3D) -> void:
	if guard == null:
		return
	var alert: AlertDirector = AlertDirector.of(tree)
	if alert != null:
		alert.trace_by[piece] = String(guard.name)
	var recorder: MatchRecorder = of(tree)
	if recorder != null:
		recorder.events.on_examined(String(guard.name))


## Robo en silencio de una pieza del encargo en pos (HeistDirector, en el servidor)
static func note_silent_theft(tree: SceneTree, pos: Vector3) -> void:
	var recorder: MatchRecorder = of(tree)
	if recorder != null:
		recorder.events.on_silent_theft(pos, recorder._guards())


func _publish_live() -> void:
	var live: Dictionary = build_report()
	var thief_score: LiveScore = LiveScore.of(get_tree(), NetConfig.ROLES[0])
	if thief_score != null:
		thief_score.update(MatchScore.live(MatchScore.thief(live["thief"])))
	var index: int = 0
	for guard: GuardController3D in _guards():
		var score: LiveScore = LiveScore.of(get_tree(), LiveScore.guard_role(guard))
		if score != null:
			score.update(MatchScore.live(MatchScore.guard(live["guards"][index])))
		index += 1


## Anota lo que hace el guardia key en el instante now: si ve al ladrón (cuenta cuando empieza
## a verlo tras SEEN_GAP s sin verlo) y si está dando una cabezada (cuenta cuando empieza)
func track(key: String, seeing: bool, nodding: bool, now: float) -> void:
	if seeing:
		if now - float(_last_seen.get(key, -INF)) > SEEN_GAP:
			_seen[key] = int(_seen.get(key, 0)) + 1
		_last_seen[key] = now
	if nodding and not bool(_nodding.get(key, false)):
		_naps[key] = int(_naps.get(key, 0)) + 1
	_nodding[key] = nodding


func get_net_state() -> Dictionary:
	return {"report": report} if not report.is_empty() else {}


func apply_net_state(state: Dictionary) -> void:
	if state.has("report"):
		report = state["report"]


## El informe con lo que ha pasado hasta ahora
func build_report() -> Dictionary:
	var guards: Array[Dictionary] = []
	var protected_pieces: int = _protected_pieces()
	var locked_in: bool = GameManager.current_state == GameManager.MatchState.THIEF_LOCKED_IN
	var alert: AlertDirector = AlertDirector.of(get_tree())
	var seen_total: int = 0
	var hits_total: int = 0
	var all_guards: Array[GuardController3D] = _guards()
	for guard: GuardController3D in all_guards:
		var key: String = String(guard.name)
		var seen: int = int(_seen.get(key, 0))
		seen_total += seen
		var alarm: bool = alert != null and alert.alarm_by == key
		if alarm and alert.alarm_sight and seen > 0:
			seen -= 1  # la vez que dio la alarma cuenta como alarma, no como «verlo»
		var hits: int = int(guard.get_meta(HITS_META, 0))
		hits_total += hits
		var entry: Dictionary = {
			"name": _guard_name(guards.size() + 1),
			"alarm": alarm,
			"seen": seen,
			"examined": int(events.examined.get(key, 0)),
			"walkie": int(events.walkie.get(key, 0)),
			"near_theft": int(events.near_theft.get(key, 0)),
			"hits": hits,
			"capture": bool(guard.get_meta(CAPTURE_META, false)),
			"naps": int(_naps.get(key, 0)),
			"repairs": int(guard.get_meta(GateBox3D.REPAIRS_META, 0)),
			"protected": protected_pieces,
			"k": _contract_size(),
			"guards": all_guards.size(),
			"locked_in": locked_in,
		}
		guards.append(entry)
	var thief: Dictionary = _thief_report(seen_total)
	thief["hits_taken"] = hits_total
	thief["guards"] = all_guards.size()
	return {"thief": thief, "guards": guards}


func _contract_size() -> int:
	return GameManager.heist.targets.size() if GameManager.heist != null else 0


## Piezas del encargo que siguen en su sitio (una falsificación cuenta como robada)
func _protected_pieces() -> int:
	var heist: HeistDirector = GameManager.heist
	if heist == null:
		return 0
	var left: int = 0
	for piece_id: StringName in heist.targets:
		if not heist.stolen.has(piece_id):
			left += 1
	return left


func _thief_report(seen: int) -> Dictionary:
	var pieces: Array[Dictionary] = []
	var heist: HeistDirector = GameManager.heist
	var coins_used: int = 0
	if heist != null:
		coins_used = HEIST_RULES.coins - heist.coins_left
		for piece_id: StringName in heist.targets:
			var piece: TargetPiece3D = heist.piece(piece_id)
			var how: StringName = heist.stolen_how.get(piece_id, &"")
			(
				pieces
				. append(
					{
						"name": piece.piece_name if piece != null else String(piece_id),
						"stolen": heist.stolen.has(piece_id),
						"clean":
						heist.stolen.has(piece_id) and piece != null and not piece.discovered,
						"how": HOW_TEXT.get(how, ""),
					}
				)
			)
	var alert: AlertDirector = AlertDirector.of(get_tree())
	var escaped: bool = GameManager.current_state == GameManager.MatchState.THIEF_ESCAPED
	var partial: bool = GameManager.current_state == GameManager.MatchState.THIEF_ESCAPED_PARTIAL
	var lockdown: HeistLockdown = HeistLockdown.of(get_tree())
	var clean: int = pieces.filter(func(p: Dictionary) -> bool: return bool(p["clean"])).size()
	return {
		"name": _thief_name(),
		"clean": clean,
		"lost": events.lost,
		"fast": _fast_seconds(lockdown, escaped or partial),
		"sabotaged": _sabotaged_boxes(),
		"sabotage_escape": lockdown != null and lockdown.sabotage_escape,
		"pieces": pieces,
		"alarms": alert.alarm_triggers if alert != null else 0,
		"coins": coins_used,
		"seen": seen,
		"escaped": escaped,
		"partial": partial,
		"time": GameManager.match_duration_seconds - GameManager.match_timer,
	}


## Segundos enteros de cuenta atrás que le sobraban al huir (0 sin cuenta atrás o tras el cierre)
func _fast_seconds(lockdown: HeistLockdown, fled: bool) -> int:
	if not fled or lockdown == null or lockdown.left < 0.0 or lockdown.closed:
		return 0
	return floori(lockdown.left)


## Cajas de reja que siguen saboteadas al acabar
func _sabotaged_boxes() -> int:
	var count: int = 0
	for node: Node in get_tree().get_nodes_in_group(&"gate_boxes"):
		var box: GateBox3D = node as GateBox3D
		if box != null and box.is_sabotaged():
			count += 1
	return count


func _guards() -> Array[GuardController3D]:
	var found: Array[GuardController3D] = []
	for node: Node in get_tree().get_nodes_in_group(&"guards"):
		if node is GuardController3D:
			found.append(node as GuardController3D)
	return found


func _thief_name() -> String:
	if NetManager.is_online():
		return _player_name(NetManagerNode.ROLE_THIEF, "Ladrón")
	var own: String = GameSettings.load_saved().player_name
	return own if not own.is_empty() else "Tú"


func _guard_name(number: int) -> String:
	if not NetManager.is_online():
		return AI_NAME
	return _player_name(StringName("guard_%d" % number), AI_NAME)


func _player_name(role: StringName, fallback: String) -> String:
	var peer: int = NetManager.get_peer_id_for_role(role)
	if peer == 0:
		return fallback
	var info: Dictionary = NetManager.get_connected_players().get(peer, {})
	var player_name: String = String(info.get("name", ""))
	return player_name if not player_name.is_empty() else fallback
