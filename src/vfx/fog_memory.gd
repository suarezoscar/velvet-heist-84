## @file fog_memory.gd
## Memoria del botín en la niebla (vision.md D4). Lo que no ves se queda como lo viste por
## última vez: si un objeto del grupo fog_memory desaparece o se mueve de un sitio que no ves,
## queda un fantasma hasta que vuelves a mirar; un objeto nuevo que no has visto (el botín de
## la caja fuerte) no aparece hasta que lo ves. Al empezar, todo cuenta como visto (el plano).
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
		elif not _seen.has(id):
			_hide(item)
	_seeded = true
	for id: int in _seen.keys():
		_update_record(id)


## Fantasmas que hay ahora (los usan los tests)
func ghost_count() -> int:
	return _ghosts.size()


func _remember(item: Node3D) -> void:
	if not item.is_visible_in_tree() and not _hidden_by_me.has(item.get_instance_id()):
		return
	_seen[item.get_instance_id()] = {
		"xform": item.global_transform, "scene": item.scene_file_path, "ref": weakref(item)
	}


func _update_record(id: int) -> void:
	var record: Dictionary = _seen[id]
	var item: Node3D = (record["ref"] as WeakRef).get_ref() as Node3D
	var origin: Vector3 = (record["xform"] as Transform3D).origin
	var gone: bool = (
		item == null
		or not item.is_visible_in_tree()
		or item.global_position.distance_to(origin) > MOVED_DISTANCE
	)
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


func _hide(item: Node3D) -> void:
	if item.visible:
		item.visible = false
		_hidden_by_me[item.get_instance_id()] = true


func _unhide(item: Node3D) -> void:
	if _hidden_by_me.erase(item.get_instance_id()):
		item.visible = true


func _reset() -> void:
	for id: int in _ghosts.keys():
		_drop_ghost(id)
	for node: Node in get_tree().get_nodes_in_group(&"fog_memory"):
		_unhide(node as Node3D)
	_seen.clear()
	_seeded = false
