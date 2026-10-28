## @file local_view_presenter.gd
## Presentador de la vista local del jugador (indicador de exposición, silueta O2, imágenes
## CCTV y marcas de bando). Gestiona la exposición del ladrón, el marcador LastSeenMarker3D del
## guardia local, las imágenes de las cámaras mientras mira los monitores (M2) y la marca de
## bando de cada personaje, con la del jugador local resaltada (FEAT-027).
class_name LocalViewPresenter
extends Node

var _map: HeistMap3D = null
var _last_seen_marker: LastSeenMarker3D = null
var _previous_local_player: PlayerBase3D = null
var _was_perceiving_thief: bool = false
var _markers: Dictionary = {}


## Inicializa el presentador de vista local asociándolo a la escena de mapa
func setup(map: HeistMap3D) -> void:
	_map = map
	if _last_seen_marker == null:
		_last_seen_marker = LastSeenMarker3D.new()
		_last_seen_marker.name = "LastSeenMarker3D"
		add_child(_last_seen_marker)
	if not NetManager.is_dedicated_server:
		_attach_markers()


func _physics_process(_delta: float) -> void:
	if _map == null:
		return

	if _map.local_player != _previous_local_player:
		_previous_local_player = _map.local_player
		for actor: PlayerBase3D in _markers:
			(_markers[actor] as TeamMarker3D).set_local(actor == _map.local_player)
		_was_perceiving_thief = false
		if _last_seen_marker != null:
			_last_seen_marker.hide_marker()

	# 1. Exposición del ladrón local
	if _map.local_player != null and _map.local_player == _map.thief and _map.thief != null:
		var lamps: Array[Lamp3D] = []
		for node: Node in get_tree().get_nodes_in_group(&"lamps"):
			if node is Lamp3D:
				lamps.append(node as Lamp3D)
		var exposure: StringName = ThiefExposure.compute(_map.thief, _map.guards, lamps)
		if _map.hud != null:
			_map.hud.set_exposure(exposure)
	else:
		if _map.hud != null:
			_map.hud.set_exposure(&"")

	# 2. Silueta O2 para el guardia local
	if _map.local_player is GuardController3D:
		var guard: GuardController3D = _map.local_player as GuardController3D
		var is_perceiving: bool = guard.is_perceiving_thief
		if _was_perceiving_thief and not is_perceiving and guard.last_seen_time_left > 0.0:
			if _last_seen_marker != null:
				_last_seen_marker.show_at(guard.last_seen_position, guard.last_seen_time_left)
		elif guard.last_seen_time_left <= 0.0:
			if _last_seen_marker != null and _last_seen_marker.visible:
				_last_seen_marker.hide_marker()
		_was_perceiving_thief = is_perceiving
	else:
		_was_perceiving_thief = false
		if _last_seen_marker != null and _last_seen_marker.visible:
			_last_seen_marker.hide_marker()

	# 3. Imágenes CCTV del guardia sentado ante los monitores
	_update_cctv_feeds()
	# 4. Panel del dial si el ladrón local está abriendo una caja fuerte
	if _map.hud != null and _map.hud.safe_dial != null:
		_map.hud.safe_dial.bind(_cracking_safe())


## Caja fuerte que el ladrón local está abriendo (en red, la que llega con el estado privado)
func _cracking_safe() -> SafeBox3D:
	if not (_map.local_player is ThiefController3D):
		return null
	for node: Node in get_tree().get_nodes_in_group(&"net_state"):
		var safe: SafeBox3D = node as SafeBox3D
		if safe != null and safe.current_state == SafeBox3D.SafeState.CRACKING:
			return safe
	return null


func _update_cctv_feeds() -> void:
	var hud: HUD84 = _map.hud
	if hud == null or hud.cctv_feeds == null:
		return
	var guard: GuardController3D = _map.local_player as GuardController3D
	var watching: bool = guard != null and guard.is_watching_monitors()
	if watching and hud.cctv_feeds.panel_count() == 0:
		var cameras: Array[SecurityCamera3D] = []
		cameras.assign(get_tree().get_nodes_in_group(&"security_camera"))
		hud.cctv_feeds.setup(cameras)
	hud.cctv_feeds.visible = watching
	if hud.round_sheet != null:
		var below_feeds: bool = watching and hud.cctv_feeds.panel_count() > 0
		hud.round_sheet.offset_top = (
			hud.cctv_feeds.feed_rect(0).end.y + 12.0 if below_feeds else RoundSheet84.TOP
		)


func _attach_markers() -> void:
	for actor: PlayerBase3D in _map.get_actors():
		var is_thief: bool = actor == _map.thief
		var color: Color = TeamMarker3D.THIEF_COLOR if is_thief else TeamMarker3D.GUARD_COLOR
		var tag: String = "" if is_thief else str(_map.guards.find(actor as GuardController3D) + 1)
		var marker: TeamMarker3D = TeamMarker3D.attach(actor, color, tag)
		if marker != null:
			_markers[actor] = marker
