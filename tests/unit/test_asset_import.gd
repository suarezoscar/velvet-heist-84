## @file test_asset_import.gd
## Verificación de importación de assets 3D en Godot 4.7 (FEAT-001, FEAT-009 y FEAT-010).
## Comprueba AABB visual, tipos de pivote, ausencia de mallas de colisión visibles y fichas.
extends GutTest

const ASSETS_DIR: String = "res://assets/models/"
const SPECS_DIR: String = "res://tools/blender_scripts/specs/"

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


func _find_visible_collision_meshes(root: Node) -> Array[String]:
	var visible_collisions: Array[String] = []
	var meshes: Array[MeshInstance3D] = []
	_find_mesh_instances(root, meshes)

	for mi: MeshInstance3D in meshes:
		var n: String = mi.name.to_lower()
		if n.ends_with("-col") or n.ends_with("-colonly"):
			visible_collisions.append(mi.name)
			continue
		var p: Node = mi.get_parent()
		if p != null:
			for sib: Node in p.get_children():
				if sib != mi and (sib is CollisionShape3D or sib is StaticBody3D):
					if sib.name == mi.name or sib.name.to_lower() == n:
						visible_collisions.append(mi.name)
						break
	return visible_collisions


func _compute_visual_aabb(root: Node3D) -> AABB:
	var meshes: Array[MeshInstance3D] = []
	_find_mesh_instances(root, meshes)
	var combined_aabb := AABB()
	var is_first: bool = true

	for mi: MeshInstance3D in meshes:
		var n: String = mi.name.to_lower()
		if n.ends_with("-col") or n.ends_with("-colonly"):
			continue
		var local_aabb: AABB = mi.get_aabb()
		var trans_aabb: AABB
		if mi.skin != null:
			trans_aabb = local_aabb
		else:
			var rel_xf: Transform3D = root.global_transform.affine_inverse() * mi.global_transform
			trans_aabb = rel_xf * local_aabb
		if is_first:
			combined_aabb = trans_aabb
			is_first = false
		else:
			combined_aabb = combined_aabb.merge(trans_aabb)
	return combined_aabb


func _is_pivot_valid(aabb: AABB, exp_size: Vector3, pivot: String) -> bool:
	var cx: float = aabb.position.x + aabb.size.x / 2.0
	var cy: float = aabb.position.y + aabb.size.y / 2.0
	var cz: float = aabb.position.z + aabb.size.z / 2.0
	var xtol: float = maxf(exp_size.x * PIVOT_XY_TOL_REL, PIVOT_XY_TOL_MIN)
	var ytol: float = maxf(exp_size.y * PIVOT_XY_TOL_REL, PIVOT_XY_TOL_MIN)
	var ztol: float = maxf(exp_size.z * PIVOT_XY_TOL_REL, PIVOT_XY_TOL_MIN)

	match pivot:
		"bottom_center":
			return absf(aabb.position.y) <= PIVOT_Z_TOL and absf(cx) <= xtol and absf(cz) <= ztol
		"top_center":
			return absf(aabb.end.y) <= PIVOT_Z_TOL and absf(cx) <= xtol and absf(cz) <= ztol
		"back_center":
			var bdist: float = minf(absf(aabb.position.z), absf(aabb.end.z))
			return bdist <= PIVOT_Z_TOL and absf(cx) <= xtol and absf(cy) <= ytol
		_:
			return false


func _verify_asset(
	glb_filename: String,
	exp_size: Vector3,
	requires_collision: bool,
	pivot: String = "bottom_center"
) -> AABB:
	var glb_path: String = ASSETS_DIR + glb_filename
	assert_true(ResourceLoader.exists(glb_path), "Asset %s existe en disco" % glb_filename)

	var packed_scene: PackedScene = load(glb_path) as PackedScene
	assert_not_null(packed_scene, "PackedScene cargada con exito para %s" % glb_filename)

	var instance: Node3D = autofree(packed_scene.instantiate() as Node3D)
	assert_not_null(instance, "Instancia 3D creada para %s" % glb_filename)
	add_child_autofree(instance)
	await wait_physics_frames(1)

	var aabb: AABB = _compute_visual_aabb(instance)
	var tol_x: float = maxf(exp_size.x * DIM_TOL_REL, DIM_TOL_MIN)
	var tol_y: float = maxf(exp_size.y * DIM_TOL_REL, DIM_TOL_MIN)
	var tol_z: float = maxf(exp_size.z * DIM_TOL_REL, DIM_TOL_MIN)

	assert_almost_eq(aabb.size.x, exp_size.x, tol_x, "[%s] Ancho X en +-1%%" % glb_filename)
	assert_almost_eq(aabb.size.y, exp_size.y, tol_y, "[%s] Alto Y en +-1%%" % glb_filename)
	assert_almost_eq(aabb.size.z, exp_size.z, tol_z, "[%s] Fondo Z en +-1%%" % glb_filename)

	var msg_piv: String = "[%s] Pivote '%s' correcto" % [glb_filename, pivot]
	assert_true(_is_pivot_valid(aabb, exp_size, pivot), msg_piv)

	var col_shapes: Array[CollisionShape3D] = []
	_find_collision_shapes(instance, col_shapes)
	if requires_collision:
		var msg_c: String = "[%s] CollisionShape3D creado desde -colonly" % glb_filename
		assert_gt(col_shapes.size(), 0, msg_c)
	else:
		var msg_nc: String = "[%s] Sin colision estatica (-colonly)" % glb_filename
		assert_eq(col_shapes.size(), 0, msg_nc)

	return aabb


func test_assets_match_their_cards() -> void:
	var dir: DirAccess = DirAccess.open(SPECS_DIR)
	assert_not_null(dir, "Directorio %s existe" % SPECS_DIR)
	if dir == null:
		return

	dir.list_dir_begin()
	var f: String = dir.get_next()
	var spec_files: Array[String] = []
	while f != "":
		if not dir.current_is_dir() and f.ends_with(".json"):
			spec_files.append(f)
		f = dir.get_next()
	dir.list_dir_end()
	spec_files.sort()
	assert_eq(spec_files.size(), 25, "25 fichas en %s" % SPECS_DIR)

	var count: int = 0
	for spec_file: String in spec_files:
		var raw_json: String = FileAccess.get_file_as_string(SPECS_DIR + spec_file)
		var parsed: Variant = JSON.parse_string(raw_json)
		assert_not_null(parsed, "Ficha %s parseada" % spec_file)
		if not (parsed is Dictionary):
			continue
		var card: Dictionary = parsed as Dictionary
		var dims: Array = card.get("dimensions", [])
		assert_eq(dims.size(), 3, "[%s] 3 dimensiones" % spec_file)
		if dims.size() != 3:
			continue
		var glb_fn: String = String(card.get("name", spec_file.get_basename())) + ".glb"
		var exp_size := Vector3(float(dims[0]), float(dims[2]), float(dims[1]))
		var req_col: bool = bool(card.get("collision", false))
		var pivot: String = String(card.get("pivot", "bottom_center"))
		var aabb: AABB = await _verify_asset(glb_fn, exp_size, req_col, pivot)
		if pivot == "top_center":
			var msg_mut: String = "[%s] Mutacion: top_center como bottom_center" % glb_fn
			assert_false(_is_pivot_valid(aabb, exp_size, "bottom_center"), msg_mut)
		count += 1

	assert_eq(count, 25, "Se recorrieron las 25 fichas de assets")


func test_collision_meshes_are_invisible() -> void:
	var dir: DirAccess = DirAccess.open(ASSETS_DIR)
	assert_not_null(dir, "Directorio %s existe" % ASSETS_DIR)
	if dir == null:
		return

	dir.list_dir_begin()
	var f: String = dir.get_next()
	var glb_files: Array[String] = []
	while f != "":
		if not dir.current_is_dir() and f.ends_with(".glb"):
			glb_files.append(f)
		f = dir.get_next()
	dir.list_dir_end()
	glb_files.sort()
	assert_gte(glb_files.size(), 25, "Al menos 25 .glb en %s" % ASSETS_DIR)

	for glb_name: String in glb_files:
		var sc: PackedScene = load(ASSETS_DIR + glb_name) as PackedScene
		assert_not_null(sc, "Escena cargada para %s" % glb_name)
		if sc == null:
			continue
		var inst: Node3D = autofree(sc.instantiate() as Node3D)
		add_child_autofree(inst)
		var cols: Array[String] = _find_visible_collision_meshes(inst)
		assert_eq(cols.size(), 0, "[%s] Sin colisiones visibles: %s" % [glb_name, str(cols)])


func test_collision_check_detects_visible_col() -> void:
	var raw_path: String = "res://assets/models/raw/polyhaven/ceramic_vase.glb"
	assert_true(FileAccess.file_exists(raw_path), "raw ceramic_vase.glb existe")
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err: Error = doc.append_from_file(raw_path, state)
	assert_eq(err, OK, "append_from_file OK para raw ceramic_vase.glb")
	var raw_node: Node = autofree(doc.generate_scene(state))
	assert_not_null(raw_node, "Escena generada para raw ceramic_vase.glb")
	if raw_node is Node3D:
		add_child_autofree(raw_node)
	var visible_cols: Array[String] = _find_visible_collision_meshes(raw_node)
	assert_gt(visible_cols.size(), 0, "Debe detectar colision visible en ceramic_vase crudo")


func test_character_models_proportions_and_bounds() -> void:
	var chars: Dictionary = {
		"characters/thief_crypto.glb": [1.80, 1.85],
		"characters/guard_swat.glb": [1.82, 2.05],
	}

	for path: String in chars:
		var p: String = ASSETS_DIR + path
		assert_true(FileAccess.file_exists(p), "[%s] Existe" % path)
		var sc: PackedScene = load(p) as PackedScene
		assert_not_null(sc, "[%s] Escena cargada" % path)
		var inst: Node3D = autofree(sc.instantiate() as Node3D)
		add_child_autofree(inst)
		await wait_physics_frames(1)

		var aabb: AABB = _compute_visual_aabb(inst)
		var limits: Array = chars[path]
		assert_almost_eq(aabb.size.y, float(limits[0]), 0.05, "[%s] Altura humana" % path)
		assert_lt(aabb.size.x, float(limits[1]), "[%s] Envergadura" % path)
		assert_almost_eq(aabb.position.y, 0.0, 0.02, "[%s] Base en Y=0.0" % path)
		assert_almost_eq(aabb.position.x + aabb.size.x / 2.0, 0.0, 0.05, "[%s] Centrado X" % path)
