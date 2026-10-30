## @file test_coin_alarm_audio.gd
## Sonido de la moneda por suelo, volumen mínimo audible y timbre de alarma (#111).
extends GutTest

const NOISE_MIX_PATH: String = "res://assets/audio/noise_mix.tres"
const NOISE_FEEDBACK_PATH: String = "res://data/balance/noise_feedback.tres"
const HUD_SCENE_PATH: String = "res://scenes/ui/hud_84.tscn"


func after_each() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"noise_audio"):
		node.queue_free()


func test_coin_streams_follow_the_floor() -> void:
	var mix: NoiseMix = load(NOISE_MIX_PATH) as NoiseMix
	assert_eq(mix.streams_for(&"coin", 0.5), mix.coin_soft, "Moqueta: coin_soft")
	assert_eq(mix.streams_for(&"coin", 1.0), mix.coin_wood, "Madera: coin_wood")
	assert_eq(mix.streams_for(&"coin", 1.5), mix.coin_hard, "Duro: coin_hard")
	assert_false(mix.coin_soft.is_empty() or mix.coin_wood.is_empty() or mix.coin_hard.is_empty())
	assert_almost_eq(mix.category_db(&"coin"), -8.0, 0.001, "coin_db vale -8")


func test_surface_mult_defaults_to_one() -> void:
	assert_eq(NoiseSurface.mult_for(null, &"coin", Vector3.ZERO, null), 1.0, "Moneda sin mundo")
	var actor: PlayerBase3D = autofree(ThiefController3D.new())
	assert_eq(
		NoiseSurface.mult_for(actor, &"step", Vector3.ZERO, null), 1.0, "Sin detector de suelo"
	)


func test_far_noise_never_drops_below_min_audible() -> void:
	var feedback: NoiseFeedbackProfile = load(NOISE_FEEDBACK_PATH) as NoiseFeedbackProfile
	var mix: NoiseMix = (load(NOISE_MIX_PATH) as NoiseMix).duplicate() as NoiseMix
	mix.impact_db = -60.0
	var map: HeistMap3D = autofree(HeistMap3D.new())
	var hud: HUD84 = (load(HUD_SCENE_PATH) as PackedScene).instantiate() as HUD84
	var thief: ThiefController3D = autofree(ThiefController3D.new())
	hud.name = "HUD84"
	thief.name = "Thief"
	map.add_child(hud)
	map.add_child(thief)
	add_child_autofree(map)
	map.set_physics_process(false)
	thief.set_physics_process(false)
	map.set_local_player(thief)
	thief.global_position = Vector3.ZERO
	map.noise_audio_presenter._mix = mix
	var other: Node3D = autofree(Node3D.new())
	add_child_autofree(other)
	SignalBus.noise_event_3d.emit(Vector3(0.0, 0.0, 4.9), 5.0, &"other", &"impact", other)
	var players: Array[Node] = get_tree().get_nodes_in_group(&"noise_audio")
	assert_eq(players.size(), 1, "Se oye en el borde del radio")
	var p3d: AudioStreamPlayer3D = players[0] as AudioStreamPlayer3D
	assert_almost_eq(p3d.volume_db, feedback.min_audible_db, 0.01, "No baja del mínimo audible")


func test_alarm_bell_rings_once_per_alarm() -> void:
	var alert: AlertDirector = AlertDirector.new()
	add_child_autofree(alert)
	alert.set_physics_process(false)
	var bell: AlarmBell84 = AlarmBell84.new()
	add_child_autofree(bell)
	await wait_process_frames(1)
	assert_false(bell.player.playing, "En calma no suena")
	alert.level = AlertDirector.Level.ALARM
	await wait_process_frames(1)
	assert_true(bell.player.playing, "Al saltar la alarma suena")
	bell.player.stop()
	alert.level = AlertDirector.Level.ALARM
	await wait_process_frames(2)
	assert_false(bell.player.playing, "Seguir en alarma no lo repite")
	alert.level = AlertDirector.Level.CALM
	await wait_process_frames(1)
	alert.level = AlertDirector.Level.ALARM
	await wait_process_frames(1)
	assert_true(bell.player.playing, "Tras volver a calma, suena de nuevo")
