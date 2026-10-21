## @file test_asset_import.gd
## Verificación de importación de assets 3D en Godot 4.7 (FEAT-001 Criterio 6).
## Comprueba AABB visual dentro de ±1% y pivote en la base inferior central (Y=0, X=0, Z=0).
extends GutTest

const ASSETS_DIR: String = "res://assets/models/"

# Estructura de expectativas para los assets clave en coordenadas de Godot:
# Godot Size: X=ancho, Y=alto (Z de Blender), Z=profundidad (Y de Blender)
const ASSET_EXPECTATIONS: Dictionary = {
	"safe_box_84.glb":
	{
		"expected_size": Vector3(0.90, 1.10, 0.96),
		"requires_collision": true,
	},
	"time_clock_84.glb":
	{
		"expected_size": Vector3(0.44, 0.60, 0.25),
		"requires_collision": true,
	},
	"rotary_phone_84.glb":
	{
		"expected_size": Vector3(0.38, 0.26, 0.32),
		"requires_collision": true,
	},
	"thief_pawn.glb":
	{
		"expected_size": Vector3(0.80, 1.80, 0.80),
		"requires_collision": false,
	},
	"guard_pawn.glb":
	{
		"expected_size": Vector3(0.815, 1.80, 0.820),
		"requires_collision": false,
	},
	"wall_mahogany.glb":
	{
		"expected_size": Vector3(2.00, 3.00, 0.20),
		"requires_collision": true,
	},
	"floor_carpet.glb":
	{
		"expected_size": Vector3(2.00, 0.10, 2.00),
		"requires_collision": true,
	},
	"escape_car_84.glb":
	{
		"expected_size": Vector3(2.15, 1.20, 4.46),
		"requires_collision": true,
	},
	"alarm_clock.glb":
	{
		"expected_size": Vector3(0.18, 0.22, 0.12),
		"requires_collision": true,
	},
	"wood_wedge.glb":
	{
		"expected_size": Vector3(0.25, 0.08, 0.08),
		"requires_collision": true,
	},
	"stethoscope.glb":
	{
		"expected_size": Vector3(0.26, 0.05, 0.32),
		"requires_collision": false,
	},
	"inspection_mirror.glb":
	{
		"expected_size": Vector3(0.10, 0.04, 0.38),
		"requires_collision": false,
	},
	"tripwire_bell.glb":
	{
		"expected_size": Vector3(0.12, 0.18, 0.14),
		"requires_collision": true,
	},
}


func _find_mesh_instances(curr: Node, out: Array[MeshInstance3D]) -> void:
	if curr is MeshInstance3D:
		out.append(curr as MeshInstance3D)
	for child in curr.get_children():
		_find_mesh_instances(child, out)


func _find_collision_shapes(curr: Node, out: Array[CollisionShape3D]) -> void:
	if curr is CollisionShape3D:
		out.append(curr as CollisionShape3D)
	for child in curr.get_children():
		_find_collision_shapes(child, out)


func _compute_visual_aabb(root: Node3D) -> AABB:
	var meshes: Array[MeshInstance3D] = []
	_find_mesh_instances(root, meshes)

	var combined_aabb := AABB()
	var is_first: bool = true

	for mi: MeshInstance3D in meshes:
		var mi_name: String = mi.name.to_lower()
		if mi_name.ends_with("-col") or mi_name.ends_with("-colonly"):
			continue

		var local_aabb: AABB = mi.get_aabb()
		var rel_xform: Transform3D = root.global_transform.affine_inverse() * mi.global_transform
		var trans_aabb: AABB = rel_xform * local_aabb

		if is_first:
			combined_aabb = trans_aabb
			is_first = false
		else:
			combined_aabb = combined_aabb.merge(trans_aabb)

	return combined_aabb


func _verify_asset(glb_filename: String) -> void:
	var glb_path: String = ASSETS_DIR + glb_filename
	assert_true(ResourceLoader.exists(glb_path), "Asset %s existe en disco" % glb_filename)

	var packed_scene: PackedScene = load(glb_path) as PackedScene
	assert_not_null(packed_scene, "PackedScene cargada con exito para %s" % glb_filename)

	var instance: Node3D = autofree(packed_scene.instantiate() as Node3D)
	assert_not_null(instance, "Instancia 3D creada para %s" % glb_filename)
	add_child_autofree(instance)
	await wait_physics_frames(1)

	var aabb: AABB = _compute_visual_aabb(instance)
	var expected: Dictionary = ASSET_EXPECTATIONS[glb_filename]
	var exp_size: Vector3 = expected["expected_size"]

	# 1. Comprobación de dimensiones (AABB size) dentro de ±1% (tolerancia min 0.015m)
	var tol_x: float = maxf(exp_size.x * 0.01, 0.015)
	var tol_y: float = maxf(exp_size.y * 0.01, 0.015)
	var tol_z: float = maxf(exp_size.z * 0.01, 0.015)

	var msg_x: String = (
		"[%s] Ancho X en ±1%% (%f vs %f)" % [glb_filename, aabb.size.x, exp_size.x]
	)
	assert_almost_eq(aabb.size.x, exp_size.x, tol_x, msg_x)

	var msg_y: String = (
		"[%s] Alto Y en ±1%% (%f vs %f)" % [glb_filename, aabb.size.y, exp_size.y]
	)
	assert_almost_eq(aabb.size.y, exp_size.y, tol_y, msg_y)

	var msg_z: String = (
		"[%s] Fondo Z en ±1%% (%f vs %f)" % [glb_filename, aabb.size.z, exp_size.z]
	)
	assert_almost_eq(aabb.size.z, exp_size.z, tol_z, msg_z)

	# 2. Comprobación de pivote en la base inferior central
	# Base inferior: position.y == 0.0 (tolerancia 0.015m)
	var msg_base: String = "[%s] Base en Y=0.0 (%f)" % [glb_filename, aabb.position.y]
	assert_almost_eq(aabb.position.y, 0.0, 0.015, msg_base)

	# Centrado en X: position.x + size.x / 2.0 ~= 0.0
	var center_x: float = aabb.position.x + aabb.size.x / 2.0
	var msg_cx: String = "[%s] Centrado en X ~= 0.0 (%f)" % [glb_filename, center_x]
	assert_almost_eq(center_x, 0.0, 0.035, msg_cx)

	# Centrado en Z: position.z + size.z / 2.0 ~= 0.0
	var center_z: float = aabb.position.z + aabb.size.z / 2.0
	var msg_cz: String = "[%s] Centrado en Z ~= 0.0 (%f)" % [glb_filename, center_z]
	assert_almost_eq(center_z, 0.0, 0.035, msg_cz)

	# 3. Comprobación de colisión importada si la ficha lo pide
	if expected["requires_collision"]:
		var col_shapes: Array[CollisionShape3D] = []
		_find_collision_shapes(instance, col_shapes)
		var msg_col: String = "[%s] CollisionShape3D creado desde -col" % glb_filename
		assert_gt(col_shapes.size(), 0, msg_col)


func test_all_key_assets_import_and_bounds() -> void:
	for glb_filename: String in ASSET_EXPECTATIONS:
		await _verify_asset(glb_filename)


func test_gadgets_assets_import_and_bounds() -> void:
	var gadgets: Array[String] = [
		"alarm_clock.glb",
		"wood_wedge.glb",
		"stethoscope.glb",
		"inspection_mirror.glb",
		"tripwire_bell.glb",
	]
	for glb_filename: String in gadgets:
		await _verify_asset(glb_filename)
