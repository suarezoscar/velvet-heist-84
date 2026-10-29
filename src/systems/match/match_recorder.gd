## @file match_recorder.gd
## Lleva la cuenta de la partida para el informe final (FEAT-041). Quien tiene la autoridad (el
## servidor o la partida sin red) mira cada fotograma cuándo empieza cada guardia a ver al
## ladrón (perderlo menos de SEEN_GAP s no cuenta otra vez) y cuándo da una cabezada; lo demás
## lo cuentan sus sistemas (HeistDirector.stolen_how, AlertDirector.alarm_triggers,
## GuardRound.punched, los golpes y la captura en metadatos del guardia). Al acabar monta el
## informe y lo reparte con el resto del estado (grupo net_state); antes no manda nada.
class_name MatchRecorder
extends Node

const HITS_META: StringName = &"match_baton_hits"
const CAPTURE_META: StringName = &"match_capture"
const HEIST_RULES: HeistRules = preload("res://data/balance/heist_rules.tres")
## Nombre de un guardia que lleva el ordenador
const AI_NAME: String = "El ordenador"
## Segundos sin ver al ladrón para que volver a verlo cuente como otra vez
const SEEN_GAP: float = 2.0
const HOW_TEXT: Dictionary = {
	&"dial": "abriendo el dial",
	&"brute": "a lo bruto",
	&"swap": "con el cambiazo",
	&"power": "con la corriente cortada",
}

## Informe de la partida terminada ({} mientras se juega)
var report: Dictionary = {}
## Por guardia (nombre del nodo): veces que empezó a verlo, último instante en que lo vio,
## cabezadas y si estaba dando una
var _seen: Dictionary = {}
var _last_seen: Dictionary = {}
var _naps: Dictionary = {}
var _nodding: Dictionary = {}
var _time: float = 0.0


func _ready() -> void:
	name = "MatchRecorder"
	add_to_group(&"net_state")


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
	for guard: GuardController3D in _guards():
		track(String(guard.name), guard.is_perceiving_thief, GuardSleep.sees_nothing(guard), _time)


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
	var seen_total: int = 0
	var index: int = 0
	for guard: GuardController3D in _guards():
		index += 1
		var round_node: GuardRound = guard.get_node_or_null("Round") as GuardRound
		var seen: int = int(_seen.get(String(guard.name), 0))
		seen_total += seen
		(
			guards
			. append(
				{
					"name": _guard_name(index),
					"clocks": round_node.punched if round_node != null else 0,
					"faults": round_node.faults if round_node != null else 0,
					"seen": seen,
					"hits": int(guard.get_meta(HITS_META, 0)),
					"capture": bool(guard.get_meta(CAPTURE_META, false)),
					"naps": int(_naps.get(String(guard.name), 0)),
				}
			)
		)
	return {"thief": _thief_report(seen_total), "guards": guards}


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
						"how": HOW_TEXT.get(how, ""),
					}
				)
			)
	var alert: AlertDirector = AlertDirector.of(get_tree())
	var escaped: bool = GameManager.current_state == GameManager.MatchState.THIEF_ESCAPED
	return {
		"name": _thief_name(),
		"pieces": pieces,
		"alarms": alert.alarm_triggers if alert != null else 0,
		"coins": coins_used,
		"seen": seen,
		"escaped": escaped,
		"time": GameManager.match_duration_seconds - GameManager.match_timer,
	}


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
