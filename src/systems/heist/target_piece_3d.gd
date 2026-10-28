## @file target_piece_3d.gd
## Pieza candidata del encargo (heist.md R1 y R9): pedestal con su pieza y una protección.
## - Combinación: la guarda un candado (SafeBox3D: vitrina o caja fuerte). Abierto, E la coge en
##   silencio. Una vitrina se puede romper a lo bruto (Q); la caja fuerte, no.
## - Presión y sensor: en esta entrega solo a lo bruto (E o Q); el cambiazo y el corte de
##   corriente llegan después.
## A lo bruto suena la campana (ruido de RULES.brute_radius). Solo el ladrón puede robarla, y
## solo si está en su encargo. Una marca encima la señala: rosa al ladrón si es de su encargo y
## cian a los guardias en todas las candidatas (saben cuáles son, no cuáles busca).
class_name TargetPiece3D
extends Area3D

const RULES: HeistRules = preload("res://data/balance/heist_rules.tres")
const PEDESTAL_SIZE: Vector3 = Vector3(0.7, 1.0, 0.7)
const MODEL_SIZE: float = 0.6
const MARKER_HEIGHT: float = 2.3
const SILENT_RADIUS: float = 2.5

var piece_id: StringName = &""
var piece_name: String = ""
var room_name: String = ""
## &"combination", &"pressure" o &"sensor"
var protection: StringName = &"combination"
## Candado de las piezas de combinación (null en las demás)
var lock: SafeBox3D = null
var variant: StringName = &"pedestal"
var stolen: bool = false
var model: Node3D = null
var marker: Label3D = null
var _marker_timer: float = 0.0


## Crea la pieza (sin añadirla): model_scene es el modelo que se coloca sobre el pedestal
## variant: &"pedestal" (sobre su pedestal), &"case" (sobre la vitrina, que es su candado) o
## &"safe" (dentro de la caja fuerte: no se ve hasta abrirla)
static func create(
	id: StringName,
	display_name: String,
	kind: StringName,
	model_scene: PackedScene,
	variant: StringName = &"pedestal"
) -> TargetPiece3D:
	var piece: TargetPiece3D = TargetPiece3D.new()
	piece.piece_id = id
	piece.piece_name = display_name
	piece.protection = kind
	piece.variant = variant
	piece.name = "Target_%s" % id
	piece._build(model_scene)
	return piece


func _ready() -> void:
	add_to_group(&"net_state")
	add_to_group(&"heist_targets")
	collision_layer = 4  # Interactuable
	collision_mask = 2
	monitoring = true


func _process(delta: float) -> void:
	_marker_timer -= delta
	if _marker_timer > 0.0:
		return
	_marker_timer = 0.25
	if variant == &"safe" and model != null and lock != null:
		model.visible = not stolen and lock.current_state == SafeBox3D.SafeState.OPENED
	_update_marker()


## El ladrón puede ir a por ella: sigue en su sitio y está en su encargo
func is_available(actor: Node3D) -> bool:
	return not stolen and actor is ThiefController3D and _in_contract()


func can_interact(actor: Node3D = null) -> bool:
	if not is_available(actor):
		return false
	return lock == null or lock.current_state == SafeBox3D.SafeState.OPENED


func get_interaction_text(_actor: Node3D = null) -> String:
	if lock != null:
		return "Coger %s [E]" % piece_name
	return "Robar %s a lo bruto: salta la alarma [E]" % piece_name


## E: coger la pieza (en silencio si el candado está abierto; a lo bruto si no tiene candado)
func interact(actor: Node3D) -> void:
	if can_interact(actor):
		steal(lock == null)


## Q: a lo bruto. Vale si no hay candado o es una vitrina (la caja fuerte no se rompe)
func can_force(actor: Node3D) -> bool:
	if not is_available(actor):
		return false
	return lock == null or lock.breakable or lock.current_state == SafeBox3D.SafeState.OPENED


func force(actor: Node3D) -> bool:
	if not can_force(actor):
		return false
	steal(lock == null or lock.current_state != SafeBox3D.SafeState.OPENED)
	return true


## Autoridad: la pieza desaparece del pedestal y cuenta para el encargo
func steal(brute: bool) -> void:
	if stolen:
		return
	stolen = true
	if lock != null and lock.current_state != SafeBox3D.SafeState.OPENED:
		lock.break_open()
	_apply_stolen()
	if GameManager.heist != null:
		GameManager.heist.mark_stolen(piece_id)
	var thief: Node3D = get_tree().get_first_node_in_group(&"thief") as Node3D
	var kind: StringName = NoiseEmit.MECHANISM if brute else NoiseEmit.IMPACT
	var radius: float = RULES.brute_radius if brute else SILENT_RADIUS
	NoiseEmit.emit(global_position, radius, &"thief", kind, thief)
	print("[TargetPiece3D] %s robada%s" % [piece_name, " a lo bruto" if brute else ""])


func get_net_state() -> Dictionary:
	return {"stolen": stolen}


func apply_net_state(state: Dictionary) -> void:
	if bool(state.get("stolen", false)) and not stolen:
		stolen = true
		_apply_stolen()


func _apply_stolen() -> void:
	if model != null:
		model.visible = false
	_update_marker()


func _in_contract() -> bool:
	return GameManager.heist != null and GameManager.heist.is_in_contract(piece_id)


## Rosa para el ladrón local si es de su encargo y sigue en su sitio; cian para los guardias
func _update_marker() -> void:
	if marker == null:
		return
	if HeistDirector.local_is_thief(get_tree()):
		marker.visible = _in_contract() and not stolen
		marker.modulate = TeamMarker3D.THIEF_COLOR
	else:
		marker.visible = not NetManager.is_dedicated_server
		marker.modulate = TeamMarker3D.GUARD_COLOR


func _build(model_scene: PackedScene) -> void:
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = PEDESTAL_SIZE + Vector3(0.6, 0.8, 0.6)
	var col: CollisionShape3D = CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0.0, shape.size.y * 0.5, 0.0)
	add_child(col)
	if variant == &"pedestal":
		_build_pedestal()
	if model_scene != null:
		model = model_scene.instantiate() as Node3D
		model.name = "Piece"
		add_child(model)
		_fit_model()
		model.visible = variant != &"safe"
	marker = Label3D.new()
	marker.name = "Marker"
	marker.text = "◆"
	marker.font_size = 48
	marker.pixel_size = 0.006
	marker.no_depth_test = true
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.outline_size = 12
	marker.position = Vector3(0.0, MARKER_HEIGHT, 0.0)
	marker.visible = false
	add_child(marker)


## Pedestal con colisión (las piezas de vitrina o de caja fuerte usan su candado)
func _build_pedestal() -> void:
	var pedestal: StaticBody3D = StaticBody3D.new()
	pedestal.name = "Pedestal"
	var box: BoxShape3D = BoxShape3D.new()
	box.size = PEDESTAL_SIZE
	var body_col: CollisionShape3D = CollisionShape3D.new()
	body_col.shape = box
	pedestal.add_child(body_col)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = PEDESTAL_SIZE
	mesh.mesh = box_mesh
	pedestal.add_child(mesh)
	pedestal.position = Vector3(0.0, PEDESTAL_SIZE.y * 0.5, 0.0)
	add_child(pedestal)


## Escala el modelo a MODEL_SIZE y lo apoya sobre el pedestal
func _fit_model() -> void:
	var bounds: AABB = AABB()
	var first: bool = true
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node: MeshInstance3D = node as MeshInstance3D
		var local: AABB = mesh_node.transform * mesh_node.get_aabb()
		bounds = local if first else bounds.merge(local)
		first = false
	if first:
		return
	var biggest: float = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	var factor: float = MODEL_SIZE / biggest if biggest > 0.0 else 1.0
	model.scale = Vector3.ONE * factor
	model.position = Vector3(0.0, PEDESTAL_SIZE.y - bounds.position.y * factor, 0.0)
