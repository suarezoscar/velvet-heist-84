## @file interaction_outline_3d.gd
## Contorno suave y no destructivo del interactivo elegido (#113).
## Duplica solo las mallas al cambiar el foco; nunca altera materiales ni assets del original.
class_name InteractionOutline3D
extends Node

const OUTLINE_SHADER: Shader = preload("res://assets/shaders/interaction_outline.gdshader")
const DUPLICATE_META: StringName = &"interaction_outline_duplicate"

## Objetivo de la escena aislada de prueba; el interactor asigna el foco por código
@export var preview_target: NodePath = NodePath("")

var _target: Node3D = null
var _material: ShaderMaterial = null
var _duplicates: Array[MeshInstance3D] = []


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = OUTLINE_SHADER
	if not preview_target.is_empty():
		show_target(get_node_or_null(preview_target) as Node3D)


## Muestra el contorno de las mallas del objetivo y lo retira del objetivo anterior
func show_target(target: Node3D) -> void:
	if target == _target:
		return
	clear()
	_target = target
	if _target == null:
		return
	var sources: Array[MeshInstance3D] = []
	if _target is MeshInstance3D:
		sources.append(_target as MeshInstance3D)
	for node: Node in _target.find_children("*", "MeshInstance3D", true, false):
		var source: MeshInstance3D = node as MeshInstance3D
		if source.mesh != null and not source.has_meta(DUPLICATE_META):
			sources.append(source)
	for source: MeshInstance3D in sources:
		var duplicate: MeshInstance3D = MeshInstance3D.new()
		duplicate.name = "InteractionOutline"
		duplicate.mesh = source.mesh
		duplicate.transform = Transform3D.IDENTITY
		duplicate.material_override = _material
		duplicate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		duplicate.set_meta(DUPLICATE_META, true)
		source.add_child(duplicate)
		_duplicates.append(duplicate)


## Retira todos los duplicados sin tocar el objetivo ni sus materiales
func clear() -> void:
	_target = null
	for duplicate: MeshInstance3D in _duplicates:
		if is_instance_valid(duplicate):
			duplicate.hide()
			duplicate.queue_free()
	_duplicates.clear()


func _exit_tree() -> void:
	clear()
