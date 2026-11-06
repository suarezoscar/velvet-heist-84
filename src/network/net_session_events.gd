## @file net_session_events.gd
## Eventos del mundo que NetSessionServer reparte a los peers listos: ruido, moneda en vuelo
## y traza de estados del mundo (FEAT-014, FEAT-038).
class_name NetSessionEvents
extends RefCounted

const NOISE_FEEDBACK: NoiseFeedbackProfile = preload("res://data/balance/noise_feedback.tres")


## Reparte un ruido a los peers que lo oyen (cada uno según su bando y su oído)
static func send_noise(
	session: NetSession,
	ready_peers: Dictionary,
	pos: Vector3,
	radius: float,
	team: StringName,
	category: StringName,
	emitter: Node
) -> void:
	if ready_peers.is_empty():
		return
	var emitter_role: StringName = session.role_for_actor(emitter)
	var surface_mult: float = NoiseSurface.mult_for(
		emitter, category, pos, session.get_viewport().find_world_3d()
	)
	for peer: int in ready_peers:
		var listener: PlayerBase3D = session.actor_for_role(NetManager.get_role_for_peer(peer))
		var reaches: bool = PerceptionRules.noise_reaches(
			listener, pos, radius, team, NOISE_FEEDBACK.thief_hearing_mult
		)
		if not reaches:
			continue
		session.send_noise(peer, pos, radius, team, category, emitter_role, surface_mult)
		NetTestHooks.log_event({"event": "noise", "peer": peer})


## La moneda en vuelo, solo a quien la ve y solo el tramo que ve (FEAT-038; el ruido va
## aparte, al caer)
static func send_coin(
	session: NetSession,
	ready_peers: Dictionary,
	from: Vector3,
	landing: Vector3,
	flight_time: float
) -> void:
	for peer: int in ready_peers:
		var viewer: PlayerBase3D = session.actor_for_role(NetManager.get_role_for_peer(peer))
		if viewer == null:
			continue
		var view: Dictionary = CoinFlightPresenter.view_for(viewer, from, landing, flight_time)
		if view.is_empty():
			continue
		# Recortada: quien no ve la salida recibe el tramo cuando entra en su vista
		var send: Callable = session.send_coin.bind(peer, view["from"], landing, view["flight"])
		session.get_tree().create_timer(float(view.get("delay", 0.0))).timeout.connect(send)


## Anota en la traza de pruebas qué rutas del mundo se han enviado a un peer
static func log_world(peer: int, changes: Dictionary) -> void:
	NetTestHooks.log_event({"event": "world", "peer": peer, "paths": changes.keys()})


## Deja quieto al actor de un peer que se va: sin sprint ni sigilo, sin vigilar, sin linterna
## ni minijuego en curso, y marcado como ausente si era guardia (#158, #119)
static func release_actor(session: NetSession, role: StringName) -> void:
	var actor: PlayerBase3D = session.actor_for_role(role)
	if actor == null:
		return
	if actor.has_method(&"stop_watching"):
		actor.call(&"stop_watching")  # guardia o ladrón sentado ante los monitores
	StealMinigame.cancel_for(actor)  # #119: sin quien lo juegue
	if actor is GuardController3D:
		(actor as GuardController3D).apply_flashlight_state(false)  # sin quien la sostenga
		actor.set_meta(MatchRecorder.LEFT_META, true)
	actor.apply_input(
		{"movement_vector": Vector2.ZERO, "is_sprinting": false, "is_sneaking": false}
	)
