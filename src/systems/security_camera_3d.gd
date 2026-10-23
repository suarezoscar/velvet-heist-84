## @file security_camera_3d.gd
## Cámara de videovigilancia CCTV analógica de 1984.
## Realiza barridos de paneo motorizados, proyecta su imagen en un SubViewport
## y detecta visualmente al ladrón mediante cono angular y PhysicsRayQueryParameters3D.
class_name SecurityCamera3D
extends Node3D

signal target_detected(target: Node3D)
signal target_lost

## Identificador de la cámara (ej. "CAM-01: Galería")
@export var camera_id: String = "CAM-01"

## Control de barrido motorizado
@export var sweep_enabled: bool = true
@export var sweep_angle_deg: float = 65.0
@export var sweep_speed: float = 0.5

## Alcance y ángulo del cono de visión
@export var detection_range: float = 9.5
@export var detection_fov_deg: float = 52.0
@export var is_online: bool = true

var is_alert_active: bool = false
var mount: Node3D = self
var _sweep_time: float = 0.0
var _base_rotation_y: float = 0.0
var _thief_ref: Node3D = null

@onready var internal_cam: Camera3D = get_node_or_null("SubViewport/InternalCamera3D")
@onready var cone_light: SpotLight3D = get_node_or_null("CameraMount/SpotLight3D")
@onready var sub_viewport: SubViewport = get_node_or_null("SubViewport")


func _ready() -> void:
	add_to_group(&"net_state")
	if has_node("CameraMount"):
		mount = get_node("CameraMount") as Node3D
	_base_rotation_y = mount.rotation.y
	_setup_internal_camera_binding()
	_find_thief_reference()


func _physics_process(delta: float) -> void:
	if not is_online:
		return

	_process_sweep(delta)
	_process_detection()


## Devuelve el snapshot de estado de la cámara para red
func get_net_state() -> Dictionary:
	var cur_rot_y: float = mount.rotation.y if mount != null else rotation.y
	return {
		"alert": is_alert_active,
		"rot_y": cur_rot_y,
	}


## Aplica el snapshot de estado recibido por red
func apply_net_state(state: Dictionary) -> void:
	if state.has("rot_y"):
		# Solo el barrido local: la raíz conserva la orientación que trae la escena
		var target: Node3D = mount if mount != null else self
		target.rotation.y = float(state["rot_y"])
	if state.has("alert"):
		is_alert_active = bool(state["alert"])
		_set_cone_alert(is_alert_active)


func _setup_internal_camera_binding() -> void:
	var remote: RemoteTransform3D = get_node_or_null("CameraMount/RemoteTransform3D")
	if remote != null and internal_cam != null:
		remote.remote_path = internal_cam.get_path()


func _find_thief_reference() -> void:
	var thief: Node = get_tree().get_first_node_in_group("thief")
	if thief != null and thief is Node3D:
		_thief_ref = thief as Node3D
	else:
		_thief_ref = get_node_or_null("../ThiefPlayer") as Node3D


## Oscilación sinusoidal de barrido horizontal
func _process_sweep(delta: float) -> void:
	if not sweep_enabled:
		return
	_sweep_time += delta * sweep_speed
	var offset_rad: float = deg_to_rad(sweep_angle_deg * 0.5) * sin(_sweep_time)
	mount.rotation.y = _base_rotation_y + offset_rad


## Comprobación física de detección del ladrón
func _process_detection() -> void:
	if _thief_ref == null:
		_find_thief_reference()
		return

	var can_see: bool = _check_line_of_sight(_thief_ref)
	if can_see and not is_alert_active:
		is_alert_active = true
		target_detected.emit(_thief_ref)
		_notify_detection_to_bus(_thief_ref.global_position)
		_set_cone_alert(true)
	elif not can_see and is_alert_active:
		is_alert_active = false
		target_lost.emit()
		_set_cone_alert(false)


func _check_line_of_sight(target: Node3D) -> bool:
	var cam_pos: Vector3 = mount.global_position
	var target_center: Vector3 = target.global_position + Vector3(0.0, 0.8, 0.0)
	var to_target: Vector3 = target_center - cam_pos
	var dist: float = to_target.length()

	if dist > detection_range or dist < 0.2:
		return false

	var forward: Vector3 = -mount.global_transform.basis.z.normalized()
	var angle_to_target: float = rad_to_deg(forward.angle_to(to_target.normalized()))
	if angle_to_target > detection_fov_deg * 0.5:
		return false

	if get_world_3d() == null:
		return false
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space_state == null:
		return false
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		cam_pos, target_center, 1
	)
	var result: Dictionary = space_state.intersect_ray(q)
	return result.is_empty()


func _notify_detection_to_bus(pos: Vector3) -> void:
	SignalBus.thief_spotted.emit(pos)


func _set_cone_alert(alert: bool) -> void:
	if cone_light:
		cone_light.light_color = Color(1.0, 0.2, 0.2) if alert else Color(0.85, 0.95, 0.75)
		cone_light.light_energy = 2.2 if alert else 0.8


func get_viewport_texture() -> ViewportTexture:
	if sub_viewport:
		return sub_viewport.get_texture()
	return null
