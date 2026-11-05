## @file test_fog_two_grades.gd
## #163 (vision.md R1, R2 y D4): niebla en dos grados (el suelo, entera; lo alzado, suave) con
## la misma zona visible, y piezas, cajas fuertes y vitrinas que en la niebla se dibujan como se
## vieron por última vez.
extends GutTest

const RULES: VisionProfile = preload("res://data/balance/vision_rules.tres")
const FIXTURE_PATH: String = "res://tests/fixtures/level_small.json"
const MAP_SCENE: PackedScene = preload("res://scenes/maps/museum_v2.tscn")
const THIEF_SCENE: PackedScene = preload("res://scenes/entities/thief_player.tscn")

var _saved_state: GameManager.MatchState
var _saved_timer: float


func before_each() -> void:
	_saved_state = GameManager.current_state
	_saved_timer = GameManager.match_timer
	GameManager.current_state = GameManager.MatchState.IN_PROGRESS
	GameManager.match_timer = 600.0


func after_each() -> void:
	GameManager.current_state = _saved_state
	GameManager.match_timer = _saved_timer


func test_fog_gets_both_grades_from_the_rules() -> void:
	var fog: FogOfWar3D = FogOfWar3D.new()
	add_child_autofree(fog)
	var mat: ShaderMaterial = fog.material_override as ShaderMaterial
	assert_eq(mat.get_shader_parameter("fog_brightness"), RULES.fog_brightness, "Suelo")
	assert_eq(mat.get_shader_parameter("raised_brightness"), RULES.fog_raised_brightness)
	assert_eq(mat.get_shader_parameter("raised_desaturation"), RULES.fog_raised_desaturation)
	assert_eq(mat.get_shader_parameter("raised_from"), RULES.fog_raised_from)
	assert_eq(mat.get_shader_parameter("raised_to"), RULES.fog_raised_to)
	assert_gte(RULES.fog_raised_brightness, RULES.fog_brightness, "Lo alzado, nunca más oscuro")
	assert_lt(RULES.fog_raised_from, RULES.fog_raised_to)


## Nivel pequeño: muro en x=8 (puerta D1 en z 2,4-3,6)
func test_shown_keeps_the_last_seen_state_out_of_view() -> void:
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	LevelArchitectureBuilder.build(LevelData.load_json(FIXTURE_PATH), root)
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
	var thing: Node3D = Node3D.new()
	root.add_child(thing)
	thing.global_position = Vector3(11.0, 0.0, 4.5)  # tras el muro x=8
	await wait_physics_frames(2)
	fog.recompute()
	memory.sample()
	assert_eq(FogMemory.shown(thing, "entera"), "entera", "Lo primero cuenta como visto")
	assert_eq(FogMemory.shown(thing, "vacía"), "entera", "Fuera de la vista: la última vista")
	thief.global_position = Vector3(10.0, 0.0, 4.0)
	await wait_physics_frames(1)
	fog.recompute()
	assert_eq(FogMemory.shown(thing, "vacía"), "vacía", "Al mirar, la de verdad")


func test_piece_stolen_out_of_view_stays_on_its_pedestal_until_seen() -> void:
	var map: HeistMap3D = MAP_SCENE.instantiate() as HeistMap3D
	add_child_autofree(map)
	for guard: GuardController3D in map.guards:
		guard.set_physics_process(false)
	map.thief.set_physics_process(false)
	await wait_physics_frames(3)
	var fog: FogOfWar3D = map.fog
	var piece: TargetPiece3D = _far_piece(fog)
	assert_not_null(piece, "Una pieza fuera de la vista del ladrón")
	var memory: FogMemory = get_tree().get_first_node_in_group(&"fog_memories") as FogMemory
	memory.sample()
	piece.apply_net_state({"stolen": true, "flaw": int(TargetPieceLook.Flaw.TINT)})
	assert_true(piece.stolen)
	assert_false(piece.shown_stolen, "En la niebla: aún no se ve que falta")
	memory.sample()
	assert_true(piece.model.visible, "Sigue en su pedestal")
	map.thief.global_position = piece.global_position + Vector3(1.0, 0.1, 0.0)
	await wait_physics_frames(1)
	fog.recompute()
	memory.sample()
	assert_true(piece.shown_stolen, "Al mirar, se ve")


func _far_piece(fog: FogOfWar3D) -> TargetPiece3D:
	fog.recompute()
	for node: Node in get_tree().get_nodes_in_group(&"heist_targets"):
		var piece: TargetPiece3D = node as TargetPiece3D
		if piece.variant != &"safe" and not fog.is_point_visible(piece.global_position):
			return piece
	return null
