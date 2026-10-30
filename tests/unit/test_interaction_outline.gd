## @file test_interaction_outline.gd
## El foco local añade un contorno no destructivo y lo retira al cambiar de personaje local.
extends GutTest


class OutlineTarget:
	extends Area3D

	func can_interact(_actor: Node3D = null) -> bool:
		return true

	func interact(_actor: Node3D = null) -> void:
		pass


const GUARD_SCENE: PackedScene = preload("res://scenes/entities/guard_player.tscn")

var _root: Node3D = null


func before_each() -> void:
	_root = Node3D.new()
	add_child_autofree(_root)


func _target() -> OutlineTarget:
	var target: OutlineTarget = OutlineTarget.new()
	target.collision_layer = Interactor3D.INTERACTION_LAYER_MASK
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.6, 1.8, 0.6)
	collision.shape = box
	target.add_child(collision)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.name = "TargetMesh"
	var visual: BoxMesh = BoxMesh.new()
	visual.size = Vector3(0.6, 1.8, 0.6)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color.NAVY_BLUE
	visual.material = material
	mesh.mesh = visual
	target.add_child(mesh)
	_root.add_child(target)
	target.position = Vector3(0.0, 0.0, -1.0)
	return target


func _outline_meshes(target: Node3D) -> Array[Node]:
	return target.find_children("InteractionOutline", "MeshInstance3D", true, false)


func test_local_focus_outlines_and_preserves_the_original_material() -> void:
	var target: OutlineTarget = _target()
	var mesh: MeshInstance3D = target.get_node("TargetMesh") as MeshInstance3D
	var original: Material = (mesh.mesh as BoxMesh).material
	var guard: GuardController3D = GUARD_SCENE.instantiate() as GuardController3D
	_root.add_child(guard)
	guard.set_physics_process(false)
	guard.is_locally_controlled = true
	await wait_physics_frames(4)
	assert_eq(guard.interactor.current_target, target, "El objeto cercano tiene el foco")
	assert_eq(_outline_meshes(target).size(), 1, "El foco local crea un contorno")
	assert_eq((mesh.mesh as BoxMesh).material, original, "El material original no se sustituye")
	guard.is_locally_controlled = false
	await wait_physics_frames(4)
	assert_true(_outline_meshes(target).is_empty(), "Al cambiar de jugador local se limpia")
	assert_eq((mesh.mesh as BoxMesh).material, original, "El original sigue intacto")


func test_preview_scene_instantiates_the_outline() -> void:
	var scene: PackedScene = (
		load("res://scenes/vfx/interaction_outline_preview.tscn") as PackedScene
	)
	assert_not_null(scene, "La escena aislada del VFX carga")
	var preview: Node3D = scene.instantiate() as Node3D
	_root.add_child(preview)
	await wait_process_frames(2)
	var target: MeshInstance3D = preview.get_node("Target") as MeshInstance3D
	assert_eq(_outline_meshes(target).size(), 1, "La escena aislada muestra el contorno")
