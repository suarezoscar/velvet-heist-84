## @file interactor_3d.gd
## Componente desacoplado que elige y ejecuta interacciones físicas con objetos del entorno.
## Usa un abanico cercano, la preferencia del cursor y la oclusión de muros (#113).
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

const DEFAULT_RULES: InteractionRules = preload("res://data/balance/interaction_rules.tres")

## Reglas comunes de alcance y abanico
@export var rules: InteractionRules = null

var current_target: Node3D = null
var _outline: InteractionOutline3D = null


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


## Elige el candidato válido preferido por el cursor; sin cursor, gana el más cercano
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
		var hit: Dictionary = _interaction_hit(space, actor, collider, broad_results)
		if hit.is_empty():
			continue
		var point: Vector3 = hit["position"] as Vector3
		var offset: Vector3 = (point - actor.global_position).slide(Vector3.UP)
		var distance: float = offset.length()
		if distance >= rules.reach_distance or distance <= 0.0001:
			continue
		var forward: Vector3 = (-actor.global_basis.z).slide(Vector3.UP).normalized()
		if forward.dot(offset / distance) < cos(deg_to_rad(rules.fan_angle_degrees * 0.5)):
			continue
		if _is_behind_wall(collider, point):
			continue
		candidates.append({"target": collider, "point": point, "distance": distance})
	return _best_candidate(actor, candidates)


## Búsqueda amplia en la capa de interacción; los filtros precisos se hacen por candidato
func _broad_phase(space: PhysicsDirectSpaceState3D, actor: Node3D) -> Array[Dictionary]:
	var cylinder: CylinderShape3D = CylinderShape3D.new()
	cylinder.radius = rules.reach_distance
	cylinder.height = BROAD_PHASE_HEIGHT
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = cylinder
	query.transform = Transform3D(Basis.IDENTITY, actor.global_position)
	query.collision_mask = INTERACTION_LAYER_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = true
	return space.intersect_shape(query, MAX_BROAD_PHASE_RESULTS)


## Impacto cercano sobre el candidato, sin que otra área interactiva solapada lo tape
func _interaction_hit(
	space: PhysicsDirectSpaceState3D,
	actor: Node3D,
	target: CollisionObject3D,
	broad_results: Array[Dictionary]
) -> Dictionary:
	var from: Vector3 = actor.global_position
	var to: Vector3 = Vector3(target.global_position.x, from.y, target.global_position.z)
	if from.distance_squared_to(to) <= 0.000001:
		to = target.global_position
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


## true si un muro del nivel (capa LevelArchitectureBuilder.LAYER_WALLS) se interpone entre el
## personaje y el punto del objetivo. Los muebles y coberturas no bloquean la interacción.
func _is_behind_wall(_target: Node3D, hit_point: Vector3) -> bool:
	if not is_inside_tree() or get_world_3d() == null:
		return false
	var from: Vector3 = global_position + Vector3(0.0, WALL_CHECK_HEIGHT, 0.0)
	var to: Vector3 = Vector3(hit_point.x, from.y, hit_point.z)
	return not VisionLogic.wall_free(get_world_3d().direct_space_state, from, to)


## Compara candidatos sin depender del orden devuelto por el motor físico
func _best_candidate(actor: Node3D, candidates: Array[Dictionary]) -> Node3D:
	var cursor: Vector3 = Vector3.INF
	if actor is PlayerBase3D:
		cursor = (actor as PlayerBase3D).interaction_cursor_position
	var cursor_offset: Vector3 = (cursor - actor.global_position).slide(Vector3.UP)
	var use_cursor: bool = cursor.is_finite() and cursor_offset.length_squared() > 0.0001
	var best: Dictionary = {}
	for candidate: Dictionary in candidates:
		if use_cursor:
			var offset: Vector3 = (candidate["point"] as Vector3 - actor.global_position).slide(
				Vector3.UP
			)
			candidate["cursor_dot"] = cursor_offset.normalized().dot(offset.normalized())
		if best.is_empty() or _is_better_candidate(candidate, best, use_cursor):
			best = candidate
	return best.get("target") as Node3D if not best.is_empty() else null


func _is_better_candidate(candidate: Dictionary, best: Dictionary, use_cursor: bool) -> bool:
	if use_cursor:
		var cursor_dot: float = float(candidate["cursor_dot"])
		var best_cursor_dot: float = float(best["cursor_dot"])
		if not is_equal_approx(cursor_dot, best_cursor_dot):
			return cursor_dot > best_cursor_dot
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
