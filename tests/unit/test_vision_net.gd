## @file test_vision_net.gd
## Visión y niebla (FEAT-020), casos de la revisión: qué envía el servidor en cada snapshot,
## que no quede un haz congelado en el cliente del ladrón, el camino sin red, el borde de
## dark_sight_radius, la niebla bajo lo transparente y el botín movido en la niebla.
extends GutTest

const RULES: VisionProfile = preload("res://data/balance/vision_rules.tres")
const FIXTURE_PATH: String = "res://tests/fixtures/level_small.json"
const THIEF_SCENE: PackedScene = preload("res://scenes/entities/thief_player.tscn")
const GUARD_SCENE: PackedScene = preload("res://scenes/entities/guard_player.tscn")
const LOOT_SCENE: PackedScene = preload("res://scenes/entities/loot_cash_item.tscn")
const CAMERA_SCENE: PackedScene = preload("res://scenes/entities/security_camera.tscn")

var _saved_state: GameManager.MatchState


func before_each() -> void:
	_saved_state = GameManager.current_state
	GameManager.current_state = GameManager.MatchState.IN_PROGRESS


func after_each() -> void:
	GameManager.current_state = _saved_state


## Mapa sin nivel con un ladrón y guard_count guardias
func _map(guard_count: int) -> HeistMap3D:
	var map: HeistMap3D = HeistMap3D.new()
	map.thief = THIEF_SCENE.instantiate() as ThiefController3D
	map.add_child(map.thief)
	for i: int in range(guard_count):
		var guard: GuardController3D = GUARD_SCENE.instantiate() as GuardController3D
		map.add_child(guard)
		map.guards.append(guard)
	add_child_autofree(map)
	return map


## Nivel pequeño con física, para los casos con línea de visión; bajo parent o bajo el test
func _level(parent: Node = null) -> Node3D:
	var root: Node3D = Node3D.new()
	if parent != null:
		parent.add_child(root)
	else:
		add_child_autofree(root)
	LevelArchitectureBuilder.build(LevelData.load_json(FIXTURE_PATH), root)
	return root


func _body(guard: GuardController3D) -> Node3D:
	return guard.get_node("VisualRoot") as Node3D


func test_beam_does_not_freeze_when_guard_leaves_snapshot() -> void:
	var map: HeistMap3D = _map(2)
	var guard: GuardController3D = map.guards[0]
	guard.apply_flashlight_state(true)
	NetViewModes.apply(map, &"thief", {&"guard_1": {"beam_only": true}})
	assert_true(guard.flashlight_on, "Con beam_only se ve el haz")
	assert_false(_body(guard).visible)
	NetViewModes.apply(map, &"thief", {})
	assert_false(guard.flashlight_on, "Fuera del snapshot no queda un haz congelado")
	assert_false(_body(guard).visible)


func test_guard_without_role_is_hidden_for_thief() -> void:
	var map: HeistMap3D = _map(NetConfig.ROLES.size())
	NetViewModes.apply(map, &"thief", {&"guard_1": {}, &"guard_2": {}})
	assert_true(_body(map.guards[0]).visible)
	assert_false(_body(map.guards[map.guards.size() - 1]).visible, "Sin rol: oculto")


func test_build_filters_for_thief_and_opens_at_end() -> void:
	var map: HeistMap3D = _map(2)
	var session: NetSession = NetSession.new()
	session.map = map
	autofree(session)
	var views: Dictionary = {
		"guards": {&"guard_1": &"", &"guard_2": &""},
		"thief": {&"guard_1": &"", &"guard_2": &"beam"},
	}
	var states: Dictionary = NetSnapshots.build(session, &"thief", views, false)
	assert_false(states.has(&"guard_1"), "El ladrón no recibe al guardia que no ve")
	var beam: Dictionary = states[&"guard_2"]
	assert_true(beam.has("beam_only"))
	for key: String in beam:
		assert_has(NetSnapshots.BEAM_KEYS + ["beam_only"], key, "beam_only solo lleva el haz")
	var guard_states: Dictionary = NetSnapshots.build(session, &"guard_1", views, false)
	assert_false(guard_states.has(&"thief"), "El guardia no recibe al ladrón que no percibe")
	assert_true(guard_states.has(&"guard_2"), "Los guardias se ven entre sí")
	var open: Dictionary = NetSnapshots.build(session, &"thief", views, true)
	assert_eq(open.size(), 2, "Partida terminada: llega todo")
	assert_false((open[&"guard_1"] as Dictionary).has("perceiving"), "Nunca la percepción")


func test_missing_data_hides() -> void:
	var views: Dictionary = {"guards": {}, "thief": {}}
	assert_eq(NetSnapshots.mark_for(&"thief", &"guard_1", views), &"hidden", "Sin vista")
	assert_eq(NetSnapshots.mark_for(&"guard_1", &"thief", views), &"hidden")
	assert_eq(NetSnapshots.mark_for(&"spectator", &"guard_1", views), &"hidden", "Sin bando")


func test_dark_sight_edge() -> void:
	var root: Node3D = _level()
	var thief: ThiefController3D = THIEF_SCENE.instantiate() as ThiefController3D
	var guard: GuardController3D = GUARD_SCENE.instantiate() as GuardController3D
	for actor: PlayerBase3D in [thief, guard]:
		root.add_child(actor)
		actor.set_physics_process(false)
	thief.global_position = Vector3(0.5, 0.0, 4.5)
	guard.apply_flashlight_state(false)
	var no_lamps: Array[Lamp3D] = []
	guard.global_position = Vector3(0.5 + RULES.dark_sight_radius - 0.01, 0.0, 4.5)
	await wait_physics_frames(2)
	assert_true(VisionLogic.thief_sees_guard(thief, guard, no_lamps), "A dark_sight − 0,01 m")
	guard.global_position = Vector3(0.5 + RULES.dark_sight_radius + 0.01, 0.0, 4.5)
	assert_false(VisionLogic.thief_sees_guard(thief, guard, no_lamps), "A dark_sight + 0,01 m")


func test_offline_thief_sees_only_visible_guards() -> void:
	var map: HeistMap3D = _map(2)
	_level(map)
	map.thief.set_physics_process(false)
	map.thief.global_position = Vector3(0.5, 0.0, 4.5)
	for guard: GuardController3D in map.guards:
		guard.set_physics_process(false)
		guard.apply_flashlight_state(false)
	map.guards[0].global_position = Vector3(2.0, 0.0, 4.5)
	map.guards[1].global_position = Vector3(10.0, 0.0, 4.5)
	await wait_physics_frames(2)
	map.local_player = map.thief
	map.call("_update_guards_local_visibility", [] as Array[Lamp3D])
	assert_true(_body(map.guards[0]).visible, "Cerca: visible")
	assert_false(_body(map.guards[1]).visible, "Tras el muro y a oscuras: oculto")
	GameManager.current_state = GameManager.MatchState.THIEF_CAPTURED
	map.call("_update_guards_local_visibility", [] as Array[Lamp3D])
	assert_true(_body(map.guards[1]).visible, "Al acabar se ve todo")


func test_fog_draws_under_transparent_and_not_on_cctv() -> void:
	var fog: FogOfWar3D = FogOfWar3D.new()
	add_child_autofree(fog)
	var material: ShaderMaterial = fog.material_override as ShaderMaterial
	assert_eq(material.render_priority, Material.RENDER_PRIORITY_MIN, "Lo transparente, encima")
	var camera: SecurityCamera3D = CAMERA_SCENE.instantiate() as SecurityCamera3D
	add_child_autofree(camera)
	assert_false(camera.internal_cam.get_cull_mask_value(FogOfWar3D.FOG_LAYER), "Sin niebla")


func test_loot_moved_in_fog_is_hidden_at_new_spot() -> void:
	var root: Node3D = _level()
	var thief: ThiefController3D = THIEF_SCENE.instantiate() as ThiefController3D
	root.add_child(thief)
	thief.set_physics_process(false)
	thief.global_position = Vector3(4.0, 0.0, 4.0)
	var fog: FogOfWar3D = FogOfWar3D.new()
	add_child_autofree(fog)
	fog.viewer = thief
	var memory: FogMemory = FogMemory.new()
	memory.fog = fog
	root.add_child(memory)
	var loot: LootItem3D = LOOT_SCENE.instantiate() as LootItem3D
	root.add_child(loot)
	loot.global_position = Vector3(11.0, 0.0, 4.5)
	await wait_physics_frames(2)
	fog.recompute()
	memory.sample()
	loot.global_position = Vector3(11.0, 0.0, 6.0)
	memory.sample()
	assert_eq(memory.ghost_count(), 1, "Fantasma en el sitio viejo")
	assert_true(memory.is_hidden(loot), "Y el objeto movido no se ve en el nuevo")
