## @file alarm_bell_84.gd
## Timbre de alarma (#111): cuando la alerta del golpe pasa a ALARMA, suena un timbre eléctrico
## de museo de los 80 durante BELL_SECONDS, igual para todos y en todo el museo (sin posición),
## y, cuando acaba el timbre, la música de la partida pasa a la de tensión. Cada máquina lo
## decide al ver cambiar el nivel replicado de AlertDirector, así que no hace falta ningún
## mensaje de red propio.
class_name AlarmBell84
extends Node

const BELL: AudioStream = preload("res://assets/audio/sfx/alarm/alarm_bell.ogg")
const BELL_SECONDS: float = 4.0
const BELL_DB: float = -6.0
const FADE_OUT: float = 0.3

var player: AudioStreamPlayer = null
var _was_alarm: bool = false


## Se cuelga del mapa; no hace nada en el servidor dedicado
func setup(map: Node) -> AlarmBell84:
	name = "AlarmBell"
	map.add_child(self)
	return self


func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.stream = BELL
	player.volume_db = BELL_DB
	player.bus = &"SFX"
	add_child(player)


func _process(_delta: float) -> void:
	var alert: AlertDirector = AlertDirector.of(get_tree())
	var alarm: bool = alert != null and alert.level == AlertDirector.Level.ALARM
	if alarm and not _was_alarm:
		ring()
	_was_alarm = alarm


## Suena BELL_SECONDS con un fundido final; la música de tensión entra después
func ring() -> void:
	player.volume_db = BELL_DB
	player.play()
	var tween: Tween = create_tween()
	tween.tween_interval(BELL_SECONDS - FADE_OUT)
	tween.tween_property(player, "volume_db", -60.0, FADE_OUT)
	tween.tween_callback(player.stop)
	tween.tween_callback(Music.play_alarm)
