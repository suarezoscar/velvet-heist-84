## @file character_animator_3d.gd
## Componente modular que conecta el estado físico y la postura de PlayerBase3D
## con las animaciones de los modelos esqueléticos definitivos (Crypto y SWAT).
## Los .glb de Mixamo llegan sin bucle, sin pose de reposo y con desplazamiento de cadera
## en las animaciones de cobertura; este componente lo corrige al cargar (ver _prepare_library).
class_name CharacterAnimator3D
extends Node

## Pose de reposo provisional: fotograma neutro (piernas juntas) de una animación de paso.
## Los modelos no traen "idle"; sustituir cuando se añada una animación de reposo real.
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
	&"tiptoe_walk",
	&"crouch_walk",
	&"prone_forward",
	&"prone_idle",
	&"cover_idle",
	&"cover_sneak_left",
	&"cover_sneak_right",
]

## Animaciones con desplazamiento lateral de cadera que hay que anular (el movimiento
## real lo hace el CharacterBody3D; si no, el modelo salta al reiniciar el bucle).
const ROOT_MOTION_ANIMATIONS: Array[StringName] = [&"cover_sneak_left", &"cover_sneak_right"]

## Velocidad (m/s) a la que cada animación de paso encaja sin patinar. Las de cobertura están
## medidas por su desplazamiento de cadera (1.24 m en 1.17 s); el resto, estimadas.
const ANIMATION_REFERENCE_SPEED: Dictionary = {
	&"walk": 1.6,
	&"sneak_walk": 1.2,
	&"tiptoe_walk": 0.8,
	&"crouch_walk": 1.2,
	&"prone_forward": 0.5,
	&"cover_sneak_left": 1.06,
	&"cover_sneak_right": 1.06,
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

## Estado de animación bloqueada (por ejemplo, acción o transición)
var _is_action_playing: bool = false

## Animación o pose lógica activa (puede ser una pose de POSES)
var _current_state: StringName = &""


func _ready() -> void:
	_player = get_parent() as PlayerBase3D
	if not animation_player and _player != null:
		animation_player = _player.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation_player != null:
		_prepare_library(animation_player)
	if _player != null:
		_player.stance_changed.connect(_on_stance_changed)


## Activa bucles y anula el desplazamiento de cadera. Los recursos Animation del .glb se
## comparten entre instancias, así que se marca cada uno para tratarlo una sola vez.
static func _prepare_library(player: AnimationPlayer) -> void:
	for anim_name: StringName in player.get_animation_list():
		var anim: Animation = player.get_animation(anim_name)
		if anim.has_meta(LIBRARY_PREPARED_META):
			continue
		anim.set_meta(LIBRARY_PREPARED_META, true)
		if LOOPED_ANIMATIONS.has(anim_name):
			anim.loop_mode = Animation.LOOP_LINEAR
		if ROOT_MOTION_ANIMATIONS.has(anim_name):
			_strip_horizontal_hips_motion(anim)


static func _strip_horizontal_hips_motion(anim: Animation) -> void:
	for track: int in anim.get_track_count():
		if anim.track_get_type(track) != Animation.TYPE_POSITION_3D:
			continue
		if not str(anim.track_get_path(track)).ends_with("Hips"):
			continue
		var first: Vector3 = anim.track_get_key_value(track, 0)
		for key: int in anim.track_get_key_count(track):
			var pos: Vector3 = anim.track_get_key_value(track, key)
			anim.track_set_key_value(track, key, Vector3(first.x, pos.y, pos.z))


func _on_stance_changed(old_stance: PlayerBase3D.Stance, new_stance: PlayerBase3D.Stance) -> void:
	if animation_player == null:
		return
	if old_stance == PlayerBase3D.Stance.CROUCH and new_stance == PlayerBase3D.Stance.PRONE:
		play_action(&"crouch_to_prone")
	elif new_stance == PlayerBase3D.Stance.WALL_COVER:
		play_action(&"taking_cover_idle")


func _process(_delta: float) -> void:
	if not _player or not animation_player or _is_action_playing:
		return

	var horizontal_speed: float = Vector2(_player.velocity.x, _player.velocity.z).length()
	var lateral_dot: float = 0.0
	if _player.current_stance == PlayerBase3D.Stance.WALL_COVER:
		lateral_dot = _player.velocity.dot(_player.global_transform.basis.x.normalized())

	var state: StringName = resolve_animation_name(
		_player.get_stance(),
		horizontal_speed,
		_player.is_sprinting,
		_player.is_sneaking,
		lateral_dot
	)
	_apply_state(state, horizontal_speed)


## Resuelve la animación (o pose de reposo) según la postura, velocidad y dirección lateral
# gdlint: disable=max-returns
func resolve_animation_name(
	stance: PlayerBase3D.Stance,
	horizontal_speed: float,
	_is_sprinting: bool = false,
	is_sneaking: bool = false,
	lateral_dot: float = 0.0
) -> StringName:
	var is_moving: bool = horizontal_speed >= MOVING_SPEED_THRESHOLD

	match stance:
		PlayerBase3D.Stance.STAND:
			if not is_moving:
				return IDLE_STAND_POSE
			# Sin animación de correr: el sprint usa "walk" acelerada (ver ANIMATION_REFERENCE_SPEED)
			return &"sneak_walk" if is_sneaking else &"walk"
		PlayerBase3D.Stance.TIPTOE:
			return &"tiptoe_walk" if is_moving else IDLE_STAND_POSE
		PlayerBase3D.Stance.CROUCH:
			return &"crouch_walk" if is_moving else IDLE_CROUCH_POSE
		PlayerBase3D.Stance.PRONE:
			return &"prone_forward" if is_moving else &"prone_idle"
		PlayerBase3D.Stance.WALL_COVER:
			if not is_moving:
				return &"cover_idle"
			return &"cover_sneak_left" if lateral_dot < -0.05 else &"cover_sneak_right"
	return &""


# gdlint: enable=max-returns


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
	animation_player.speed_scale = _playback_speed(state, horizontal_speed)


func _playback_speed(anim_name: StringName, horizontal_speed: float) -> float:
	if not ANIMATION_REFERENCE_SPEED.has(anim_name):
		return 1.0
	var ratio: float = horizontal_speed / float(ANIMATION_REFERENCE_SPEED[anim_name])
	return clampf(ratio, MIN_PLAYBACK_SPEED, MAX_PLAYBACK_SPEED)
