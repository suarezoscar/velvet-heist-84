## @file fog_memory.gd
## Memoria del botín en la niebla (vision.md D4). Lo que no ves se queda como lo viste por
## última vez: si un objeto del grupo fog_memory desaparece o se mueve de un sitio que no ves,
## queda un fantasma hasta que vuelves a mirar; un objeto nuevo que no has visto (el botín de
## la caja fuerte) no aparece hasta que lo ves. Al empezar, todo cuenta como visto (el plano).
## Oculta los hijos visuales, no la raíz: la red puede cambiar la visibilidad de la raíz.
class_name FogMemory
extends Node3D

const SAMPLE_INTERVAL: float = 0.1
## Distancia (m) a partir de la cual un objeto se ha movido de su sitio
const MOVED_DISTANCE: float = 0.3

var fog: FogOfWar3D = null
var _seen: Dictionary = {}
var _ghosts: Dictionary = {}
var _hidden_by_me: Dictionary = {}
var _seeded: bool = false
var _timer: float = 0.0


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = SAMPLE_INTERVAL
	sample()


## Revisa los objetos de memoria contra la zona visible actual
func sample() -> void:
	if fog == null or not fog.is_active():
		_reset()
		return
	for node: Node in get_tree().get_nodes_in_group(&"fog_memory"):
		var item: Node3D = node as Node3D
		var id: int = item.get_instance_id()
		var in_view: bool = fog.is_point_visible(item.global_position)
		if in_view or not _seeded:
			_remember(item)
			_unhide(item)
		elif not _seen.has(id) or _moved(id, item):
			_hide(item)
	_seeded = true
	for id: int in _hidden_by_me.keys():
		if not is_instance_id_valid(id):
			_hidden_by_me.erase(id)
	for id: int in _seen.keys():
		_update_record(id)


## Fantasmas que hay ahora (los usan los tests)
func ghost_count() -> int:
	return _ghosts.size()


func _remember(item: Node3D) -> void:
	if not item.is_visible_in_tree():
		return
	_seen[item.get_instance_id()] = {
		"xform": item.global_transform, "scene": item.scene_file_path, "ref": weakref(item)
	}


func _update_record(id: int) -> void:
	var record: Dictionary = _seen[id]
	var item: Node3D = (record["ref"] as WeakRef).get_ref() as Node3D
	var origin: Vector3 = (record["xform"] as Transform3D).origin
	var gone: bool = item == null or not item.is_visible_in_tree() or _moved(id, item)
	if not gone:
		_drop_ghost(id)
	elif fog.is_point_visible(origin):
		_drop_ghost(id)
		_seen.erase(id)
	elif not _ghosts.has(id):
		_ghosts[id] = _make_ghost(record)


func _make_ghost(record: Dictionary) -> Node3D:
	var scene: PackedScene = load(record["scene"]) as PackedScene if record["scene"] != "" else null
	var ghost: Node3D = scene.instantiate() as Node3D if scene != null else Node3D.new()
	ghost.set_script(null)
	var body: CollisionObject3D = ghost as CollisionObject3D
	if body != null:
		body.collision_layer = 0
		body.collision_mask = 0
	ghost.name = "Ghost"
	add_child(ghost)
	ghost.global_transform = record["xform"]
	return ghost


func _drop_ghost(id: int) -> void:
	if _ghosts.has(id):
		(_ghosts[id] as Node).queue_free()
		_ghosts.erase(id)


## true si el objeto está lejos del sitio donde se vio por última vez
func _moved(id: int, item: Node3D) -> bool:
	if not _seen.has(id):
		return false
	var origin: Vector3 = (_seen[id]["xform"] as Transform3D).origin
	return item.global_position.distance_to(origin) > MOVED_DISTANCE


func _hide(item: Node3D) -> void:
	var id: int = item.get_instance_id()
	if _hidden_by_me.has(id):
		return
	var hidden: Array[Node3D] = []
	for child: Node in item.get_children():
		var visual: Node3D = child as Node3D
		if visual != null and visual.visible:
			visual.visible = false
			hidden.append(visual)
	_hidden_by_me[id] = hidden


func _unhide(item: Node3D) -> void:
	var id: int = item.get_instance_id()
	if not _hidden_by_me.has(id):
		return
	for visual: Node3D in _hidden_by_me[id]:
		if is_instance_valid(visual):
			visual.visible = true
	_hidden_by_me.erase(id)


## true si la memoria tiene oculto el objeto (lo usan los tests)
func is_hidden(item: Node3D) -> bool:
	return _hidden_by_me.has(item.get_instance_id())


func _reset() -> void:
	for id: int in _ghosts.keys():
		_drop_ghost(id)
	for node: Node in get_tree().get_nodes_in_group(&"fog_memory"):
		_unhide(node as Node3D)
	_seen.clear()
	_seeded = false
