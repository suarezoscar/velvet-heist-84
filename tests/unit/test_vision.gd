## @file test_vision.gd
## Visión y niebla de guerra (FEAT-020, vision.md): línea de visión cortada solo por muros,
## cuándo el ladrón ve a un guardia, marcas de red, modos de vista del cliente, zona visible de
## la niebla y memoria del botín.
extends GutTest

const RULES: VisionProfile = preload("res://data/balance/vision_rules.tres")
const FIXTURE_PATH: String = "res://tests/fixtures/level_small.json"
const THIEF_SCENE: PackedScene = preload("res://scenes/entities/thief_player.tscn")
const GUARD_SCENE: PackedScene = preload("res://scenes/entities/guard_player.tscn")
const LOOT_SCENE: PackedScene = preload("res://scenes/entities/loot_cash_item.tscn")
const LAMP_SCENE: PackedScene = preload("res://scenes/entities/lamp.tscn")

var _root: Node3D = null
var _saved_state: GameManager.MatchState


func before_each() -> void:
	_saved_state = GameManager.current_state
	GameManager.current_state = GameManager.MatchState.IN_PROGRESS
	_root = Node3D.new()
	add_child_autofree(_root)
	LevelArchitectureBuilder.build(LevelData.load_json(FIXTURE_PATH), _root)


func after_each() -> void:
	GameManager.current_state = _saved_state


func _actor(scene: PackedScene, at: Vector3) -> PlayerBase3D:
	var actor: PlayerBase3D = scene.instantiate() as PlayerBase3D
	_root.add_child(actor)
	actor.set_physics_process(false)
	actor.global_position = at
	return actor


## Nivel pequeño: muro en x=8 (puerta D1 en z 2,4-3,6) y tabique T1 de x 2 a 5 en z=2
func test_only_walls_cut_line_of_sight() -> void:
	await wait_physics_frames(2)
	var space: PhysicsDirectSpaceState3D = _root.get_world_3d().direct_space_state
	assert_false(
		VisionLogic.wall_free(space, Vector3(7.0, 1.6, 4.5), Vector3(9.0, 1.6, 4.5)), "Muro"
	)
	assert_true(
		VisionLogic.wall_free(space, Vector3(7.0, 1.6, 3.0), Vector3(9.0, 1.6, 3.0)), "Puerta"
	)
	assert_false(
		VisionLogic.wall_free(space, Vector3(3.5, 1.6, 1.0), Vector3(3.5, 1.6, 3.0)), "Tabique"
	)
	assert_true(
		VisionLogic.wall_free(space, Vector3(5.0, 1.6, 4.0), Vector3(7.0, 1.6, 4.0)),
		"La mesa A_mesa no corta la vista"
	)


func test_thief_sees_guard_rules() -> void:
	var thief: ThiefController3D = _actor(THIEF_SCENE, Vector3(0.5, 0.0, 4.5)) as ThiefController3D
	var guard: GuardController3D = _actor(GUARD_SCENE, Vector3(7.5, 0.0, 4.5)) as GuardController3D
	await wait_physics_frames(2)
	var no_lamps: Array[Lamp3D] = []
	guard.apply_flashlight_state(true)
	assert_true(VisionLogic.thief_sees_guard(thief, guard, no_lamps), "Con linterna, a la vista")
	guard.apply_flashlight_state(false)
	assert_false(VisionLogic.thief_sees_guard(thief, guard, no_lamps), "A oscuras y lejos, no")
	assert_eq(VisionLogic.thief_view_of(thief, guard, no_lamps), &"", "Ni el haz")
	guard.global_position = Vector3(0.5 + RULES.dark_sight_radius - 0.2, 0.0, 4.5)
	assert_true(VisionLogic.thief_sees_guard(thief, guard, no_lamps), "A oscuras pero cerca")
	guard.global_position = Vector3(7.5, 0.0, 4.5)
	var lamp: Lamp3D = LAMP_SCENE.instantiate() as Lamp3D
	lamp.profile = load("res://data/balance/lamp_ceiling.tres") as LampProfile
	_root.add_child(lamp)
	lamp.global_position = Vector3(7.5, 3.0, 4.5)
	await wait_physics_frames(2)
	var lamps: Array[Lamp3D] = [lamp]
	assert_true(VisionLogic.thief_sees_guard(thief, guard, lamps), "Iluminado por una lámpara")


func test_wall_hides_guard_but_beam_stays() -> void:
	var thief: ThiefController3D = _actor(THIEF_SCENE, Vector3(6.0, 0.0, 4.5)) as ThiefController3D
	var guard: GuardController3D = _actor(GUARD_SCENE, Vector3(10.0, 0.0, 4.5)) as GuardController3D
	await wait_physics_frames(2)
	var no_lamps: Array[Lamp3D] = []
	guard.apply_flashlight_state(true)
	assert_false(VisionLogic.thief_sees_guard(thief, guard, no_lamps), "Tras el muro no lo ve")
	assert_eq(VisionLogic.thief_view_of(thief, guard, no_lamps), &"beam", "Pero ve el haz")


func test_net_marks() -> void:
	var views: Dictionary = {
		"guards": {&"guard_1": &"", &"guard_2": &"cctv"},
		"thief": {&"guard_1": &"", &"guard_2": &"beam"},
	}
	assert_eq(NetSnapshots.mark_for(&"thief", &"guard_1", views), &"hidden")
	assert_eq(NetSnapshots.mark_for(&"thief", &"guard_2", views), &"beam_only")
	assert_eq(NetSnapshots.mark_for(&"guard_1", &"thief", views), &"hidden")
	assert_eq(NetSnapshots.mark_for(&"guard_2", &"thief", views), &"cctv_only")
	assert_eq(NetSnapshots.mark_for(&"guard_1", &"guard_2", views), &"", "Guardias entre sí")
	var logged: Array[String] = NetSnapshots.log_roles({&"guard_2": {"beam_only": true}})
	assert_eq(logged, ["guard_2:beam_only"] as Array[String])


func test_client_view_modes_for_local_thief() -> void:
	var map: HeistMap3D = HeistMap3D.new()
	var thief: ThiefController3D = THIEF_SCENE.instantiate() as ThiefController3D
	var guard: GuardController3D = GUARD_SCENE.instantiate() as GuardController3D
	map.add_child(thief)
	map.add_child(guard)
	add_child_autofree(map)
	var body: Node3D = guard.get_node("VisualRoot") as Node3D
	NetViewModes.apply(map, &"thief", {})
	assert_false(body.visible, "Fuera del snapshot: oculto")
	NetViewModes.apply(map, &"thief", {&"guard_1": {"beam_only": true}})
	assert_false(body.visible, "Solo el haz: cuerpo oculto")
	NetViewModes.apply(map, &"thief", {&"guard_1": {}})
	assert_true(body.visible, "Visible")


func test_fog_zone_and_end_of_match() -> void:
	var thief: ThiefController3D = _actor(THIEF_SCENE, Vector3(4.0, 0.0, 4.0)) as ThiefController3D
	var fog: FogOfWar3D = FogOfWar3D.new()
	add_child_autofree(fog)
	fog.viewer = thief
	await wait_physics_frames(2)
	fog.recompute()
	assert_true(fog.is_point_visible(Vector3(6.0, 0.0, 4.0)), "En la misma sala")
	assert_false(fog.is_point_visible(Vector3(11.0, 0.0, 4.5)), "Tras el muro x=8")
	assert_true(fog.is_point_visible(Vector3(10.0, 0.0, 3.0)), "Por la puerta D1")
	assert_false(fog.is_point_visible(Vector3(4.0 + RULES.thief_view_radius + 1.0, 0.0, 4.0)))
	GameManager.current_state = GameManager.MatchState.THIEF_CAPTURED
	assert_false(fog.is_active(), "Sin niebla al acabar")


func test_loot_memory_ghost_until_seen() -> void:
	var thief: ThiefController3D = _actor(THIEF_SCENE, Vector3(4.0, 0.0, 4.0)) as ThiefController3D
	var fog: FogOfWar3D = FogOfWar3D.new()
	add_child_autofree(fog)
	fog.viewer = thief
	var memory: FogMemory = FogMemory.new()
	memory.fog = fog
	_root.add_child(memory)
	var loot: LootItem3D = LOOT_SCENE.instantiate() as LootItem3D
	_root.add_child(loot)
	loot.global_position = Vector3(11.0, 0.0, 4.5)
	await wait_physics_frames(2)
	fog.recompute()
	memory.sample()
	loot.free()
	memory.sample()
	assert_eq(memory.ghost_count(), 1, "Desaparece en la niebla: queda el fantasma")
	thief.global_position = Vector3(10.0, 0.0, 4.0)
	await wait_physics_frames(1)
	fog.recompute()
	memory.sample()
	assert_eq(memory.ghost_count(), 0, "Al volver a mirar se descubre que falta")
	var fresh: LootItem3D = LOOT_SCENE.instantiate() as LootItem3D
	_root.add_child(fresh)
	fresh.global_position = Vector3(2.0, 0.0, 1.0)
	memory.sample()
	assert_true(memory.is_hidden(fresh), "Lo nuevo tras el tabique no aparece hasta verlo")
	fresh.visible = true
	assert_true(memory.is_hidden(fresh), "Aunque la red toque la raíz, sigue oculto")
