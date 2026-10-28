## @file heist_input.gd
## Sin red, lee las teclas del golpe del jugador local (moneda, walkie y luces de alarma) y
## las ejecuta con HeistActions. Con red lo hace NetSessionClient enviándolas al servidor.
class_name HeistInput
extends Node


func _ready() -> void:
	name = "HeistInput"


func _process(_delta: float) -> void:
	if NetManager.is_online() or LocalInput3D.blocked:
		return
	for action: StringName in HeistActions.ACTIONS:
		if InputMap.has_action(action) and Input.is_action_just_pressed(action):
			HeistActions.handle(_local_actor(), action)


func _local_actor() -> PlayerBase3D:
	for group: StringName in [&"thief", &"guards"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			var actor: PlayerBase3D = node as PlayerBase3D
			if actor != null and actor.is_locally_controlled:
				return actor
	return null
