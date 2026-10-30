## @file interactor_3d.gd
## Componente desacoplado que elige y ejecuta interacciones físicas con objetos del entorno.
## Usa un abanico cercano, la preferencia del cursor y la oclusión de muros (#113). Distancias y
## ángulos se miden al centro de la forma de cada objeto, a su altura (cuadros e interruptores
## están altos), y el cursor solo decide si cae cerca de un candidato.
class_name Interactor3D
extends Node3D

## Señal emitida cuando el personaje apunta a un objeto interactuable válido
signal target_focused(target: Node3D)

## Señal emitida cuando el personaje deja de apuntar a un objeto interactuable
signal target_unfocused

## Capa de colisión exclusiva para objetos interactuables en el mapa
const INTERACTION_LAYER_MASK: int = 4

## Altura (m) sobre el personaje a la que se comprueba que ningún muro tapa el objetivo
const WALL_CHECK_HEIGHT: float = 1.0

## Altura del cilindro de búsqueda; el alcance jugable se mide después en horizontal
const BROAD_PHASE_HEIGHT: float = 4.0

## Máximo de formas devueltas por la búsqueda física de cada tick
const MAX_BROAD_PHASE_RESULTS: int = 64

## Cámara isométrica fija (AGENTS.md: rotación -35,264°, 45°): hacia dónde mira en el plano y
## cuánto avanza en horizontal por cada metro que baja (1 / tan 35,264° = √2). Sirve para llevar
## el cursor, proyectado al suelo, a la altura de cada objeto
const VIEW_FORWARD_H: Vector3 = Vector3(-0.70710677, 0.0, -0.70710677)
const VIEW_RUN_PER_DROP: float = 1.4142135

const DEFAULT_RULES: InteractionRules = preload("res://data/balance/interaction_rules.tres")

## Reglas comunes de alcance y abanico
@export var rules: InteractionRules = null

var current_target: Node3D = null
var _outline: InteractionOutline3D = null
var _broad_query: PhysicsShapeQueryParameters3D = null
var _cylinder_shape: CylinderShape3D = null


func _ready() -> void:
	if rules == null:
		rules = DEFAULT_RULES


func _physics_process(_delta: float) -> void:
	_scan_for_interactables()


## Escanea continuamente en cada frame físico en busca de objetos con método `interact`
func _scan_for_interactables() -> void:
	var detected_target: Node3D = _find_best_target()
	if detected_target != current_target:
		current_target = detected_target
		if current_target != null:
			target_focused.emit(current_target)
		else:
			target_unfocused.emit()
	_update_outline()


## Solo el jugador local ve el contorno; servidores y títeres no crean geometría de apoyo
func _update_outline() -> void:
	var actor: PlayerBase3D = get_parent() as PlayerBase3D
	if actor == null or not actor.is_locally_controlled:
		if _outline != null:
			_outline.clear()
		return
	if _outline == null:
		_outline = InteractionOutline3D.new()
		_outline.name = "InteractionOutline"
		add_child(_outline)
	_outline.show_target(current_target)


## Elige el candidato bajo el cursor (si cae cerca de alguno); si no, el más cercano
func _find_best_target() -> Node3D:
	var actor: Node3D = get_parent() as Node3D
	if actor == null or not is_inside_tree() or get_world_3d() == null or rules == null:
		return null
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var broad_results: Array[Dictionary] = _broad_phase(space, actor)
	var candidates: Array[Dictionary] = []
	var seen: Dictionary = {}
	for result: Dictionary in broad_results:
		var collider: CollisionObject3D = result.get("collider") as CollisionObject3D
		if collider == null or seen.has(collider.get_instance_id()):
			continue
		seen[collider.get_instance_id()] = true
		if not collider.has_method("interact"):
			continue
		if collider.has_method("can_interact") and not bool(collider.call("can_interact", actor)):
			continue
		var center: Vector3 = target_center(collider)
		var offset: Vector3 = (center - actor.global_position).slide(Vector3.UP)
		var distance: float = offset.length()
		if distance >= rules.reach_distance:
			continue
		if distance > 0.0001:
			var forward: Vector3 = (-actor.global_basis.z).slide(Vector3.UP).normalized()
			if forward.dot(offset.normalized()) < cos(deg_to_rad(rules.fan_angle_degrees * 0.5)):
				continue
		if _interaction_hit(space, actor, collider, center, broad_results).is_empty():
			continue
		if _is_behind_wall(collider, center):
			continue
		candidates.append({"target": collider, "point": center, "distance": distance})
	return _best_candidate(actor, _without_covered_locks(candidates))


## Un candado y la pieza que guarda están en el mismo sitio: se elige la pieza, que ya abre su
## dial; el candado solo cuenta si su pieza no es candidata
static func _without_covered_locks(candidates: Array[Dictionary]) -> Array[Dictionary]:
	var targets: Array[Node3D] = []
	for candidate: Dictionary in candidates:
		targets.append(candidate["target"] as Node3D)
	var kept: Array[Dictionary] = []
	for candidate: Dictionary in candidates:
		var lock: SafeBox3D = candidate["target"] as SafeBox3D
		if lock == null or not targets.has(lock.contained_target):
			kept.append(candidate)
	return kept


## Búsqueda amplia en la capa de interacción; los filtros precisos se hacen por candidato
func _broad_phase(space: PhysicsDirectSpaceState3D, actor: Node3D) -> Array[Dictionary]:
	if _broad_query == null:
		_broad_query = PhysicsShapeQueryParameters3D.new()
		_cylinder_shape = CylinderShape3D.new()
		_cylinder_shape.height = BROAD_PHASE_HEIGHT
		_broad_query.shape = _cylinder_shape
		_broad_query.collision_mask = INTERACTION_LAYER_MASK
		_broad_query.collide_with_areas = true
		_broad_query.collide_with_bodies = true
	_cylinder_shape.radius = rules.reach_distance
	_broad_query.transform = Transform3D(Basis.IDENTITY, actor.global_position)
	return space.intersect_shape(_broad_query, MAX_BROAD_PHASE_RESULTS)


## Impacto cercano sobre el candidato, sin que otra área interactiva solapada lo tape
func _interaction_hit(
	space: PhysicsDirectSpaceState3D,
	actor: Node3D,
	target: CollisionObject3D,
	center: Vector3,
	broad_results: Array[Dictionary]
) -> Dictionary:
	# A la altura del objeto: un rayo a los pies no toca cuadros ni interruptores de pared
	var from: Vector3 = Vector3(actor.global_position.x, center.y, actor.global_position.z)
	var to: Vector3 = center
	if from.distance_squared_to(to) <= 0.000001:
		from = to + Vector3.UP * 0.01
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, to, INTERACTION_LAYER_MASK
	)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.hit_from_inside = true
	var exclusions: Array[RID] = []
	for result: Dictionary in broad_results:
		var other: CollisionObject3D = result.get("collider") as CollisionObject3D
		if other != null and other != target:
			exclusions.append(other.get_rid())
	query.exclude = exclusions
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty() or hit.get("collider") != target:
		return {}
	return hit


## Distancia en el plano entre el objeto y el punto que el ratón señala a su altura: el cursor
## llega proyectado al suelo, y un objeto alto se ve bajo el ratón más cerca de la cámara
static func cursor_gap(cursor: Vector3, center: Vector3) -> float:
	var aimed: Vector3 = cursor - VIEW_FORWARD_H * (center.y - cursor.y) * VIEW_RUN_PER_DROP
	return (center - aimed).slide(Vector3.UP).length()


## Centro de la primera forma de colisión activa hija directa del objeto (su origen si no tiene
## ninguna). Con varias formas solo cuenta la primera; hoy todos los interactivos tienen una
static func target_center(target: Node3D) -> Vector3:
	for child: Node in target.get_children():
		var shape: CollisionShape3D = child as CollisionShape3D
		if shape != null and not shape.disabled:
			return shape.global_position
	return target.global_position


## true si un muro del nivel (capa LevelArchitectureBuilder.LAYER_WALLS) se interpone entre el
## personaje y el objetivo. Los muebles no bloquean y las partes del propio objetivo (como la hoja
## de una puerta) no se consideran obstáculos (#113).
func _is_behind_wall(target: Node3D, hit_point: Vector3) -> bool:
	if not is_inside_tree() or get_world_3d() == null:
		return false
	var from: Vector3 = global_position + Vector3(0.0, WALL_CHECK_HEIGHT, 0.0)
	var to: Vector3 = Vector3(hit_point.x, from.y, hit_point.z)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, to, LevelArchitectureBuilder.LAYER_WALLS
	)
	var exclusions: Array[RID] = []
	if target is CollisionObject3D:
		exclusions.append((target as CollisionObject3D).get_rid())
	if target != null:
		for child: Node in target.find_children("*", "CollisionObject3D", true, false):
			exclusions.append((child as CollisionObject3D).get_rid())
	query.exclude = exclusions
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Compara candidatos sin depender del orden devuelto por el motor físico
func _best_candidate(actor: Node3D, candidates: Array[Dictionary]) -> Node3D:
	var cursor: Vector3 = Vector3.INF
	if actor is PlayerBase3D:
		cursor = (actor as PlayerBase3D).interaction_cursor_position
	# El cursor solo decide si cae cerca de algún candidato; si no, gana el más cercano
	var use_cursor: bool = false
	for candidate: Dictionary in candidates:
		var gap: float = INF
		if cursor.is_finite():
			gap = cursor_gap(cursor, candidate["point"] as Vector3)
		candidate["cursor_gap"] = gap
		use_cursor = use_cursor or gap <= rules.cursor_snap_distance
	var best: Dictionary = {}
	for candidate: Dictionary in candidates:
		if best.is_empty() or _is_better_candidate(candidate, best, use_cursor):
			best = candidate
	return best.get("target") as Node3D if not best.is_empty() else null


func _is_better_candidate(candidate: Dictionary, best: Dictionary, use_cursor: bool) -> bool:
	if use_cursor:
		var gap: float = float(candidate["cursor_gap"])
		var best_gap: float = float(best["cursor_gap"])
		if not is_equal_approx(gap, best_gap):
			return gap < best_gap
	var distance: float = float(candidate["distance"])
	var best_distance: float = float(best["distance"])
	if not is_equal_approx(distance, best_distance):
		return distance < best_distance
	var target: Node3D = candidate["target"] as Node3D
	var best_target: Node3D = best["target"] as Node3D
	return String(target.get_path()) < String(best_target.get_path())


## Ejecuta la interacción; con cursor refresca el foco para aplicar su preferencia en el mismo tick
func execute_interaction(actor: Node3D) -> bool:
	var player: PlayerBase3D = actor as PlayerBase3D
	if player != null and player.interaction_cursor_position.is_finite():
		_scan_for_interactables()
	if current_target != null and current_target.has_method("interact"):
		current_target.call("interact", actor)
		return true
	return false


## Devuelve el texto del tooltip informativo para el HUD
func get_target_prompt_text() -> String:
	if current_target != null and current_target.has_method("get_interaction_text"):
		return str(current_target.call("get_interaction_text", get_parent()))
	return ""
