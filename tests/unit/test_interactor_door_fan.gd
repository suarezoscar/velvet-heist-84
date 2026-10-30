## @file test_interactor_door_fan.gd
## La selección en abanico alcanza toda la puerta por ambos lados sin que su hoja se autooculte.
extends GutTest

const GUARD_SCENE: PackedScene = preload("res://scenes/entities/guard_player.tscn")

var _root: Node3D = null
var _door: Door3D = null
var _guard: GuardController3D = null


func before_each() -> void:
	_root = Node3D.new()
	add_child_autofree(_root)
	_door = Door3D.create("prueba", 1.6)
	_root.add_child(_door)
	_guard = GUARD_SCENE.instantiate() as GuardController3D
	_root.add_child(_guard)
	_guard.set_physics_process(false)
	_guard.is_ai_controlled = false


func test_door_focuses_from_both_sides_and_across_the_opening() -> void:
	for side: float in [-1.0, 1.0]:
		for horizontal: float in [-0.8, 0.0, 0.8]:
			_guard.global_position = Vector3(horizontal, 0.05, side * 1.6)
			_guard.look_at(_door.global_position, Vector3.UP)
			await wait_physics_frames(3)
			assert_eq(
				_guard.interactor.current_target,
				_door,
				"Puerta enfocada desde x=%.1f, z=%.1f" % [horizontal, side * 1.6]
			)
