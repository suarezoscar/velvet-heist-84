## @file test_interactor_walls.gd
## Interactor3D no enfoca un interactuable al otro lado de un muro o tabique del nivel, pero sí
## por encima de un mueble o con el camino libre (rayo de la capa 4 que atravesaba paredes).
extends GutTest

const FIXTURE_PATH: String = "res://tests/fixtures/level_small.json"
const GUARD_SCENE: PackedScene = preload("res://scenes/entities/guard_player.tscn")

var _root: Node3D = null


func before_each() -> void:
	_root = Node3D.new()
	add_child_autofree(_root)
	LevelArchitectureBuilder.build(LevelData.load_json(FIXTURE_PATH), _root)


## Guardia quieto en from mirando a un reloj de fichar en at; devuelve lo que enfoca
func _focus(from: Vector3, at: Vector3) -> Node3D:
	var clock: TimeClock3D = TimeClock3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.6, 2.0, 0.4)
	shape.shape = box
	shape.position = Vector3(0.0, 1.0, 0.0)
	clock.add_child(shape)
	_root.add_child(clock)
	clock.global_position = at
	var guard: GuardController3D = GUARD_SCENE.instantiate() as GuardController3D
	_root.add_child(guard)
	guard.set_physics_process(false)
	guard.global_position = from
	var to_clock: Vector3 = (at - from).slide(Vector3.UP)
	guard.rotation.y = atan2(-to_clock.x, -to_clock.z)
	await wait_physics_frames(3)
	return guard.interactor.current_target


func test_open_path_focuses() -> void:
	var target: Node3D = await _focus(Vector3(2.7, 0.05, 4.5), Vector3(4.0, 0.0, 4.5))
	assert_true(target is TimeClock3D, "Sin nada en medio se enfoca")


func test_wall_blocks_interaction() -> void:
	var target: Node3D = await _focus(Vector3(7.3, 0.05, 4.5), Vector3(8.6, 0.0, 4.5))
	assert_null(target, "El reloj al otro lado del muro x=8 no se enfoca")


func test_partition_blocks_interaction() -> void:
	var target: Node3D = await _focus(Vector3(3.5, 0.05, 1.3), Vector3(3.5, 0.0, 2.6))
	assert_null(target, "El tabique T1 tapa el reloj")


func test_same_side_and_over_furniture() -> void:
	var furniture: StaticBody3D = StaticBody3D.new()
	furniture.collision_layer = 1
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.2, 1.5, 0.6)
	shape.shape = box
	furniture.add_child(shape)
	_root.add_child(furniture)
	furniture.global_position = Vector3(3.3, 0.75, 4.5)
	var target: Node3D = await _focus(Vector3(2.7, 0.05, 4.5), Vector3(4.0, 0.0, 4.5))
	assert_true(target is TimeClock3D, "Un mueble no es un muro: se enfoca")
