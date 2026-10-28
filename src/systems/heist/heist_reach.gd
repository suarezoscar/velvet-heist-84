## @file heist_reach.gd
## Qué pieza del encargo tiene el ladrón al alcance para robarla a lo bruto (Q): la más cercana
## a REACH metros, sin muros de por medio, que admita la fuerza (TargetPiece3D.can_force).
class_name HeistReach
extends RefCounted

const REACH: float = 2.0


static func forceable(thief: ThiefController3D) -> TargetPiece3D:
	if thief == null or not thief.is_inside_tree():
		return null
	var space: PhysicsDirectSpaceState3D = thief.get_world_3d().direct_space_state
	var eye: Vector3 = thief.global_position + Vector3.UP
	var best: TargetPiece3D = null
	var best_distance: float = REACH
	for node: Node in thief.get_tree().get_nodes_in_group(&"heist_targets"):
		var piece: TargetPiece3D = node as TargetPiece3D
		var distance: float = piece.global_position.distance_to(thief.global_position)
		if distance > best_distance or not piece.can_force(thief):
			continue
		if not VisionLogic.wall_free(space, eye, piece.global_position + Vector3.UP):
			continue
		best = piece
		best_distance = distance
	return best
