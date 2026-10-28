## @file music_player_84.gd
## Música de fondo (FEAT-030). Autoload Music: en el menú suena «Coffee Black» y en la partida
## «Espionage», en bucle, bajita y en el bus Music (su volumen está en Opciones). Al cambiar de
## escena funde de una pista a otra. No suena en el servidor dedicado.
class_name MusicPlayer84
extends Node

const MENU_TRACK: AudioStream = preload("res://assets/audio/music/menu_coffee_black.ogg")
const HEIST_TRACK: AudioStream = preload("res://assets/audio/music/heist_espionage.ogg")
## Volumen de base de cada pista (dB), por debajo de los efectos: es música de fondo
const MENU_DB: float = -10.0
const HEIST_DB: float = -16.0
const SILENT_DB: float = -60.0
const FADE_TIME: float = 1.5

var player: AudioStreamPlayer = null
var current: AudioStream = null
var _tween: Tween = null


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	player = AudioStreamPlayer.new()
	player.name = "MusicStream"
	player.bus = &"Music"
	add_child(player)
	get_tree().scene_changed.connect(_on_scene_changed)
	_on_scene_changed.call_deferred()


## Pista y volumen que tocan para una escena: la de partida en los mapas, la del menú en el resto
static func track_for(scene: Node) -> Array:
	if scene is HeistMap3D:
		return [HEIST_TRACK, HEIST_DB]
	return [MENU_TRACK, MENU_DB]


func play(track: AudioStream, volume_db: float) -> void:
	if player == null or track == current:
		return
	current = track
	if track is AudioStreamOggVorbis:
		(track as AudioStreamOggVorbis).loop = true
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	if player.playing:
		_tween.tween_property(player, "volume_db", SILENT_DB, FADE_TIME * 0.5)
	_tween.tween_callback(
		func() -> void:
			player.stream = track
			player.volume_db = SILENT_DB
			player.play()
	)
	_tween.tween_property(player, "volume_db", volume_db, FADE_TIME)


func _on_scene_changed() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var choice: Array = track_for(scene)
	play(choice[0] as AudioStream, float(choice[1]))
