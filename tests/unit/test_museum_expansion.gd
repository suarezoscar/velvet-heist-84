## @file test_museum_expansion.gd
## Museo ampliado (FEAT-034): la puerta de la garita, la ventilación del ladrón, el decorado
## (cuadros con sus créditos, focos) y el recorte de paredes delante del jugador local.
extends GutTest

const MAP_SCENE: PackedScene = preload("res://scenes/maps/museum_v2.tscn")
const DOOR_RULES: DoorRules = preload("res://data/balance/door_rules.tres")
const VENT_RULES: VentRules = preload("res://data/balance/vent_rules.tres")
const LEVEL_PATH: String = "res://data/levels/museum_v2.json"

var _saved_state: GameManager.MatchState


func before_each() -> void:
	_saved_state = GameManager.current_state


func after_each() -> void:
	GameManager.current_state = _saved_state


func _map() -> HeistMap3D:
	var map: HeistMap3D = MAP_SCENE.instantiate() as HeistMap3D
	add_child_autofree(map)
	return map


func _tick(node: Node, seconds: float) -> void:
	for _i: int in range(roundi(seconds / 0.1) + 1):
		node._physics_process(0.1)


func test_garita_door_opens_closes_and_blocks() -> void:
	var map: HeistMap3D = _map()
	await wait_physics_frames(2)
	var door: Door3D = map.find_child("Door_P20", true, false) as Door3D
	assert_not_null(door, "La garita tiene su puerta")
	assert_false(door.is_open, "Empieza cerrada")
	var leaf: StaticBody3D = door.find_child("Leaf", true, false) as StaticBody3D
	assert_true(
		leaf.collision_layer & LevelArchitectureBuilder.LAYER_WALLS != 0, "Cerrada tapa la vista"
	)
	for guard: GuardController3D in map.guards:
		guard.is_ai_controlled = false
		guard.global_position = door.global_position + Vector3(10.0, 0.0, 10.0)
	var guard: GuardController3D = map.guards[0]
	door.interact(guard)
	assert_true(door.is_open, "Un guardia la abre al momento")
	var col: CollisionShape3D = leaf.get_node("CollisionShape3D") as CollisionShape3D
	assert_true(col.disabled, "Abierta deja pasar")
	map.thief.global_position = door.global_position + Vector3(10.0, 0.0, -10.0)
	_tick(door, DOOR_RULES.auto_close)
	assert_false(door.is_open, "Se cierra sola")
	map.thief.global_position = door.global_position + Vector3(0.0, 0.0, 1.0)
	door.interact(map.thief)
	assert_false(door.is_open, "El ladrón no abre al momento")
	assert_string_contains(door.get_interaction_text(map.thief), "Forzando")
	_tick(door, DOOR_RULES.pick_time)
	assert_true(door.is_open, "La fuerza en pick_time")
	map.thief.global_position = door.global_position
	_tick(door, DOOR_RULES.auto_close + 1.0)
	assert_true(door.is_open, "No se cierra con alguien en el hueco")
	assert_eq(door.get_net_state(), {"open": true})


func test_ai_guard_opens_the_door() -> void:
	var map: HeistMap3D = _map()
	await wait_physics_frames(2)
	var door: Door3D = map.find_child("Door_P20", true, false) as Door3D
	map.guards[0].is_ai_controlled = true
	map.guards[0].global_position = door.global_position + Vector3(0.5, 0.0, 0.0)
	door._physics_process(0.1)
	assert_true(door.is_open, "La IA la abre al acercarse")


func test_paintings_have_images_and_credits() -> void:
	var data: LevelData = LevelData.load_json(LEVEL_PATH)
	var credits: String = FileAccess.get_file_as_string(
		"res://assets/textures/paintings/CREDITS.md"
	)
	var slugs: Array[String] = []
	for art: Dictionary in data.section("art"):
		slugs.append(String(art["painting"]))
	for target: Dictionary in data.section("targets"):
		if target.get("model", "") == "painting":
			slugs.append(String(target["painting"]))
	assert_gt(slugs.size(), 25, "Un museo lleno de cuadros")
	for slug: String in slugs:
		assert_true(ResourceLoader.exists(PaintingArt.TEXTURE_DIR % slug), "Existe %s" % slug)
		assert_string_contains(credits, "`%s.jpg`" % slug, "Créditos de %s" % slug)


## #186: el decorado ya no pone focos sobre las piezas (parecían luz de sigilo sin serlo)
func test_dressing_has_no_spots_and_adds_xray() -> void:
	var map: HeistMap3D = _map()
	await wait_physics_frames(2)
	var dressing: Node = map.get_node("Dressing")
	assert_eq(dressing.find_children("*", "Light3D", true, false).size(), 0, "Sin luces de adorno")
	assert_not_null(map.get_node_or_null("WallXRay"))
	assert_not_null(map.get_node_or_null("WallCutaway"), "#193: paredes recortadas por sala")


func test_guards_see_a_counter_and_the_map_has_the_level() -> void:
	var map: HeistMap3D = _map()
	await wait_physics_frames(2)
	var heist: HeistDirector = GameManager.heist
	assert_eq(ContractList84.guards_line(heist), "EN EL PUNTO DE MIRA 20 · RASTROS 0 · plano [M]")
	heist.piece(heist.candidates()[0]).discovered = true
	assert_string_contains(ContractList84.guards_line(heist), "EN EL PUNTO DE MIRA 19 · RASTROS 1")
	assert_true(map.get_meta(&"level_data") is LevelData, "El plano (M) tiene los datos")
