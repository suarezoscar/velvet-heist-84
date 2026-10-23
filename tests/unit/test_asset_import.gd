## @file test_asset_import.gd
## Verificación de importación de assets 3D en Godot 4.7 (FEAT-001 y FEAT-009).
## Comprueba AABB visual y pivote en la base inferior central guiado por las fichas.
extends GutTest

const ASSETS_DIR: String = "res://assets/models/"
const SPECS_DIR: String = "res://tools/blender_scripts/specs/"

## Tolerancias según FEAT-009 (Reglas del validador)
const DIM_TOL_REL: float = 0.01
const DIM_TOL_MIN: float = 0.001
const PIVOT_Z_TOL: float = 0.002
const PIVOT_XY_TOL_REL: float = 0.01
const PIVOT_XY_TOL_MIN: float = 0.005


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
		var trans_aabb: AABB
		if mi.skin != null:
			trans_aabb = local_aabb
		else:
			var rel_xform: Transform3D = (
				root.global_transform.affine_inverse() * mi.global_transform
			)
			trans_aabb = rel_xform * local_aabb

		if is_first:
			combined_aabb = trans_aabb
			is_first = false
		else:
			combined_aabb = combined_aabb.merge(trans_aabb)

	return combined_aabb


func _verify_asset(glb_filename: String, exp_size: Vector3, requires_collision: bool) -> void:
	var glb_path: String = ASSETS_DIR + glb_filename
	assert_true(ResourceLoader.exists(glb_path), "Asset %s existe en disco" % glb_filename)

	var packed_scene: PackedScene = load(glb_path) as PackedScene
	assert_not_null(packed_scene, "PackedScene cargada con exito para %s" % glb_filename)

	var instance: Node3D = autofree(packed_scene.instantiate() as Node3D)
	assert_not_null(instance, "Instancia 3D creada para %s" % glb_filename)
	add_child_autofree(instance)
	await wait_physics_frames(1)

	var aabb: AABB = _compute_visual_aabb(instance)

	# 1. Comprobación de dimensiones según tolerancias FEAT-009
	var tol_x: float = maxf(exp_size.x * DIM_TOL_REL, DIM_TOL_MIN)
	var tol_y: float = maxf(exp_size.y * DIM_TOL_REL, DIM_TOL_MIN)
	var tol_z: float = maxf(exp_size.z * DIM_TOL_REL, DIM_TOL_MIN)

	var msg_x: String = "[%s] Ancho X en ±1%% (%f vs %f)" % [glb_filename, aabb.size.x, exp_size.x]
	assert_almost_eq(aabb.size.x, exp_size.x, tol_x, msg_x)

	var msg_y: String = "[%s] Alto Y en ±1%% (%f vs %f)" % [glb_filename, aabb.size.y, exp_size.y]
	assert_almost_eq(aabb.size.y, exp_size.y, tol_y, msg_y)

	var msg_z: String = "[%s] Fondo Z en ±1%% (%f vs %f)" % [glb_filename, aabb.size.z, exp_size.z]
	assert_almost_eq(aabb.size.z, exp_size.z, tol_z, msg_z)

	# 2. Comprobación de pivote en la base inferior central
	# Base inferior: position.y == 0.0 (tolerancia PIVOT_Z_TOL = 0.002m)
	var msg_base: String = "[%s] Base en Y=0.0 (%f)" % [glb_filename, aabb.position.y]
	assert_almost_eq(aabb.position.y, 0.0, PIVOT_Z_TOL, msg_base)

	# Centrado en X: position.x + size.x / 2.0 ~= 0.0
	var center_x: float = aabb.position.x + aabb.size.x / 2.0
	var x_tol: float = maxf(exp_size.x * PIVOT_XY_TOL_REL, PIVOT_XY_TOL_MIN)
	var msg_cx: String = "[%s] Centrado en X ~= 0.0 (%f)" % [glb_filename, center_x]
	assert_almost_eq(center_x, 0.0, x_tol, msg_cx)

	# Centrado en Z (Y de Blender): position.z + size.z / 2.0 ~= 0.0
	var center_z: float = aabb.position.z + aabb.size.z / 2.0
	var z_tol: float = maxf(exp_size.z * PIVOT_XY_TOL_REL, PIVOT_XY_TOL_MIN)
	var msg_cz: String = "[%s] Centrado en Z ~= 0.0 (%f)" % [glb_filename, center_z]
	assert_almost_eq(center_z, 0.0, z_tol, msg_cz)

	# 3. Comprobación de colisión importada si la ficha lo pide
	var col_shapes: Array[CollisionShape3D] = []
	_find_collision_shapes(instance, col_shapes)
	if requires_collision:
		var msg_col: String = "[%s] CollisionShape3D creado desde -col" % glb_filename
		assert_gt(col_shapes.size(), 0, msg_col)
	else:
		var msg_no_col: String = "[%s] Sin colision estatica (-col)" % glb_filename
		assert_eq(col_shapes.size(), 0, msg_no_col)


func test_assets_match_their_cards() -> void:
	var dir: DirAccess = DirAccess.open(SPECS_DIR)
	assert_not_null(dir, "El directorio de fichas %s existe" % SPECS_DIR)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	var spec_files: Array[String] = []

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			spec_files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	spec_files.sort()
	assert_gte(spec_files.size(), 15, "Existen al menos 15 fichas en %s" % SPECS_DIR)

	var count: int = 0
	for spec_file: String in spec_files:
		var file_path: String = SPECS_DIR + spec_file
		var json_text: String = FileAccess.get_file_as_string(file_path)
		var parsed: Variant = JSON.parse_string(json_text)
		assert_not_null(parsed, "Ficha %s parseada con exito" % spec_file)
		if not (parsed is Dictionary):
			continue

		var card: Dictionary = parsed as Dictionary
		var asset_name: String = card.get("name", spec_file.get_basename())
		var glb_filename: String = asset_name + ".glb"
		var dims: Array = card.get("dimensions", [])
		assert_eq(dims.size(), 3, "[%s] Ficha define 3 dimensiones" % spec_file)
		if dims.size() != 3:
			continue

		var d0: float = float(dims[0])
		var d1: float = float(dims[1])
		var d2: float = float(dims[2])
		# En Godot el tamaño es Vector3(d[0], d[2], d[1])
		# (X ancho, Y alto = Z Blender, Z fondo = Y Blender)
		var exp_size := Vector3(d0, d2, d1)
		var requires_collision: bool = bool(card.get("collision", false))

		await _verify_asset(glb_filename, exp_size, requires_collision)
		count += 1

	assert_gte(count, 15, "Se recorrieron al menos 15 fichas de assets")


func test_character_models_proportions_and_bounds() -> void:
	var characters: Dictionary = {
		"characters/thief_crypto.glb":
		{
			"expected_height": 1.80,
			"expected_max_wingspan": 1.85,
		},
		"characters/guard_swat.glb":
		{
			"expected_height": 1.82,
			"expected_max_wingspan": 2.05,
		},
	}

	for char_path: String in characters:
		var full_path: String = ASSETS_DIR + char_path
		assert_true(FileAccess.file_exists(full_path), "[%s] Archivo existe" % char_path)
		var scene: PackedScene = load(full_path) as PackedScene
		assert_not_null(scene, "[%s] Escena cargada con éxito" % char_path)
		var inst: Node3D = autofree(scene.instantiate() as Node3D)
		add_child_autofree(inst)
		await wait_physics_frames(1)

		var aabb: AABB = _compute_visual_aabb(inst)
		var exp_data: Dictionary = characters[char_path] as Dictionary
		var exp_h: float = exp_data["expected_height"] as float
		var exp_span: float = exp_data["expected_max_wingspan"] as float

		# 1. Altura humana métrica normal (1.80m / 1.82m con tolerancia ±5cm)
		var msg_h: String = "[%s] Altura humana (~%f m vs %f m)" % [char_path, exp_h, aabb.size.y]
		assert_almost_eq(aabb.size.y, exp_h, 0.05, msg_h)

		# 2. Envergadura acotada (< 2.1m, descartando el bug de 180m de ancho)
		var msg_w: String = "[%s] Ancho (< %f m, actual: %f m)" % [char_path, exp_span, aabb.size.x]
		assert_lt(aabb.size.x, exp_span, msg_w)

		# 3. Base inferior sobre el suelo (Y=0.0 con tolerancia 2cm)
		var msg_base: String = "[%s] Base inferior en Y=0.0 (%f m)" % [char_path, aabb.position.y]
		assert_almost_eq(aabb.position.y, 0.0, 0.02, msg_base)

		# 4. Centrado horizontal en X
		var center_x: float = aabb.position.x + aabb.size.x / 2.0
		var msg_cx: String = "[%s] Centrado horizontal en X (%f m)" % [char_path, center_x]
		assert_almost_eq(center_x, 0.0, 0.05, msg_cx)
