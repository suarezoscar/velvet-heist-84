## @file replica_table_3d.gd
## La mesa de réplicas del taller de restauración (heist.md R9): el ladrón coge una pieza de
## pega (solo una cada vez) para dar el cambiazo en un pedestal de presión.
class_name ReplicaTable3D
extends Area3D

const AREA_SIZE: Vector3 = Vector3(1.8, 1.4, 1.4)
const TABLE_SIZE: Vector3 = Vector3(1.2, 0.85, 0.6)
const BUST_MODEL: PackedScene = preload("res://assets/models/marble_bust.glb")


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
	# Mesa con un busto a medio copiar: se reconoce de un vistazo
	var body: StaticBody3D = StaticBody3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = TABLE_SIZE
	var body_col: CollisionShape3D = CollisionShape3D.new()
	body_col.shape = box
	body.add_child(body_col)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = TABLE_SIZE
	mesh.mesh = box_mesh
	body.add_child(mesh)
	body.position = Vector3(0.0, TABLE_SIZE.y * 0.5, 0.0)
	table.add_child(body)
	var bust: Node3D = BUST_MODEL.instantiate() as Node3D
	bust.scale = Vector3.ONE * 0.8
	bust.position = Vector3(0.25, TABLE_SIZE.y, 0.0)
	table.add_child(bust)
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
