## @file noise_audio_presenter.gd
## Presentador de audio de ruido posicional, vúmetro y chevron fuera de pantalla.
## Reproduce ruidos perceptibles por el jugador local con atenuación y pitch variable.
class_name NoiseAudioPresenter
extends Node

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _map: HeistMap3D = null
var _feedback: NoiseFeedbackProfile = null
var _mix: NoiseMix = null
var _listener: AudioListener3D = null


## Inicializa el presentador acústico vinculando el mapa, balance y mezcla
func setup(map: HeistMap3D, feedback: NoiseFeedbackProfile, mix: NoiseMix) -> void:
	_map = map
	_feedback = feedback
	_mix = mix

	if _listener == null:
		_listener = AudioListener3D.new()
		_listener.name = "NoiseAudioListener"
		add_child(_listener)

	if not SignalBus.noise_event_3d.is_connected(_on_noise_event_3d):
		SignalBus.noise_event_3d.connect(_on_noise_event_3d)

	if _map != null and _map.hud != null:
		var meter: NoiseMeter84 = _map.hud.get_noise_meter()
		if meter != null and _feedback != null:
			var fs: float = _feedback.meter_full_scale
			var ht: float = _feedback.meter_hold_time
			var ft: float = _feedback.meter_fall_time
			meter.configure(fs, ht, ft, 3.5)
		var is_thief_local: bool = _map.local_player == _map.thief and _map.thief != null
		_map.hud.set_noise_meter_visible(is_thief_local)


func _physics_process(_delta: float) -> void:
	if _map == null:
		return

	if _map.hud != null:
		var is_thief_local: bool = _map.local_player == _map.thief and _map.thief != null
		_map.hud.set_noise_meter_visible(is_thief_local)

	if _map.local_player != null and _listener != null:
		if _map.camera != null:
			var cam_basis: Basis = _map.camera.global_basis
			var player_pos: Vector3 = _map.local_player.global_position
			_listener.global_transform = Transform3D(cam_basis, player_pos)
		else:
			_listener.global_position = _map.local_player.global_position
		_listener.make_current()


func _on_noise_event_3d(
	pos: Vector3, radius: float, source_team: StringName, category: StringName, emitter: Node
) -> void:
	if radius <= 0.0 or _map == null:
		return

	var local: PlayerBase3D = _map.local_player
	if local == null:
		return

	if local == _map.thief and source_team == &"thief":
		if _map.hud != null and _map.hud.get_noise_meter() != null:
			_map.hud.get_noise_meter().push(radius)

	var m: float = 1.0
	if emitter is PlayerBase3D:
		var p_base: PlayerBase3D = emitter as PlayerBase3D
		if p_base.surface_detector != null:
			m = p_base.surface_detector.get_surface_noise_multiplier()

	var streams: Array[AudioStream] = []
	if _mix != null:
		streams = _mix.streams_for(category, m)

	var player: Node = null

	if emitter != null and emitter == local:
		if not streams.is_empty():
			var player_2d: AudioStreamPlayer = AudioStreamPlayer.new()
			if category == &"step":
				var full_scale: float = 10.0
				var base_vol: float = -22.0
				if _feedback != null:
					full_scale = _feedback.meter_full_scale
					base_vol = _feedback.own_step_volume_db
				var ratio: float = clampf(radius / full_scale, 0.05, 1.0)
				player_2d.volume_db = base_vol + linear_to_db(ratio)
			else:
				var cat_db: float = 0.0
				if _mix != null:
					cat_db = _mix.category_db(category)
				player_2d.volume_db = cat_db
			player = player_2d
	else:
		var hearing_mult: float = 1.5
		if _feedback != null:
			hearing_mult = _feedback.thief_hearing_mult
		if not PerceptionRules.noise_reaches(local, pos, radius, source_team, hearing_mult):
			return

		if not streams.is_empty():
			var player_3d: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
			player_3d.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
			player_3d.max_distance = 0.0

			var d: float = PerceptionRules.horizontal_distance(local.global_position, pos)
			var r_ef: float = PerceptionRules.effective_radius(
				local, radius, source_team, hearing_mult
			)
			var edge_floor: float = 0.2
			if _feedback != null:
				edge_floor = _feedback.audio_edge_floor
			var g: float = NoiseAudioRules.gain(d, r_ef, edge_floor)
			var cat_db: float = 0.0
			if _mix != null:
				cat_db = _mix.category_db(category)
			player_3d.volume_db = cat_db + linear_to_db(g)
			player = player_3d

		if category != &"step":
			if _map.camera != null and not _map.camera.is_position_in_frustum(pos):
				var role: StringName = &"other"
				if local == _map.thief and source_team == &"guard":
					role = &"guard"
				if _map.hud != null:
					var marker_time: float = 2.0
					if _feedback != null:
						marker_time = _feedback.offscreen_marker_time
					_map.hud.show_offscreen_noise(pos, marker_time, role)

	if player != null:
		var stream_idx: int = rng.randi_range(0, streams.size() - 1)
		player.set("stream", streams[stream_idx])
		var jitter: float = 0.06
		if _feedback != null:
			jitter = _feedback.pitch_jitter
		player.set("pitch_scale", 1.0 + rng.randf_range(-jitter, jitter))
		player.add_to_group(&"noise_audio")
		add_child(player)
		if player is Node3D:
			(player as Node3D).global_position = pos
		if player.has_signal("finished"):
			player.connect("finished", Callable(player, "queue_free"))
		player.call("play")
