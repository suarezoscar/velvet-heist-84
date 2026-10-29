## @file test_level_bounds.gd
## El callejón está cerrado (sección "bounds" del nivel) y nadie cae sin fin por un hueco: la
## red de seguridad lo devuelve al último suelo que pisó.
extends GutTest

const MAP_SCENE: PackedScene = preload("res://scenes/maps/museum_v2.tscn")


func _map() -> HeistMap3D:
	var map: HeistMap3D = MAP_SCENE.instantiate() as HeistMap3D
	add_child_autofree(map)
	return map


func test_alley_is_closed_on_every_open_side() -> void:
	var map: HeistMap3D = _map()
	await wait_physics_frames(2)
	for id: String in ["ALY_S", "ALY_W", "ALY_E", "ALY_NW", "ALY_NE"]:
		var bound: StaticBody3D = map.find_child("Bound_%s" % id, true, false) as StaticBody3D
		assert_not_null(bound, "Cierre %s" % id)
		if bound != null:
			assert_true(
				bound.collision_layer & LevelArchitectureBuilder.LAYER_WALLS != 0,
				"Tapa la vista y para las monedas como un muro"
			)


func test_walking_off_the_alley_is_stopped_by_the_wall() -> void:
	var map: HeistMap3D = _map()
	await wait_physics_frames(3)
	var thief: ThiefController3D = map.thief
	thief.is_locally_controlled = false  # que no lea el teclado del test
	var start: Vector3 = thief.global_position
	for i: int in range(240):  # 4 s andando hacia el sur (fuera del callejón)
		thief.apply_world_move(Vector3(0.0, 0.0, 1.0))
		await wait_physics_frames(1)
	assert_gt(thief.global_position.y, -1.0, "No cae")
	var south_wall: Node3D = map.find_child("Bound_ALY_S", true, false) as Node3D
	assert_lt(thief.global_position.z, south_wall.global_position.z, "Se queda en el callejón")
	assert_gt(thief.global_position.z, start.z, "Ha llegado a andar hacia el muro")


func test_fall_guard_brings_back_whoever_falls() -> void:
	var map: HeistMap3D = _map()
	await wait_physics_frames(5)
	var thief: ThiefController3D = map.thief
	var ground: Vector3 = thief.global_position
	thief.global_position = Vector3(ground.x, -20.0, ground.z)
	await wait_physics_frames(2)
	assert_gt(thief.global_position.y, -1.0, "Vuelve al suelo")
	assert_almost_eq(thief.global_position.x, ground.x, 0.5)
	assert_almost_eq(thief.global_position.z, ground.z, 0.5)
