## @file test_stealth_mechanics.gd
## Suite de pruebas unitarias con GUT para FEAT-005 (Mecánicas de Sigilo, Posturas y Rigging).
## Valida los 7 criterios de aceptación: modelos esqueléticos, enum Stance y cápsulas dinámicas,
## acústica TIPTOE/PRONE, evasión de láseres en PRONE, mecánica WALL_COVER y animación esqueletal.
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

func _create_player(pos: Vector3 = Vector3.ZERO) -> PlayerBase3D:
	var player: PlayerBase3D = autofree(PlayerBase3D.new())
	player.position = pos
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.height = 1.6
	capsule.radius = 0.35
	col.shape = capsule
	col.position = Vector3(0.0, 0.8, 0.0)
	player.add_child(col)
	add_child_autofree(player)
	return player

func _create_solid_box(pos: Vector3, size: Vector3) -> StaticBody3D:
	var body: StaticBody3D = autofree(StaticBody3D.new())
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	var col: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	col.shape = box
	body.add_child(col)
	add_child_autofree(body)
	return body

# ------------------------------------------------------------------------------
# Criterio 1: Modelos definitivos thief_crypto.glb y guard_swat.glb en escenas
# ------------------------------------------------------------------------------

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

	# Comprobar ancla CarryAnchor3D en manos (aprox Vector3(0.0, 0.85, 0.45))
	var carry_anchor: Node3D = thief.find_child("CarryAnchor3D", true, false) as Node3D
	assert_not_null(carry_anchor, "CarryAnchor3D presente en thief_player")
	assert_almost_eq(carry_anchor.position.y, 0.85, 0.05, "Altura Y de CarryAnchor3D aprox 0.85m")
	assert_almost_eq(carry_anchor.position.z, 0.45, 0.06, "Profundidad Z de CarryAnchor3D aprox 0.45m")

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

	# Comprobar MagliteSpotLight a la altura del pecho/hombro (Vector3(0.0, 0.9, 0.4))
	var maglite: SpotLight3D = guard.maglite_light
	assert_not_null(maglite, "MagliteSpotLight asignada en guard_player")
	assert_almost_eq(maglite.position.y, 0.90, 0.05, "Altura Y de Maglite aprox 0.90m")
	assert_almost_eq(maglite.position.z, 0.40, 0.05, "Profundidad Z de Maglite aprox 0.40m")

# ------------------------------------------------------------------------------
# Criterio 2: Enum Stance y dimensiones dinámicas de cápsula
# ------------------------------------------------------------------------------

func test_criterio_2_stance_enum_and_capsule_dimensions() -> void:
	var player: PlayerBase3D = _create_player()
	await wait_physics_frames(1)

	# 1. Postura inicial STAND
	assert_eq(player.get_stance(), PlayerBase3D.Stance.STAND, "Postura inicial es STAND")
	var capsule: CapsuleShape3D = player.collision_shape.shape as CapsuleShape3D
	assert_almost_eq(capsule.height, 1.60, 0.01, "STAND altura es 1.60m")
	assert_almost_eq(capsule.radius, 0.35, 0.01, "STAND radio es 0.35m")
	assert_almost_eq(player.collision_shape.transform.origin.y, 0.80, 0.01, "STAND origen Y es 0.80m")

	# 2. Transición a CROUCH
	watch_signals(player)
	var crouch_ok: bool = player.set_stance(PlayerBase3D.Stance.CROUCH)
	assert_true(crouch_ok, "set_stance(CROUCH) tiene exito")
	assert_signal_emitted(player, "stance_changed", "Se emitio señal stance_changed")
	capsule = player.collision_shape.shape as CapsuleShape3D
	assert_almost_eq(capsule.height, 1.00, 0.01, "CROUCH altura es 1.00m")
	assert_almost_eq(capsule.radius, 0.35, 0.01, "CROUCH radio es 0.35m")
	assert_almost_eq(player.collision_shape.transform.origin.y, 0.50, 0.01, "CROUCH origen Y es 0.50m")

	# 3. Transición a PRONE
	var prone_ok: bool = player.set_stance(PlayerBase3D.Stance.PRONE)
	assert_true(prone_ok, "set_stance(PRONE) tiene exito")
	capsule = player.collision_shape.shape as CapsuleShape3D
	assert_almost_eq(capsule.height, 0.40, 0.01, "PRONE altura es 0.40m")
	assert_almost_eq(capsule.radius, 0.20, 0.01, "PRONE radio es 0.20m")
	assert_almost_eq(player.collision_shape.transform.origin.y, 0.20, 0.01, "PRONE origen Y es 0.20m")

	# 4. Transición a TIPTOE
	var tiptoe_ok: bool = player.set_stance(PlayerBase3D.Stance.TIPTOE)
	assert_true(tiptoe_ok, "set_stance(TIPTOE) tiene exito")
	capsule = player.collision_shape.shape as CapsuleShape3D
	assert_almost_eq(capsule.height, 1.60, 0.01, "TIPTOE altura es 1.60m")
	assert_almost_eq(capsule.radius, 0.35, 0.01, "TIPTOE radio es 0.35m")
	assert_almost_eq(player.collision_shape.transform.origin.y, 0.80, 0.01, "TIPTOE origen Y es 0.80m")

# ------------------------------------------------------------------------------
# Criterio 3: Emisión de ruido nulo (0.0) en modo TIPTOE y PRONE
# ------------------------------------------------------------------------------

func test_criterio_3_tiptoe_and_prone_noise_emission() -> void:
	var player: PlayerBase3D = _create_player()
	await wait_physics_frames(1)

	# Multiplicadores numéricos especificados
	assert_eq(player.get_stance_noise_multiplier(), 1.0, "STAND multiplicador de ruido es 1.0")
	player.set_stance(PlayerBase3D.Stance.CROUCH)
	assert_almost_eq(player.get_stance_noise_multiplier(), 0.35, 0.01, "CROUCH multiplicador es 0.35")
	player.set_stance(PlayerBase3D.Stance.WALL_COVER)
	assert_almost_eq(
		player.get_stance_noise_multiplier(),
		0.15,
		0.01,
		"WALL_COVER multiplicador es 0.15"
	)

	# TIPTOE debe ser estrictamente 0.0
	player.set_stance(PlayerBase3D.Stance.TIPTOE)
	assert_eq(player.get_stance_noise_multiplier(), 0.0, "TIPTOE multiplicador de ruido es 0.0")

	# PRONE debe ser estrictamente 0.0
	player.set_stance(PlayerBase3D.Stance.PRONE)
	assert_eq(player.get_stance_noise_multiplier(), 0.0, "PRONE multiplicador de ruido es 0.0")

	# Verificar emisión a través de SignalBus
	var signal_bus: Node = get_node_or_null("/root/SignalBus")
	if signal_bus != null:
		watch_signals(signal_bus)
		player.set_stance(PlayerBase3D.Stance.TIPTOE)
		player._emit_step_sound()
		var signal_params: Array = get_signal_parameters(signal_bus, "noise_emitted_3d")
		assert_not_null(signal_params, "noise_emitted_3d fue emitido")
		if signal_params != null and signal_params.size() >= 2:
			var emitted_radius: float = float(signal_params[1])
			assert_almost_eq(emitted_radius, 0.0, 0.001, "Radio de ruido emitido en TIPTOE es 0.0m")

# ------------------------------------------------------------------------------
# Criterio 4: Modo PRONE pasa bajo rayo láser a 0.60m sin colisión
# ------------------------------------------------------------------------------

func test_criterio_4_prone_passes_under_laser_at_60cm() -> void:
	var player: PlayerBase3D = _create_player(Vector3.ZERO)
	player.collision_layer = 2 # Characters
	await wait_physics_frames(1)

	var space_state: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state

	# Rayo láser situado horizontalmente a Y = 0.60m, cruzando la posición del jugador
	var laser_from: Vector3 = Vector3(-2.0, 0.60, 0.0)
	var laser_to: Vector3 = Vector3(2.0, 0.60, 0.0)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(laser_from, laser_to)
	query.collision_mask = 2 # Characters

	# 1. En STAND (altura 1.6m, top 1.6m), colisiona con el láser
	player.set_stance(PlayerBase3D.Stance.STAND)
	await wait_physics_frames(1)
	var hit_stand: Dictionary = space_state.intersect_ray(query)
	assert_false(hit_stand.is_empty(), "STAND colisiona con rayo laser a 0.60m")

	# 2. En CROUCH (altura 1.0m, top 1.0m), colisiona con el láser
	player.set_stance(PlayerBase3D.Stance.CROUCH)
	await wait_physics_frames(1)
	var hit_crouch: Dictionary = space_state.intersect_ray(query)
	assert_false(hit_crouch.is_empty(), "CROUCH colisiona con rayo laser a 0.60m")

	# 3. En PRONE (altura 0.40m, top 0.40m), queda por debajo del láser (0.40m < 0.60m)
	player.set_stance(PlayerBase3D.Stance.PRONE)
	await wait_physics_frames(1)
	var hit_prone: Dictionary = space_state.intersect_ray(query)
	assert_true(hit_prone.is_empty(), "PRONE no colisiona con rayo laser a 0.60m (cruza libremente)")

	# Comprobar que la extensión vertical de la cápsula es inferior a 0.50m
	var capsule: CapsuleShape3D = player.collision_shape.shape as CapsuleShape3D
	var top_y: float = player.collision_shape.transform.origin.y + (capsule.height * 0.5)
	assert_lt(top_y, 0.50, "Extensión vertical en PRONE es menor a 0.50m (exacto: 0.40m)")

# ------------------------------------------------------------------------------
# Restricción de espacio superior: can_enter_stance(STAND) bloqueado con techo a 1.1m
# ------------------------------------------------------------------------------

func test_headroom_check_blocks_stand_under_low_ceiling() -> void:
	var player: PlayerBase3D = _create_player(Vector3.ZERO)
	# Crear techo sólido a 1.1m de altura (grosor 0.2m, centrado en Y = 1.2m, fondo en Y = 1.1m)
	var ceiling: StaticBody3D = _create_solid_box(Vector3(0.0, 1.2, 0.0), Vector3(3.0, 0.2, 3.0))
	assert_not_null(ceiling)
	await wait_physics_frames(2)

	player.set_stance(PlayerBase3D.Stance.PRONE)
	assert_eq(player.get_stance(), PlayerBase3D.Stance.PRONE)

	# 1. Intentar levantarse a STAND requiere 1.6m de altura; debe fallar por colisión a 1.1m
	var can_stand: bool = player.can_enter_stance(PlayerBase3D.Stance.STAND)
	assert_false(can_stand, "can_enter_stance(STAND) devuelve false bajo techo a 1.1m")

	var stand_attempt: bool = player.set_stance(PlayerBase3D.Stance.STAND)
	assert_false(stand_attempt, "set_stance(STAND) rechazado con techo a 1.1m")
	assert_eq(player.get_stance(), PlayerBase3D.Stance.PRONE, "El jugador permanece en PRONE")

	# 2. Agacharse a CROUCH requiere solo 1.0m de altura; debe permitirse bajo 1.1m
	var can_crouch: bool = player.can_enter_stance(PlayerBase3D.Stance.CROUCH)
	assert_true(can_crouch, "can_enter_stance(CROUCH) permitido bajo techo a 1.1m (requiere 1.0m)")

	var crouch_ok: bool = player.set_stance(PlayerBase3D.Stance.CROUCH)
	assert_true(crouch_ok, "set_stance(CROUCH) completado con exito")
	assert_eq(player.get_stance(), PlayerBase3D.Stance.CROUCH)

# ------------------------------------------------------------------------------
# Criterio 5: WALL_COVER detección de muro, alineación y cinemática lateral
# ------------------------------------------------------------------------------

func test_criterio_5_wall_cover_detection_and_lateral_kinematics() -> void:
	# Muro situado a 0.50m hacia -Z, orientado en el plano XZ (normal apunta hacia +Z)
	var wall: StaticBody3D = _create_solid_box(Vector3(0.0, 1.0, -0.6), Vector3(6.0, 3.0, 0.2))
	assert_not_null(wall)
	var player: PlayerBase3D = _create_player(Vector3.ZERO)
	player.look_target_position = Vector3(0.0, 0.0, -5.0)
	player.rotation.y = 0.0 # Mirando hacia -Z (Godot forward)
	await wait_physics_frames(2)

	# 1. Detección de muro con RayCast a < 0.7m
	var wall_hit: Dictionary = player.detect_wall_ahead(0.7)
	assert_false(wall_hit.is_empty(), "Muro detectado a < 0.7m con RayCast")

	# 2. Entrada en modo WALL_COVER y alineación
	var cover_ok: bool = player.set_stance(PlayerBase3D.Stance.WALL_COVER)
	assert_true(cover_ok, "Entrada en WALL_COVER concedida")
	assert_eq(player.get_stance(), PlayerBase3D.Stance.WALL_COVER)

	# Normal del muro obtenida
	var wall_normal: Vector3 = player.get_cover_wall_normal()
	assert_almost_eq(wall_normal.z, 1.0, 0.05, "Normal del muro orientada hacia +Z")
	assert_almost_eq(wall_normal.x, 0.0, 0.05, "Normal no tiene componente X")

	# Tangente del muro puramente transversal (eje X)
	var wall_tangent: Vector3 = player.get_cover_wall_tangent()
	assert_almost_eq(absf(wall_tangent.x), 1.0, 0.05, "Tangente alineada con el eje X del muro")
	assert_almost_eq(wall_tangent.z, 0.0, 0.05, "Tangente no penetra el muro en Z")

	# 3. Cinemática: movimiento proyectado sobre la tangente (puramente lateral)
	# Inyectar movimiento lateral respecto a la pared
	player.apply_input({
		"movement_vector": Vector2(1.0, 0.0)
	})
	player.simulate_movement(0.05)

	# La velocidad perpendicular (en Z) debe ser nula o absorbida por el muro
	assert_almost_eq(player.velocity.z, 0.0, 0.01, "Velocidad perpendicular al muro en Z es 0.0")
	# La velocidad tangencial (en X) absorbe el desplazamiento lateral
	assert_ne(player.velocity.x, 0.0, "Velocidad lateral sobre la tangente en X es activa")

# ------------------------------------------------------------------------------
# Criterio 6: CharacterAnimator3D mapea las 11 pistas de animación
# ------------------------------------------------------------------------------

func test_criterio_6_character_animator_state_mapping() -> void:
	var animator: CharacterAnimator3D = autofree(CharacterAnimator3D.new())
	add_child_autofree(animator)

	# STAND
	var stand_idle: StringName = animator.resolve_animation_name(PlayerBase3D.Stance.STAND, 0.0)
	assert_eq(
		stand_idle,
		&"Armature|mixamo.com|Layer0",
		"STAND en reposo mapea a Armature|mixamo.com|Layer0"
	)

	var stand_walk: StringName = animator.resolve_animation_name(PlayerBase3D.Stance.STAND, 3.0)
	assert_eq(stand_walk, &"walk", "STAND en movimiento mapea a walk")

	var stand_sneak: StringName = animator.resolve_animation_name(
		PlayerBase3D.Stance.STAND,
		2.0,
		false,
		true
	)
	assert_eq(stand_sneak, &"sneak_walk", "STAND con sneak mapea a sneak_walk")

	# TIPTOE
	var tiptoe_walk: StringName = animator.resolve_animation_name(PlayerBase3D.Stance.TIPTOE, 2.0)
	assert_eq(tiptoe_walk, &"tiptoe_walk", "TIPTOE en movimiento mapea a tiptoe_walk")

	# CROUCH
	var crouch_idle: StringName = animator.resolve_animation_name(PlayerBase3D.Stance.CROUCH, 0.0)
	assert_eq(crouch_idle, &"crouch_to_prone", "CROUCH en reposo mapea a crouch_to_prone")

	var crouch_walk: StringName = animator.resolve_animation_name(PlayerBase3D.Stance.CROUCH, 2.4)
	assert_eq(crouch_walk, &"crouch_walk", "CROUCH en movimiento mapea a crouch_walk")

	# PRONE
	var prone_idle: StringName = animator.resolve_animation_name(PlayerBase3D.Stance.PRONE, 0.0)
	assert_eq(prone_idle, &"prone_idle", "PRONE en reposo mapea a prone_idle")

	var prone_fwd: StringName = animator.resolve_animation_name(PlayerBase3D.Stance.PRONE, 1.2)
	assert_eq(prone_fwd, &"prone_forward", "PRONE en movimiento mapea a prone_forward")

	# WALL_COVER
	var cover_idle: StringName = animator.resolve_animation_name(PlayerBase3D.Stance.WALL_COVER, 0.0)
	assert_eq(cover_idle, &"cover_idle", "WALL_COVER en reposo mapea a cover_idle")

	var cover_left: StringName = animator.resolve_animation_name(
		PlayerBase3D.Stance.WALL_COVER,
		1.5,
		false,
		false,
		-0.8
	)
	assert_eq(cover_left, &"cover_sneak_left", "WALL_COVER lateral izquierdo mapea a cover_sneak_left")

	var cover_right: StringName = animator.resolve_animation_name(
		PlayerBase3D.Stance.WALL_COVER,
		1.5,
		false,
		false,
		0.8
	)
	assert_eq(
		cover_right,
		&"cover_sneak_right",
		"WALL_COVER lateral derecho mapea a cover_sneak_right"
	)

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
			thief_anim.has_animation(anim_name),
			"thief_crypto tiene la pista: %s" % anim_name
		)
	assert_true(
		thief_anim.has_animation(&"Armature|mixamo_com|Layer0")
		or thief_anim.has_animation(&"Armature|mixamo.com|Layer0"),
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
			guard_anim.has_animation(anim_name),
			"guard_swat tiene la pista: %s" % anim_name
		)
	assert_true(
		guard_anim.has_animation(&"Armature|mixamo_com|Layer0")
		or guard_anim.has_animation(&"Armature|mixamo.com|Layer0"),
		"guard_swat tiene la pose base"
	)

# ------------------------------------------------------------------------------
# Multiplicadores de velocidad por postura
# ------------------------------------------------------------------------------

func test_stance_speed_multipliers_and_kinematic_convergence() -> void:
	var player: PlayerBase3D = _create_player()
	await wait_physics_frames(1)

	assert_almost_eq(player.get_stance_speed_multiplier(), 1.00, 0.001)
	player.set_stance(PlayerBase3D.Stance.TIPTOE)
	assert_almost_eq(player.get_stance_speed_multiplier(), 0.45, 0.001)
	player.set_stance(PlayerBase3D.Stance.CROUCH)
	assert_almost_eq(player.get_stance_speed_multiplier(), 0.55, 0.001)
	player.set_stance(PlayerBase3D.Stance.PRONE)
	assert_almost_eq(player.get_stance_speed_multiplier(), 0.25, 0.001)
	player.set_stance(PlayerBase3D.Stance.WALL_COVER)
	assert_almost_eq(player.get_stance_speed_multiplier(), 0.40, 0.001)

	# Simular en CROUCH y verificar velocidad límite
	player.set_stance(PlayerBase3D.Stance.CROUCH)
	player.apply_input({"movement_vector": Vector2(1.0, 0.0)})
	for i in range(25):
		player.simulate_movement(0.05)

	var expected_crouch_speed: float = player.move_speed * 0.55
	var horizontal_speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	assert_almost_eq(
		horizontal_speed,
		expected_crouch_speed,
		0.1,
		"Velocidad horizontal converge a 55% de move_speed"
	)
