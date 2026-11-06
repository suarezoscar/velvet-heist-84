## @file target_piece_game.gd
## Minijuego de la pieza candidata (#119): lo que ve el panel y las teclas del ladrón.
class_name TargetPieceGame
extends RefCounted


## true mientras el ladrón juega su minijuego (también en el cliente, por la red)
static func is_playing(piece: TargetPiece3D) -> bool:
	return piece.game != null or int(piece._view.get("game", 0)) != 0


## Lo que enseña el panel del minijuego ({} sin minijuego)
static func view(piece: TargetPiece3D) -> Dictionary:
	if piece.game != null:
		return piece.game.to_view()
	return piece._view if is_playing(piece) else {}


## E (un intento o volver a sujetar), soltar E (la balanza se pausa) o Esc (sale)
static func action(piece: TargetPiece3D, actor: Node3D, action_name: StringName) -> void:
	if piece.game == null or piece.game.actor != actor:
		return
	match action_name:
		&"interact":
			piece.game.press()
		&"interact_release":
			piece.game.release()
		&"dial_cancel":
			piece.game = null


## Teclas de movimiento del ladrón durante el minijuego
static func steer(piece: TargetPiece3D, actor: Node3D, move: Vector2) -> void:
	if piece.game != null and piece.game.actor == actor:
		piece.game.steer(move)
