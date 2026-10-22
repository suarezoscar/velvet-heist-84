## @file test_stealth_mechanics.gd
## Suite de pruebas unitarias con GUT para los modelos y las pistas de animación de FEAT-005.
extends GutTest

const THIEF_SCENE_PATH: String = "res://scenes/entities/thief_player.tscn"
const GUARD_SCENE_PATH: String = "res://scenes/entities/guard_player.tscn"

const EXPECTED_ACTION_ANIMATIONS: Array[StringName] = [
	&"walk",
	&"tiptoe_walk",
	&"sneak_walk",
	&"crouch_walk",
	&"crouch_to_prone",
	&"prone_idle",
	&"prone_forward",
	&"taking_cover_idle",
	&"cover_idle",
	&"cover_sneak_left",
	&"cover_sneak_right",
]


func test_criterio_1_thief_scene_model_and_anchors() -> void:
	var thief_scene: PackedScene = load(THIEF_SCENE_PATH) as PackedScene
	assert_not_null(thief_scene, "La escena thief_player.tscn existe y carga limpiamente")

	var thief: ThiefController3D = autofree(thief_scene.instantiate() as ThiefController3D)
	assert_not_null(thief, "ThiefController3D instanciado con exito")
	add_child_autofree(thief)

	var visual_root: Node3D = thief.visual_root
	assert_not_null(visual_root, "thief.visual_root esta asignado")
	assert_eq(visual_root.name, &"VisualRoot", "El nodo visual se llama VisualRoot")

	# Comprobar presencia de AnimationPlayer en el modelo importado
	var anim_player: AnimationPlayer = (
		visual_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	)
	assert_not_null(anim_player, "El modelo thief_crypto.glb contiene AnimationPlayer")

	# Comprobar ancla CarryAnchor3D en manos, delante del pecho (-Z es el frente en Godot)
	var carry_anchor: Node3D = thief.find_child("CarryAnchor3D", true, false) as Node3D
	assert_not_null(carry_anchor, "CarryAnchor3D presente en thief_player")
	assert_almost_eq(carry_anchor.position.y, 0.85, 0.05, "Altura Y de CarryAnchor3D aprox 0.85m")
	assert_almost_eq(carry_anchor.position.z, -0.45, 0.06, "CarryAnchor3D delante (-Z) aprox 0.45m")


func test_criterio_1_guard_scene_model_and_anchors() -> void:
	var guard_scene: PackedScene = load(GUARD_SCENE_PATH) as PackedScene
	assert_not_null(guard_scene, "La escena guard_player.tscn existe y carga limpiamente")

	var guard: GuardController3D = autofree(guard_scene.instantiate() as GuardController3D)
	assert_not_null(guard, "GuardController3D instanciado con exito")
	add_child_autofree(guard)

	var visual_root: Node3D = guard.find_child("VisualRoot", false, false) as Node3D
	assert_not_null(visual_root, "VisualRoot presente en guard_player")

	var anim_player: AnimationPlayer = (
		visual_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	)
	assert_not_null(anim_player, "El modelo guard_swat.glb contiene AnimationPlayer")

	# Comprobar MagliteSpotLight a la altura del pecho, delante del cuerpo (-Z)
	var maglite: SpotLight3D = guard.maglite_light
	assert_not_null(maglite, "MagliteSpotLight asignada en guard_player")
	assert_almost_eq(maglite.position.y, 0.90, 0.05, "Altura Y de Maglite aprox 0.90m")
	assert_almost_eq(maglite.position.z, -0.40, 0.05, "Maglite delante (-Z) aprox 0.40m")


func test_criterio_6_all_11_animation_tracks_exist_in_glb_assets() -> void:
	var thief_scene: PackedScene = load(THIEF_SCENE_PATH) as PackedScene
	var thief: Node = autofree(thief_scene.instantiate())
	add_child_autofree(thief)
	var thief_anim: AnimationPlayer = (
		thief.find_child("AnimationPlayer", true, false) as AnimationPlayer
	)
	assert_not_null(thief_anim, "AnimationPlayer encontrado en thief_crypto.glb")
	for anim_name: StringName in EXPECTED_ACTION_ANIMATIONS:
		assert_true(
			thief_anim.has_animation(anim_name), "thief_crypto tiene la pista: %s" % anim_name
		)
	assert_true(
		(
			thief_anim.has_animation(&"Armature|mixamo_com|Layer0")
			or thief_anim.has_animation(&"Armature|mixamo.com|Layer0")
		),
		"thief_crypto tiene la pose base"
	)

	var guard_scene: PackedScene = load(GUARD_SCENE_PATH) as PackedScene
	var guard: Node = autofree(guard_scene.instantiate())
	add_child_autofree(guard)
	var guard_anim: AnimationPlayer = (
		guard.find_child("AnimationPlayer", true, false) as AnimationPlayer
	)
	assert_not_null(guard_anim, "AnimationPlayer encontrado en guard_swat.glb")

	for anim_name: StringName in EXPECTED_ACTION_ANIMATIONS:
		assert_true(
			guard_anim.has_animation(anim_name), "guard_swat tiene la pista: %s" % anim_name
		)
	assert_true(
		(
			guard_anim.has_animation(&"Armature|mixamo_com|Layer0")
			or guard_anim.has_animation(&"Armature|mixamo.com|Layer0")
		),
		"guard_swat tiene la pose base"
	)
