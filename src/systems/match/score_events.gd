## @file score_events.gd
## Lo que cuenta MatchRecorder para los puntos nuevos de #123 (heist.md R11), en el servidor o la
## partida sin red. Las claves de los guardias son el nombre de su nodo.
## - despistes: tras verlo alguien, RULES.lose_them_time s sin que nadie lo vea ni le pegue;
## - walkie: una marca acierta si en RULES.walkie_hit_window s otro guardia *empieza* a verlo
##   (no lo veía en el instante anterior) a menos de RULES.walkie_hit_radius m (en horizontal)
##   de ella; cada marca, una vez. Así no cuenta marcar a quien el compañero ya está viendo;
## - falsificaciones descubiertas y robos en silencio cerca de cada guardia (sin muros).
class_name ScoreEvents
extends RefCounted

const RULES: ScoreRules = preload("res://data/balance/score_rules.tres")
## Altura del punto de la pieza al que mira el guardia (la misma que la de los rastros)
const PIECE_HEIGHT: float = 1.1

## Veces que lo despistó
var lost: int = 0
## Por guardia: marcas que acertaron, falsificaciones descubiertas y robos cerca
var walkie: Dictionary = {}
var examined: Dictionary = {}
var near_theft: Dictionary = {}
## Marcas abiertas: [{"by": String, "pos": Vector3, "t": float}]
var _pings: Array[Dictionary] = []
var _chasing: bool = false
var _last_contact: float = -INF
var _hits: int = 0
## Quién lo veía en el instante anterior (para el walkie: empezar a verlo)
var _prev_seeing: Dictionary = {}


## Un instante de la partida: seeing, {clave: true} de los guardias que lo ven ahora; thief_pos,
## dónde está; hits, golpes recibidos hasta ahora
func tick(seeing: Dictionary, thief_pos: Vector3, hits: int, now: float) -> void:
	if not seeing.is_empty() or (_chasing and hits != _hits):  # un golpe solo alarga la huida
		_chasing = true
		_last_contact = now
	elif _chasing and now - _last_contact >= RULES.lose_them_time:
		_chasing = false
		lost += 1
	_hits = hits
	_check_pings(seeing, thief_pos, now)
	_prev_seeing = seeing.duplicate()


## Un guardia marca un punto con el walkie
func on_ping(by: String, pos: Vector3, now: float) -> void:
	_pings.append({"by": by, "pos": pos, "t": now})


## Un guardia descubre una falsificación examinándola
func on_examined(by: String) -> void:
	examined[by] = int(examined.get(by, 0)) + 1


## Robo en silencio en pos: −30 a cada guardia a menos de RULES.near_theft_radius m que tenga
## la pieza sin muros de por medio
func on_silent_theft(pos: Vector3, guards: Array[GuardController3D]) -> void:
	var target: Vector3 = pos + Vector3.UP * PIECE_HEIGHT
	for guard: GuardController3D in guards:
		var flat: Vector3 = guard.global_position - pos
		flat.y = 0.0
		if flat.length() > RULES.near_theft_radius:
			continue
		var space: PhysicsDirectSpaceState3D = guard.get_world_3d().direct_space_state
		if VisionLogic.wall_free(space, VisionLogic.eye(guard), target):
			var key: String = String(guard.name)
			near_theft[key] = int(near_theft.get(key, 0)) + 1


func _check_pings(seeing: Dictionary, thief_pos: Vector3, now: float) -> void:
	var open: Array[Dictionary] = []
	for ping: Dictionary in _pings:
		if now - float(ping["t"]) > RULES.walkie_hit_window:
			continue
		var by: String = ping["by"]
		var flat: Vector3 = thief_pos - (ping["pos"] as Vector3)
		flat.y = 0.0
		var teammate: bool = seeing.keys().any(
			func(key: String) -> bool: return key != by and not _prev_seeing.has(key)
		)
		if teammate and flat.length() <= RULES.walkie_hit_radius:
			walkie[by] = int(walkie.get(by, 0)) + 1
			continue
		open.append(ping)
	_pings = open
