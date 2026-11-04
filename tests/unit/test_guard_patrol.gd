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
	_piece_at(8.0, 8.0)  # ANT
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


func test_pick_room_never_corridor() -> void:
	var rng: RandomNumberGenerator = _rng()
	var recent: Array[String] = []
	for i: int in range(500):
		var room_id: String = _patrol.pick_room(recent, rng)
		assert_ne(room_id, "PS", "Nunca el pasillo de servicio")
		assert_ne(room_id, "EPS", "Nunca el pasillo del este")


func test_pick_room_with_all_but_one_avoided_returns_the_rest() -> void:
	var weights: Dictionary = _patrol.room_weights({})
	var avoid: Array[String] = []
	for room_id: Variant in weights.keys():
		avoid.append(String(room_id))
	avoid.erase("ORI")
	var rng: RandomNumberGenerator = _rng()
	for i: int in range(50):
		assert_eq(_patrol.pick_room(avoid, rng), "ORI", "Solo queda una")


func _piece_at(x: float, z: float) -> TargetPiece3D:
	var piece: TargetPiece3D = TargetPiece3D.new()
	add_child_autofree(piece)
	piece.add_to_group(&"heist_targets")
	piece.global_position = _at(x, z)
	return piece


func test_discovered_piece_does_not_weigh() -> void:
	var piece: TargetPiece3D = _piece_at(8.0, 8.0)  # ANT
	var before: float = float(_patrol.room_weights(_patrol._piece_counts())["ANT"])
	piece.discovered = true
	var after: float = float(_patrol.room_weights(_patrol._piece_counts())["ANT"])
	assert_gt(before, after, "Descubierta como robada, deja de pesar")
	assert_eq(after, 1.0, "Vuelve al peso base")


func test_piece_stops_one_per_live_piece_near_it() -> void:
	var piece: TargetPiece3D = _piece_at(2.0, 2.0)  # ANT, lejos del centro
	var discovered: TargetPiece3D = _piece_at(12.0, 10.0)  # ANT
	discovered.discovered = true
	_piece_at(24.0, 5.0)  # VLT: otra sala
	var stops: Array[Vector3] = _patrol.piece_stops("ANT")
	assert_eq(stops.size(), 1, "Una por pieza viva de la sala")
	var delta: Vector3 = stops[0] - piece.global_position
	var flat: Vector2 = Vector2(delta.x, delta.z)
	assert_lte(flat.length(), 1.001, "A 1 m o menos de la pieza")
	assert_almost_eq(stops[0].y, _patrol.room_center("ANT").y, 0.001, "A la altura del centro")
