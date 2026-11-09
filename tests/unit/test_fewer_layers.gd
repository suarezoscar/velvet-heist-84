extends GutTest
## #191: menos capas: trazo solo en lo jugable, modelos de color plano, sin trazo en la
## arquitectura, cono del haz de la linterna y efectos de pantalla reducidos.

const LOOK: NightLook = preload("res://data/visual/night_look.tres")


func _look() -> NightLook:
	var look: NightLook = NightLook.new()
	look.outline_only_gameplay = true
	look.flat_textures = true
	return look


func _mesh_with(mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.set_surface_override_material(0, mat)
	return mesh


func test_outline_only_on_gameplay_nodes() -> void:
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	var decor: MeshInstance3D = _mesh_with(StandardMaterial3D.new())
	root.add_child(decor)
	var loot: Node3D = Node3D.new()
	loot.add_to_group(&"heist_targets")
	root.add_child(loot)
	var piece: MeshInstance3D = _mesh_with(StandardMaterial3D.new())
	loot.add_child(piece)
	var converter: CelConverter = CelConverter.new()
	converter.look = _look()
	converter.convert_tree(root)
	assert_null(decor.get_active_material(0).next_pass, "El decorado, sin trazo")
	assert_not_null(piece.get_active_material(0).next_pass, "El botín conserva el trazo")


func test_flat_textures_use_the_average_color() -> void:
	var image: Image = Image.create(2, 1, false, Image.FORMAT_RGB8)
	image.set_pixel(0, 0, Color(1, 0, 0))
	image.set_pixel(1, 0, Color(0, 0, 1))
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(image)
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	var mesh: MeshInstance3D = _mesh_with(mat)
	root.add_child(mesh)
	var converter: CelConverter = CelConverter.new()
	converter.look = _look()
	converter.convert_tree(root)
	var cel: ShaderMaterial = mesh.get_active_material(0) as ShaderMaterial
	assert_null(cel.get_shader_parameter(&"albedo_texture"), "Sin textura")
	var albedo: Color = cel.get_shader_parameter(&"albedo")
	assert_almost_eq(albedo.r, albedo.b, 0.05, "Mezcla de rojo y azul")
	assert_gt(albedo.r, 0.2)


func test_flashlight_cone_follows_the_light() -> void:
	var light: SpotLight3D = SpotLight3D.new()
	add_child_autofree(light)
	light.spot_range = 9.0
	light.spot_angle = 32.0
	var cone: MeshInstance3D = FlashlightCone.attach(light, 0.02)
	assert_not_null(cone)
	assert_eq(cone.get_parent(), light, "Hijo de la luz: se apaga y se oculta con ella")
	assert_almost_eq((cone.mesh as CylinderMesh).height, 9.0 * FlashlightCone.LENGTH_SHARE, 0.001)
	assert_null(FlashlightCone.attach(light, 0.0), "Con 0 no hay cono")


func test_night_look_has_fewer_layers() -> void:
	assert_false(LOOK.ssr_enabled)
	assert_false(LOOK.sdfgi_enabled)
	assert_false(LOOK.volumetric_fog_enabled)
	assert_false(LOOK.outline_architecture)
	assert_true(LOOK.outline_only_gameplay)
	assert_lte(LOOK.outline_width, 0.025, "Trazo fino")
	assert_gt(LOOK.beam_cone_alpha, 0.0, "Sin niebla volumétrica, el haz lleva su cono")


## #194: brillo frío de las piezas desde el NightLook (sin pantalla no se pone la capa)
func test_piece_glow_material() -> void:
	assert_gt(LOOK.piece_glow_rim, 0.0, "Brillo activo")
	var glow: ShaderMaterial = TargetPieceLook.glow_material()
	assert_eq(glow.get_shader_parameter(&"glow_rim"), LOOK.piece_glow_rim)
	assert_eq(glow.get_shader_parameter(&"glow_base"), LOOK.piece_glow_base)
	assert_eq(glow.shader, TargetPieceLook.GLOW_SHADER)


## #178: las piezas con color en la tabla pierden su textura fotográfica y llevan ese color
func test_piece_flat_color_from_the_table() -> void:
	var colors: Dictionary = MuseumKitBuilder.FINISHES.piece_colors
	assert_true(colors.has("marble_bust"), "La tabla tiene el busto")
	var model: Node3D = Node3D.new()
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	var textured: StandardMaterial3D = StandardMaterial3D.new()
	textured.albedo_texture = PlaceholderTexture2D.new()
	mesh.set_surface_override_material(0, textured)
	model.add_child(mesh)
	add_child_autofree(model)
	TargetPieceLook.flatten(model, colors["marble_bust"])
	var flat: StandardMaterial3D = mesh.get_active_material(0) as StandardMaterial3D
	assert_null(flat.albedo_texture, "Sin textura")
	assert_eq(flat.albedo_color, colors["marble_bust"])
