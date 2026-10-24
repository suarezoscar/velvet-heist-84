## @file local_view_presenter.gd
## Presentador de la vista local del jugador (indicador de exposición, silueta O2 e
## imágenes CCTV). Gestiona la exposición del ladrón, el marcador LastSeenMarker3D del
## guardia local y las imágenes de las cámaras mientras mira los monitores (M2).
class_name LocalViewPresenter
extends Node

var _map: HeistMap3D = null
var _last_seen_marker: LastSeenMarker3D = null
var _previous_local_player: PlayerBase3D = null
var _was_perceiving_thief: bool = false


## Inicializa el presentador de vista local asociándolo a la escena de mapa
func setup(map: HeistMap3D) -> void:
	_map = map
	if _last_seen_marker == null:
		_last_seen_marker = LastSeenMarker3D.new()
		_last_seen_marker.name = "LastSeenMarker3D"
		add_child(_last_seen_marker)


func _physics_process(_delta: float) -> void:
	if _map == null:
		return

	if _map.local_player != _previous_local_player:
		_previous_local_player = _map.local_player
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
