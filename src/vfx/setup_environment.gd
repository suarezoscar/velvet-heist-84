## @file setup_environment.gd
## Entorno nocturno del museo (#181, fase 1): cielo synthwave procedural (night_sky.gdshader),
## luz ambiente plana azul noche (la banda de sombra del cel-shading), SSR para los suelos, SDFGI,
## glow suave para neones y niebla volumétrica para el haz de las linternas. También la luna y
## el paso de todos los materiales del mapa a cel-shading (CelConverter). Los valores, en
## data/visual/night_look.tres. Un servidor dedicado no dibuja: no hace nada.
class_name NightEnvironmentSetup
extends RefCounted

const LOOK: NightLook = preload("res://data/visual/night_look.tres")
const SKY_SHADER: Shader = preload("res://assets/shaders/night_sky.gdshader")


## Aplica el aspecto nocturno a un mapa ya construido
static func apply(map: HeistMap3D, look: NightLook = LOOK) -> void:
	if NetManager.is_dedicated_server:
		return
	var world: WorldEnvironment = map.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world != null:
		world.environment = build_environment(look, world.environment)
	var moon: DirectionalLight3D = map.get_node_or_null("MoonLight") as DirectionalLight3D
	if moon != null:
		moon.light_color = look.moon_color
		moon.light_energy = look.moon_energy
	for light: Node in map.find_children("*", "Light3D", true, false):
		(light as Light3D).shadow_blur = look.shadow_blur  # #189: sombras suaves
	CelConverter.outline_material(look)
	WallXRay.apply_look(look)
	var converter: CelConverter = CelConverter.new()
	converter.look = look
	if map.thief != null:
		converter.convert_tree(map.thief, look.thief_rim)
	for guard: GuardController3D in map.guards:
		converter.convert_tree(guard, look.guard_rim)
	converter.convert_tree(map)


## Environment nocturno a partir de base (se duplica: la escena no se toca)
static func build_environment(look: NightLook, base: Environment = null) -> Environment:
	var env: Environment = base.duplicate() as Environment if base != null else Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = _sky(look)
	env.background_energy_multiplier = look.sky_energy
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = look.night_shadow.lerp(look.night_lit, 0.35)
	env.ambient_light_energy = look.ambient_energy
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ssr_enabled = look.ssr_enabled
	env.ssr_max_steps = 48
	env.ssao_intensity = look.ssao_intensity  # #191: suave
	env.sdfgi_enabled = look.sdfgi_enabled
	env.sdfgi_energy = look.sdfgi_energy
	env.sdfgi_use_occlusion = true
	env.glow_enabled = true
	env.glow_intensity = look.glow_intensity
	env.glow_bloom = look.glow_bloom
	env.glow_hdr_threshold = look.glow_hdr_threshold
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = false  # la niebla la pone la volumétrica
	env.volumetric_fog_enabled = look.volumetric_fog_enabled
	env.volumetric_fog_density = look.volumetric_fog_density
	env.volumetric_fog_albedo = look.volumetric_fog_albedo
	env.volumetric_fog_sky_affect = 0.0  # el cielo synthwave no se lava
	return env


static func _sky(look: NightLook) -> Sky:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = SKY_SHADER
	mat.set_shader_parameter(&"top_color", look.night_deep)
	mat.set_shader_parameter(&"mid_color", look.night_shadow)
	mat.set_shader_parameter(&"low_color", look.cloth)
	mat.set_shader_parameter(&"glow_magenta", look.neon_pink)
	mat.set_shader_parameter(&"glow_cyan", look.neon_cyan)
	mat.set_shader_parameter(&"window_color", look.lamp_amber)
	var sky: Sky = Sky.new()
	sky.sky_material = mat
	return sky
