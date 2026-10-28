## @file replica_table_3d.gd
## La mesa de réplicas del taller de restauración (heist.md R9): el ladrón coge una pieza de
## pega (solo una cada vez) para dar el cambiazo en un pedestal de presión.
class_name ReplicaTable3D
extends Area3D

const AREA_SIZE: Vector3 = Vector3(2.6, 1.4, 1.6)


static func create() -> ReplicaTable3D:
	var table: ReplicaTable3D = ReplicaTable3D.new()
	table.name = "ReplicaTable"
	table.collision_layer = 4
	table.collision_mask = 2
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = AREA_SIZE
	var col: CollisionShape3D = CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0.0, AREA_SIZE.y * 0.5, 0.0)
	table.add_child(col)
	return table


func can_interact(actor: Node3D = null) -> bool:
	return (
		actor is ThiefController3D
		and GameManager.heist != null
		and not GameManager.heist.carrying_fake
	)


func get_interaction_text(_actor: Node3D = null) -> String:
	return "Coger una pieza de pega [E]"


func interact(actor: Node3D) -> void:
	if can_interact(actor):
		GameManager.heist.carrying_fake = true
		NoiseEmit.emit(global_position, 2.0, &"thief", NoiseEmit.IMPACT, actor)
