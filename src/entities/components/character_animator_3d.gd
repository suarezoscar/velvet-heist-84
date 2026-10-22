## @file character_animator_3d.gd
## Componente modular que conecta el estado físico y la postura de PlayerBase3D
## con las animaciones de los modelos esqueléticos definitivos (Crypto y SWAT).
class_name CharacterAnimator3D
extends Node

## Referencia al AnimationPlayer del modelo 3D
@export var animation_player: AnimationPlayer

## Nodo padre esperado (PlayerBase3D)
var _player: PlayerBase3D = null

## Estado de animación bloqueada (por ejemplo, acción o transición)
var _is_action_playing: bool = false

func _ready() -> void:
	_player = get_parent() as PlayerBase3D
	if not animation_player and _player != null:
		animation_player = _player.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _player != null:
		_player.stance_changed.connect(_on_stance_changed)

func _on_stance_changed(old_stance: PlayerBase3D.Stance, new_stance: PlayerBase3D.Stance) -> void:
	if animation_player == null:
		return
	if old_stance == PlayerBase3D.Stance.CROUCH and new_stance == PlayerBase3D.Stance.PRONE:
		if animation_player.has_animation(&"crouch_to_prone"):
			play_action(&"crouch_to_prone")
	elif new_stance == PlayerBase3D.Stance.WALL_COVER:
		if animation_player.has_animation(&"taking_cover_idle"):
			play_action(&"taking_cover_idle")

func _process(_delta: float) -> void:
	if not _player or not animation_player or _is_action_playing:
		return

	var horizontal_speed: float = Vector2(_player.velocity.x, _player.velocity.z).length()
	var lateral_dot: float = 0.0
	if _player.current_stance == PlayerBase3D.Stance.WALL_COVER:
		lateral_dot = _player.velocity.dot(_player.global_transform.basis.x.normalized())

	var anim_name: StringName = resolve_animation_name(
		_player.get_stance(),
		horizontal_speed,
		_player.is_sprinting,
		_player.is_sneaking,
		lateral_dot
	)

	if anim_name != &"":
		_play_if_not_active(anim_name, 1.0)

## Resuelve la pista de animación correspondiente según la postura, velocidad y dirección lateral
func resolve_animation_name(
	stance: PlayerBase3D.Stance,
	horizontal_speed: float,
	is_sprinting: bool = false,
	is_sneaking: bool = false,
	lateral_dot: float = 0.0
) -> StringName:
	var is_moving: bool = horizontal_speed >= 0.15

	match stance:
		PlayerBase3D.Stance.STAND:
			if not is_moving:
				if animation_player != null:
					if animation_player.has_animation(&"Idle"):
						return &"Idle"
					elif animation_player.has_animation(&"Armature|mixamo_com|Layer0"):
						return &"Armature|mixamo_com|Layer0"
					elif animation_player.has_animation(&"Armature|mixamo.com|Layer0"):
						return &"Armature|mixamo.com|Layer0"
				return &"Armature|mixamo.com|Layer0"
			elif is_sprinting:
				if animation_player != null and animation_player.has_animation(&"Running_A"):
					return &"Running_A"
				return &"walk"
			elif is_sneaking:
				if animation_player != null and animation_player.has_animation(&"sneak_walk"):
					return &"sneak_walk"
				elif animation_player != null and animation_player.has_animation(&"Walking_B"):
					return &"Walking_B"
				return &"sneak_walk"
			else:
				if animation_player != null and animation_player.has_animation(&"Walking_A"):
					return &"Walking_A"
				return &"walk"

		PlayerBase3D.Stance.TIPTOE:
			if not is_moving:
				return &"Armature|mixamo.com|Layer0"
			return &"tiptoe_walk"

		PlayerBase3D.Stance.CROUCH:
			if not is_moving:
				return &"crouch_to_prone"
			return &"crouch_walk"

		PlayerBase3D.Stance.PRONE:
			if not is_moving:
				return &"prone_idle"
			return &"prone_forward"

		PlayerBase3D.Stance.WALL_COVER:
			if not is_moving:
				return &"cover_idle"
			if lateral_dot > 0.05:
				return &"cover_sneak_right"
			elif lateral_dot < -0.05:
				return &"cover_sneak_left"
			return &"cover_sneak_right"

	return &""

## Reproduce una animación de acción única (golpe, apertura de caja, etc.)
func play_action(action_name: StringName) -> void:
	if not animation_player or not animation_player.has_animation(action_name):
		return
	_is_action_playing = true
	animation_player.play(action_name, 0.15)
	if not animation_player.animation_finished.is_connected(_on_action_finished):
		animation_player.animation_finished.connect(_on_action_finished, CONNECT_ONE_SHOT)

func _on_action_finished(_anim_name: StringName) -> void:
	_is_action_playing = false

func _play_if_not_active(anim_name: StringName, custom_speed: float = 1.0) -> void:
	if animation_player == null:
		return
	if animation_player.current_animation != anim_name:
		if animation_player.has_animation(anim_name):
			animation_player.play(anim_name, 0.2, custom_speed)
