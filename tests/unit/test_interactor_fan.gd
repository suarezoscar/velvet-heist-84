## @file test_interactor_fan.gd
## Interactor3D (#113): el abanico de ±60° y el alcance de 2 m deciden el foco; sin cursor gana
## el más cercano, con cursor gana el apuntado aunque esté más lejos y `execute_interaction`
## actúa sobre el mismo candidato elegido. Reglas leídas de `data/balance/interaction_rules.tres`.
extends GutTest


## Interactuable mínimo de prueba: área en la capa de interacción que registra quién lo usó
class FanTarget:
	extends Area3D

	var interacted_by: Node3D = null

	func can_interact(_actor: Node3D = null) -> bool:
		return true

	func interact(actor: Node3D = null) -> void:
		interacted_by = actor


const GUARD_SCENE: PackedScene = preload("res://scenes/entities/guard_player.tscn")
const RULES: InteractionRules = preload("res://data/balance/interaction_rules.tres")

var _root: Node3D = null
var _guard: GuardController3D = null


func before_each() -> void:
	_root = Node3D.new()
	add_child_autofree(_root)
	_guard = GUARD_SCENE.instantiate() as GuardController3D
	_root.add_child(_guard)
	_guard.set_physics_process(false)
	_guard.global_position = Vector3(0.0, 0.05, 0.0)
	_guard.rotation.y = 0.0


## Punto horizontal a `angle_deg` del frente del guardia (-Z) y a `dist` metros de él
func _fan_point(angle_deg: float, dist: float) -> Vector3:
	var rad: float = deg_to_rad(angle_deg)
	return _guard.global_position + Vector3(-sin(rad) * dist, 0.0, -cos(rad) * dist)


## Crea un interactuable de prueba con caja vertical en la capa de interacción
func _spawn_target(at: Vector3) -> FanTarget:
	var target: FanTarget = FanTarget.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.4, 2.0, 0.4)
	shape.shape = box
	target.add_child(shape)
	target.collision_layer = Interactor3D.INTERACTION_LAYER_MASK
	target.collision_mask = 0
	_root.add_child(target)
	target.global_position = at
	return target


## Deja que el interactor escanee en varios ticks físicos y devuelve su foco actual
func _focused() -> Node3D:
	await wait_physics_frames(4)
	return _guard.interactor.current_target


func test_no_cursor_closest_wins() -> void:
	var near: FanTarget = _spawn_target(_fan_point(0.0, RULES.reach_distance * 0.6))
	var far: FanTarget = _spawn_target(_fan_point(40.0, RULES.reach_distance * 0.85))
	var focused: Node3D = await _focused()
	assert_eq(focused, near, "Sin cursor el interactor enfoca al candidato más cercano")


func test_target_inside_fan_is_focused() -> void:
	var half_fan: float = RULES.fan_angle_degrees * 0.5
	var inside: FanTarget = _spawn_target(_fan_point(half_fan - 5.0, RULES.reach_distance * 0.75))
	var focused: Node3D = await _focused()
	assert_eq(focused, inside, "Un objeto dentro del abanico (±%f°) se enfoca" % half_fan)


func test_target_behind_is_not_focused() -> void:
	_spawn_target(_fan_point(180.0, RULES.reach_distance * 0.7))
	var focused: Node3D = await _focused()
	assert_null(focused, "Un objeto a la espalda del guardia queda fuera del abanico")


func test_target_within_reach_is_focused() -> void:
	var close: FanTarget = _spawn_target(_fan_point(0.0, RULES.reach_distance * 0.75))
	var focused: Node3D = await _focused()
	assert_eq(focused, close, "Un objeto a menos de %f m se enfoca" % RULES.reach_distance)


func test_target_at_or_beyond_reach_is_not_focused() -> void:
	# La caja tiene 0,4 m de fondo: su punto cercano queda exactamente en el límite.
	_spawn_target(_fan_point(0.0, RULES.reach_distance + 0.2))
	var focused: Node3D = await _focused()
	assert_null(
		focused, "El punto interactivo a %f m no entra en el alcance" % RULES.reach_distance
	)


func test_cursor_prefers_aimed_target_even_farther() -> void:
	var near: FanTarget = _spawn_target(_fan_point(0.0, RULES.reach_distance * 0.6))
	var far: FanTarget = _spawn_target(_fan_point(40.0, RULES.reach_distance * 0.85))
	_guard.interaction_cursor_position = _fan_point(40.0, RULES.reach_distance * 0.85)
	var focused: Node3D = await _focused()
	assert_eq(focused, far, "El cursor elige al apuntado aunque esté más lejos")
	assert_ne(focused, near, "El candidato más cercano pero sin apuntar pierde")


func test_execute_interaction_acts_on_cursor_target() -> void:
	var near: FanTarget = _spawn_target(_fan_point(0.0, RULES.reach_distance * 0.6))
	var far: FanTarget = _spawn_target(_fan_point(40.0, RULES.reach_distance * 0.85))
	_guard.interaction_cursor_position = _fan_point(40.0, RULES.reach_distance * 0.85)
	var focused: Node3D = await _focused()
	assert_eq(focused, far, "Antes de ejecutar, el foco ya es el apuntado por el cursor")
	var executed: bool = _guard.interactor.execute_interaction(_guard)
	assert_true(executed, "execute_interaction revalida el foco y devuelve true")
	assert_eq(far.interacted_by, _guard, "El interact es para el candidato elegido por el cursor")
	assert_null(near.interacted_by, "El descartado por el cursor no recibe interact")


func test_reset_cursor_to_inf_restores_proximity_priority() -> void:
	var near: FanTarget = _spawn_target(_fan_point(0.0, RULES.reach_distance * 0.6))
	var far: FanTarget = _spawn_target(_fan_point(40.0, RULES.reach_distance * 0.85))
	_guard.interaction_cursor_position = _fan_point(40.0, RULES.reach_distance * 0.85)
	var focused: Node3D = await _focused()
	assert_eq(focused, far, "Con cursor apunta al lejano")
	_guard.interaction_cursor_position = Vector3.INF
	focused = await _focused()
	assert_eq(focused, near, "Al reiniciar cursor a INF vuelve a ganar el más cercano")


func test_sanitize_interaction_cursor_does_not_persist_without_finite_value() -> void:
	_guard.interaction_cursor_position = Vector3(5.0, 0.0, 5.0)
	var sanitized: Vector3 = NetInputRules.sanitize_interaction_cursor(_guard, Vector3.INF)
	assert_eq(
		sanitized, Vector3.INF, "Un cursor no finito se sanea a Vector3.INF sin heredar el previo"
	)


## Interactuable con caja de `size` cuyo centro queda a `center_y` sobre el suelo
func _spawn_box(at: Vector3, size: Vector3, center_y: float) -> FanTarget:
	var target: FanTarget = FanTarget.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector3(0.0, center_y, 0.0)
	target.add_child(shape)
	target.collision_layer = Interactor3D.INTERACTION_LAYER_MASK
	target.collision_mask = 0
	_root.add_child(target)
	target.global_position = at
	return target


func test_cursor_behind_player_closest_wins() -> void:
	var near: FanTarget = _spawn_target(_fan_point(0.0, 0.8))
	var far: FanTarget = _spawn_target(_fan_point(50.0, 1.9))
	_guard.interaction_cursor_position = _guard.global_position + Vector3(0.0, 0.0, 5.0)
	var focused: Node3D = await _focused()
	assert_eq(focused, near, "Con el cursor a la espalda y lejos de todo, gana el más cercano")
	assert_ne(focused, far, "El lejano no gana por estar 'más alineado' con un cursor lejano")


func test_cursor_over_far_target_wins() -> void:
	var near: FanTarget = _spawn_target(_fan_point(0.0, 0.8))
	var far: FanTarget = _spawn_target(_fan_point(50.0, 1.9))
	var over_far: Vector3 = _fan_point(50.0, 1.9) + Vector3(0.3, 0.0, 0.0)
	_guard.interaction_cursor_position = over_far
	var focused: Node3D = await _focused()
	assert_eq(focused, far, "Con el cursor a 0,3 m del lejano, gana el lejano")
	assert_ne(focused, near, "El cercano pierde si el cursor está sobre el otro")


func test_deep_area_is_measured_to_its_center() -> void:
	# Caja de 2,2 m de fondo como la de las puertas: su borde queda mucho más cerca que su centro
	var deep: FanTarget = _spawn_box(Vector3(0.0, 0.0, -10.0), Vector3(1.0, 2.0, 2.2), 1.0)
	_guard.global_position = Vector3(0.0, 0.05, -10.0 + 2.5)
	var focused: Node3D = await _focused()
	assert_null(focused, "A 2,5 m del centro no se enfoca aunque el borde quede a 1,4 m")
	_guard.global_position = Vector3(0.0, 0.05, -10.0 + 1.5)
	focused = await _focused()
	assert_eq(focused, deep, "A 1,5 m del centro sí se enfoca")


func test_high_target_is_focused() -> void:
	# Como un cuadro eléctrico: área de 0,55 a 2,05 m, sin tocar el suelo
	var high: FanTarget = _spawn_box(_fan_point(0.0, 1.0), Vector3(0.6, 1.5, 0.3), 1.3)
	var focused: Node3D = await _focused()
	assert_eq(focused, high, "Un objetivo alto a 1 m delante se enfoca")


func test_high_target_behind_wall_is_not_focused() -> void:
	var wall: StaticBody3D = StaticBody3D.new()
	wall.collision_layer = LevelArchitectureBuilder.LAYER_WALLS
	var wall_shape: CollisionShape3D = CollisionShape3D.new()
	var wall_box: BoxShape3D = BoxShape3D.new()
	wall_box.size = Vector3(4.0, 3.0, 0.2)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	_root.add_child(wall)
	wall.global_position = _fan_point(0.0, 0.6) + Vector3(0.0, 1.5, 0.0)
	_spawn_box(_fan_point(0.0, 1.0), Vector3(0.6, 1.5, 0.3), 1.3)
	var focused: Node3D = await _focused()
	assert_null(focused, "Un muro entre el personaje y el objetivo alto lo oculta")


func test_cursor_gap_corrects_for_object_height() -> void:
	# Bajo el ratón, un punto a 0,9 m de alto cae en el suelo √2·0,9 m más allá (hacia donde mira)
	var center: Vector3 = Vector3(0.0, 0.9, 0.0)
	var on_floor: Vector3 = (
		center + Interactor3D.VIEW_FORWARD_H * 0.9 * Interactor3D.VIEW_RUN_PER_DROP
	)
	on_floor.y = 0.0
	assert_almost_eq(Interactor3D.cursor_gap(on_floor, center), 0.0, 0.01, "Ratón sobre la pieza")
	assert_gt(
		Interactor3D.cursor_gap(Vector3(0.0, 0.0, 0.0), center),
		1.0,
		"El suelo bajo ella no la señala"
	)
