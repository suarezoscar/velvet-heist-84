extends GutTest
## #193: paredes recortadas por sala: siguen la sala del jugador local, se funden al cambiar y
## sustituyen al círculo de WallXRay. Solo aspecto.

const MAP_SCENE: PackedScene = preload("res://scenes/maps/museum_v2.tscn")
const LOOK: NightLook = preload("res://data/visual/night_look.tres")


func test_cutaway_follows_the_local_room() -> void:
	assert_true(LOOK.occlusion_cutaway, "Paredes recortadas por defecto")
	var map: HeistMap3D = MAP_SCENE.instantiate() as HeistMap3D
	add_child_autofree(map)
	for guard: GuardController3D in map.guards:
		guard.set_physics_process(false)
	map.thief.set_physics_process(false)
	await wait_physics_frames(3)
	var cutaway: WallCutaway = map.get_node_or_null("WallCutaway") as WallCutaway
	assert_not_null(cutaway)
	var data: LevelData = map.get_meta(&"level_data") as LevelData
	var ves: Rect2 = data.room_rect(data.room_by_id("VES"))
	var center: Vector2 = ves.get_center() + data.offset
	map.thief.global_position = Vector3(center.x, 0.2, center.y)
	await wait_seconds(LOOK.cutaway_time + 0.2)
	var mat: ShaderMaterial = WallXRay.materials()[0]
	assert_almost_eq(float(mat.get_shader_parameter(&"cut_amount_a")), 1.0, 0.01, "Bajadas")
	var rect: Vector4 = mat.get_shader_parameter(&"cut_rect_a")
	var corner: Vector3 = data.to_world([ves.position.x, ves.position.y])
	assert_almost_eq(rect.x, corner.x, 0.01, "La sala del vestíbulo")
	assert_eq(float(mat.get_shader_parameter(&"xray_radius")), 0.0, "Sin círculo")
