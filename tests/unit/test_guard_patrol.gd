## @file test_guard_patrol.gd
## GuardPatrol (heist.md R5, R5c; #116): la garita, la elección de sala de la IA (sin exterior,
## sin garita, sin repetir, más las que tienen piezas) y los caminos entre salas.
extends GutTest

const MUSEUM_PATH: String = "res://data/levels/museum_v2.json"

var _data: LevelData = null
var _patrol: GuardPatrol = null


func before_each() -> void:
	_data = LevelData.load_json(MUSEUM_PATH)
	_patrol = GuardPatrol.new()
	_patrol.graph = RoomGraph.from_level(_data)
	add_child_autofree(_patrol)


func _at(x: float, z: float) -> Vector3:
	return _data.to_world([x, z], LevelEntitiesBuilder.ACTOR_HEIGHT)


func _rng() -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 116
	return rng


func test_in_guard_post_inside_gar_only() -> void:
	assert_true(_patrol.in_guard_post(_at(38.0, 27.0)), "El centro de la garita")
	assert_true(_patrol.in_guard_post(_at(35.0, 25.0)), "Y un rincón")
	assert_false(_patrol.in_guard_post(_at(33.9, 25.0)), "El pasillo junto al umbral, no")
	assert_false(_patrol.in_guard_post(_at(33.0, 20.0)), "El pasillo de servicio, no")
	assert_false(_patrol.in_guard_post(_at(8.0, 8.0)), "Una sala cualquiera, no")
	assert_false(_patrol.in_guard_post(_at(20.0, 40.0)), "El callejón, no")


func test_pick_room_never_exterior_or_post() -> void:
	var rng: RandomNumberGenerator = _rng()
	var recent: Array[String] = []
	for i: int in range(300):
		var room_id: String = _patrol.pick_room(recent, rng)
		assert_ne(room_id, "", "Siempre hay sala")
		assert_ne(room_id, "GAR", "Nunca la garita")
		assert_ne(room_id, "ALY", "Nunca el exterior")


func test_pick_room_skips_recent_rooms() -> void:
	var rng: RandomNumberGenerator = _rng()
	var recent: Array[String] = ["ANT", "GW", "ORI"]
	for i: int in range(300):
		assert_false(recent.has(_patrol.pick_room(recent, rng)), "No repite las recientes")


func test_pick_room_prefers_rooms_with_pieces() -> void:
	var piece: Node3D = Node3D.new()
	add_child_autofree(piece)
	piece.add_to_group(&"heist_targets")
	piece.global_position = _at(8.0, 8.0)  # ANT
	var rng: RandomNumberGenerator = _rng()
	var counts: Dictionary = {}
	var recent: Array[String] = []
	for i: int in range(3000):
		var room_id: String = _patrol.pick_room(recent, rng)
		counts[room_id] = int(counts.get(room_id, 0)) + 1
	var empty: int = int(counts.get("GW", 0))
	assert_gt(empty, 0, "Las vacías también salen")
	assert_gt(int(counts.get("ANT", 0)), int(empty * 1.5), "Con una pieza sale bastante más")


func test_walk_between_ends_at_the_destination() -> void:
	var from: Vector3 = _patrol.room_center("ANT")
	var to: Vector3 = _patrol.room_center("ORI")
	var path: Array[Vector3] = _patrol.walk_between(from, to)
	assert_gt(path.size(), 1, "Cruza puertas por el camino")
	var last: Vector3 = path.back()
	assert_lt(Vector2(last.x - to.x, last.z - to.z).length(), 0.5, "Acaba en el destino")
