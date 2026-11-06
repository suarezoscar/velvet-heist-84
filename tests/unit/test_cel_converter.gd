extends GutTest

const LOOK: NightLook = preload("res://data/visual/night_look.tres")
const THIEF_SCENE: PackedScene = preload("res://scenes/entities/thief_player.tscn")
const LOOT_SCENE: PackedScene = preload("res://scenes/entities/loot_cash_item.tscn")


func _mesh_with(mat: Material) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.material = mat
	mesh.mesh = box
	return autofree(mesh)


func _converter() -> CelConverter:
	var converter: CelConverter = CelConverter.new()
	converter.look = LOOK
	return converter


func test_copia_color_textura_y_contorno() -> void:
	var source: StandardMaterial3D = StandardMaterial3D.new()
	source.albedo_color = Color(0.2, 0.4, 0.6)
	source.albedo_texture = PlaceholderTexture2D.new()
	source.roughness = 0.3
	var mesh: MeshInstance3D = _mesh_with(source)
	var root: Node3D = autofree(Node3D.new())
	root.add_child(mesh)
	assert_eq(_converter().convert_tree(root), 1)
	var cel: ShaderMaterial = mesh.get_active_material(0) as ShaderMaterial
	assert_not_null(cel, "pasa a cel_toon")
	assert_eq(cel.get_shader_parameter(&"albedo"), source.albedo_color)
	assert_eq(cel.get_shader_parameter(&"albedo_texture"), source.albedo_texture)
	assert_almost_eq(float(cel.get_shader_parameter(&"roughness")), 0.3, 0.001)
	assert_eq(cel.next_pass, CelConverter.outline_material(null, true), "con contorno de caja")


func test_respeta_lo_transparente_y_lo_sin_luz() -> void:
	var glass: StandardMaterial3D = StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var marker: StandardMaterial3D = StandardMaterial3D.new()
	marker.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var root: Node3D = autofree(Node3D.new())
	root.add_child(_mesh_with(glass))
	root.add_child(_mesh_with(marker))
	var skipped: Node3D = Node3D.new()
	skipped.add_to_group(CelConverter.SKIP_GROUP)
	skipped.add_child(_mesh_with(StandardMaterial3D.new()))
	root.add_child(skipped)
	assert_eq(_converter().convert_tree(root), 0)


func test_suelo_plano_sin_contorno_y_pulido() -> void:
	var floor_mat: StandardMaterial3D = StandardMaterial3D.new()
	floor_mat.uv1_triplanar = true
	floor_mat.uv1_world_triplanar = true
	floor_mat.uv1_scale = Vector3(0.25, 0.25, 0.25)
	floor_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var mesh: MeshInstance3D = _mesh_with(floor_mat)
	var root: Node3D = autofree(Node3D.new())
	root.add_child(mesh)
	_converter().convert_tree(root)
	var cel: ShaderMaterial = mesh.get_active_material(0) as ShaderMaterial
	assert_true(bool(cel.get_shader_parameter(&"world_planar")))
	assert_true(bool(cel.get_shader_parameter(&"texture_nearest")))
	assert_null(cel.next_pass)
	assert_almost_eq(float(cel.get_shader_parameter(&"roughness")), LOOK.floor_roughness, 0.001)


func test_compartido_se_convierte_una_vez() -> void:
	var shared: StandardMaterial3D = StandardMaterial3D.new()
	var a: MeshInstance3D = _mesh_with(shared)
	var b: MeshInstance3D = _mesh_with(shared)
	var root: Node3D = autofree(Node3D.new())
	root.add_child(a)
	root.add_child(b)
	_converter().convert_tree(root)
	assert_same(a.get_active_material(0), b.get_active_material(0))


func test_set_albedo_con_y_sin_cel() -> void:
	var plain: MeshInstance3D = _mesh_with(StandardMaterial3D.new())
	CelConverter.set_albedo(plain, Color.RED)
	assert_eq(CelConverter.albedo_of(plain.get_active_material(0)), Color.RED)
	var root: Node3D = autofree(Node3D.new())
	var cel: MeshInstance3D = _mesh_with(StandardMaterial3D.new())
	root.add_child(cel)
	_converter().convert_tree(root)
	CelConverter.set_albedo(cel, Color.GREEN)
	assert_eq(CelConverter.albedo_of(cel.get_active_material(0)), Color.GREEN)


func test_ladron_con_textura_y_borde() -> void:
	var thief: Node3D = add_child_autofree(THIEF_SCENE.instantiate()) as Node3D
	assert_gt(_converter().convert_tree(thief, LOOK.thief_rim), 0)
	for node: Node in thief.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		var cel: ShaderMaterial = mesh.get_active_material(0) as ShaderMaterial
		gut.p("%s %s" % [mesh.name, cel])
		if cel == null:
			continue
		assert_not_null(cel.get_shader_parameter(&"albedo_texture"), "%s con textura" % mesh.name)
		assert_gt(float(cel.get_shader_parameter(&"rim_strength")), 0.0)


func test_material_override_y_mascara_de_emision() -> void:
	var source: StandardMaterial3D = StandardMaterial3D.new()
	source.emission_enabled = true
	source.emission = Color.WHITE
	source.emission_texture = PlaceholderTexture2D.new()
	var mesh: MeshInstance3D = _mesh_with(StandardMaterial3D.new())
	mesh.material_override = source
	var root: Node3D = autofree(Node3D.new())
	root.add_child(mesh)
	assert_eq(_converter().convert_tree(root), 1)
	var cel: ShaderMaterial = mesh.material_override as ShaderMaterial
	assert_not_null(cel, "el override también pasa a cel")
	assert_eq(cel.get_shader_parameter(&"emission_texture"), source.emission_texture)


func test_cuerpo_del_ladron_convertido() -> void:
	var thief: Node3D = add_child_autofree(THIEF_SCENE.instantiate()) as Node3D
	_converter().convert_tree(thief, LOOK.thief_rim)
	var body: MeshInstance3D = thief.find_child("Ch45", true, false) as MeshInstance3D
	assert_not_null(body)
	var cel: ShaderMaterial = body.get_active_material(0) as ShaderMaterial
	assert_not_null(cel, "el cuerpo pasa a cel")
	assert_not_null(cel.next_pass, "y lleva contorno aunque traiga emisión con máscara")


func test_piloto_emisivo_sin_contorno() -> void:
	var pilot: StandardMaterial3D = StandardMaterial3D.new()
	pilot.emission_enabled = true
	pilot.emission = Color.RED
	var mesh: MeshInstance3D = _mesh_with(pilot)
	var root: Node3D = autofree(Node3D.new())
	root.add_child(mesh)
	_converter().convert_tree(root)
	assert_null((mesh.get_active_material(0) as ShaderMaterial).next_pass)


func test_fantasma_copia_el_aspecto() -> void:
	var real: Node3D = autofree(Node3D.new())
	var real_mesh: MeshInstance3D = _mesh_with(StandardMaterial3D.new())
	real_mesh.name = "Mesh"
	real.add_child(real_mesh)
	_converter().convert_tree(real)
	var ghost: Node3D = autofree(Node3D.new())
	var ghost_mesh: MeshInstance3D = _mesh_with(StandardMaterial3D.new())
	ghost_mesh.name = "Mesh"
	ghost.add_child(ghost_mesh)
	CelConverter.copy_look(real, ghost)
	assert_same(ghost_mesh.get_active_material(0), real_mesh.get_active_material(0))
	assert_not_null(ghost_mesh.get_active_material(0).next_pass)


func test_tinte_de_pieza_sobre_cel() -> void:
	var model: Node3D = autofree(Node3D.new())
	var source: StandardMaterial3D = StandardMaterial3D.new()
	source.albedo_color = Color(0.5, 0.5, 0.5)
	model.add_child(_mesh_with(source))
	_converter().convert_tree(model)
	TargetPieceLook._tint(model, Color(1.0, 0.0, 0.0))
	var mesh: MeshInstance3D = model.get_child(0) as MeshInstance3D
	var tinted: Color = CelConverter.albedo_of(mesh.get_active_material(0))
	assert_almost_eq(tinted.r, 0.5, 0.001)
	assert_almost_eq(tinted.g, 0.0, 0.001)


func test_servidor_dedicado_no_toca_nada() -> void:
	var saved: bool = NetManager.is_dedicated_server
	NetManager.is_dedicated_server = true
	var map: HeistMap3D = autofree(HeistMap3D.new())
	var world: WorldEnvironment = WorldEnvironment.new()
	world.name = "WorldEnvironment"
	var env: Environment = Environment.new()
	world.environment = env
	map.add_child(world)
	var mesh: MeshInstance3D = _mesh_with(StandardMaterial3D.new())
	map.add_child(mesh)
	NightEnvironmentSetup.apply(map)
	NetManager.is_dedicated_server = saved
	assert_same(world.environment, env, "sin entorno nuevo")
	assert_true(mesh.get_active_material(0) is StandardMaterial3D, "sin convertir")


func test_fantasma_de_fog_memory_igual_que_el_botin() -> void:
	var loot: Node3D = add_child_autofree(LOOT_SCENE.instantiate()) as Node3D
	_converter().convert_tree(loot)
	var memory: FogMemory = add_child_autofree(FogMemory.new()) as FogMemory
	var record: Dictionary = {
		"xform": loot.global_transform, "scene": loot.scene_file_path, "ref": weakref(loot)
	}
	var ghost: Node3D = memory._make_ghost(record)
	for node: Node in ghost.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		var real: MeshInstance3D = loot.get_node(ghost.get_path_to(mesh)) as MeshInstance3D
		assert_same(mesh.get_active_material(0), real.get_active_material(0), mesh.name)
		assert_not_null(mesh.get_active_material(0).next_pass, "%s con contorno" % mesh.name)
