## Componente modular que conecta el modo de movimiento de PlayerBase3D
## con las animaciones de los modelos esqueléticos (Crypto y SWAT).
class_name CharacterAnimator3D
extends Node

## Pose de reposo provisional: fotograma neutro (piernas juntas) de una animación de paso.
const IDLE_STAND_POSE: StringName = &"idle_stand"
const IDLE_CROUCH_POSE: StringName = &"idle_crouch"
const POSES: Dictionary = {
	IDLE_STAND_POSE: [&"walk", 0.0],
	IDLE_CROUCH_POSE: [&"crouch_walk", 0.0],
}

## Animaciones que deben repetirse en bucle
const LOOPED_ANIMATIONS: Array[StringName] = [
	&"walk",
	&"sneak_walk",
	&"crouch_walk",
]

## Velocidad (m/s) a la que cada animación de paso encaja sin patinar
const ANIMATION_REFERENCE_SPEED: Dictionary = {
	&"walk": 1.6,
	&"sneak_walk": 1.2,
	&"crouch_walk": 1.2,
}
## Duración (s) de cada ciclo de paso de Mixamo (dos pisadas por ciclo), medida en los .glb del
## ladrón y del guardia, que comparten animaciones. Los pasos suenan a este ritmo (#109)
const STEP_CYCLE_LENGTH: Dictionary = {
	&"walk": 1.0667,
	&"sneak_walk": 1.10,
	&"crouch_walk": 1.0667,
}
const MIN_PLAYBACK_SPEED: float = 0.6
const MAX_PLAYBACK_SPEED: float = 3.0

## Velocidad horizontal mínima (m/s) para considerar que el personaje camina
const MOVING_SPEED_THRESHOLD: float = 0.15
const BLEND_TIME: float = 0.2
const ACTION_BLEND_TIME: float = 0.15
const LIBRARY_PREPARED_META: StringName = &"vh84_prepared"

## Referencia al AnimationPlayer del modelo 3D
@export var animation_player: AnimationPlayer

## Nodo padre esperado (PlayerBase3D)
var _player: PlayerBase3D = null

## Estado de animación bloqueada (por ejemplo, acción única)
var _is_action_playing: bool = false

## Animación o pose lógica activa (puede ser una pose de POSES)
var _current_state: StringName = &""


func _ready() -> void:
	_player = get_parent() as PlayerBase3D
	if not animation_player and _player != null:
		animation_player = _player.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation_player != null:
		_prepare_library(animation_player)


func _process(_delta: float) -> void:
	if not _player or not animation_player or _is_action_playing:
		return

	var horizontal_speed: float = Vector2(_player.velocity.x, _player.velocity.z).length()
	var state: StringName = resolve_animation_name(_player.get_move_mode(), horizontal_speed)
	_apply_state(state, horizontal_speed)


## Activa bucles en las animaciones soportadas. Se marca cada recurso para tratarlo una sola vez.
static func _prepare_library(player: AnimationPlayer) -> void:
	for anim_name: StringName in player.get_animation_list():
		var anim: Animation = player.get_animation(anim_name)
		if anim.has_meta(LIBRARY_PREPARED_META):
			continue
		anim.set_meta(LIBRARY_PREPARED_META, true)
		if LOOPED_ANIMATIONS.has(anim_name):
			anim.loop_mode = Animation.LOOP_LINEAR


## Resuelve la animación (o pose de reposo) según el modo de movimiento y la velocidad
func resolve_animation_name(mode: MovementProfile.Mode, horizontal_speed: float) -> StringName:
	var is_moving: bool = horizontal_speed >= MOVING_SPEED_THRESHOLD
	if not is_moving:
		if mode == MovementProfile.Mode.CROUCH:
			return IDLE_CROUCH_POSE
		return IDLE_STAND_POSE

	match mode:
		MovementProfile.Mode.SNEAK:
			return &"sneak_walk"
		MovementProfile.Mode.CROUCH:
			return &"crouch_walk"
		MovementProfile.Mode.WALK, MovementProfile.Mode.SPRINT:
			return &"walk"
		_:
			return &"walk"


## Reproduce una animación de acción única (golpe, apertura de caja, etc.)
func play_action(action_name: StringName) -> void:
	if not animation_player or not animation_player.has_animation(action_name):
		return
	_is_action_playing = true
	_current_state = action_name
	animation_player.play(action_name, ACTION_BLEND_TIME)
	if not animation_player.animation_finished.is_connected(_on_action_finished):
		animation_player.animation_finished.connect(_on_action_finished, CONNECT_ONE_SHOT)


func _on_action_finished(_anim_name: StringName) -> void:
	_is_action_playing = false
	_current_state = &""


func _apply_state(state: StringName, horizontal_speed: float) -> void:
	if state == &"" or animation_player == null:
		return
	if POSES.has(state):
		if _current_state != state:
			var pose: Array = POSES[state]
			if animation_player.has_animation(pose[0]):
				animation_player.play(pose[0], BLEND_TIME, 0.0)
				animation_player.seek(pose[1], true)
		_current_state = state
		return

	if not animation_player.has_animation(state):
		return
	if _current_state != state:
		animation_player.play(state, BLEND_TIME)
		_current_state = state
	animation_player.speed_scale = playback_speed(state, horizontal_speed)


## Segundos entre pasos para que el sonido caiga con cada pie: el ciclo de la animación del modo,
## a la velocidad a la que se reproduce, entre sus dos pisadas. Lo usa la simulación (también en
## el servidor, sin animación), así que no lee el AnimationPlayer
static func step_interval(mode: MovementProfile.Mode, horizontal_speed: float) -> float:
	var anim: StringName = &"walk"
	if mode == MovementProfile.Mode.CROUCH:
		anim = &"crouch_walk"
	elif mode == MovementProfile.Mode.SNEAK:
		anim = &"sneak_walk"
	return float(STEP_CYCLE_LENGTH[anim]) / (2.0 * playback_speed(anim, horizontal_speed))


static func playback_speed(anim_name: StringName, horizontal_speed: float) -> float:
	if not ANIMATION_REFERENCE_SPEED.has(anim_name):
		return 1.0
	var ratio: float = horizontal_speed / float(ANIMATION_REFERENCE_SPEED[anim_name])
	return clampf(ratio, MIN_PLAYBACK_SPEED, MAX_PLAYBACK_SPEED)
