## @file character_animator_3d.gd
## Componente modular que conecta el estado físico de PlayerBase3D
## con las animaciones de los modelos esqueléticos (Rogue y Knight).
class_name CharacterAnimator3D
extends Node

## Referencia al AnimationPlayer del modelo 3D
@export var animation_player: AnimationPlayer

## Nodo padre esperado (PlayerBase3D)
var _player: PlayerBase3D = null

## Estado de animación bloqueada (por ejemplo, ataque o interacción)
var _is_action_playing: bool = false

func _ready() -> void:
	_player = get_parent() as PlayerBase3D
	if not animation_player:
		animation_player = _player.find_child("AnimationPlayer", true, false) as AnimationPlayer

func _process(_delta: float) -> void:
	if not _player or not animation_player or _is_action_playing:
		return

	var horizontal_speed: float = Vector2(_player.velocity.x, _player.velocity.z).length()

	if horizontal_speed < 0.15:
		_play_if_not_active(&"Idle")
	elif _player.is_sprinting:
		_play_if_not_active(&"Running_A", 1.2)
	elif _player.is_sneaking:
		_play_if_not_active(&"Walking_B", 0.9)
	else:
		_play_if_not_active(&"Walking_A", 1.0)

## Reproduce una animación de acción única (golpe, apertura de caja, etc.)
func play_action(action_name: StringName) -> void:
	if not animation_player or not animation_player.has_animation(action_name):
		return
	_is_action_playing = true
	animation_player.play(action_name)
	if not animation_player.animation_finished.is_connected(_on_action_finished):
		animation_player.animation_finished.connect(_on_action_finished, CONNECT_ONE_SHOT)

func _on_action_finished(_anim_name: StringName) -> void:
	_is_action_playing = false

func _play_if_not_active(anim_name: StringName, custom_speed: float = 1.0) -> void:
	if animation_player.current_animation != anim_name:
		if animation_player.has_animation(anim_name):
			animation_player.play(anim_name, 0.2, custom_speed)
