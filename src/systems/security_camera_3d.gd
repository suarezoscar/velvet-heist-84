## @file security_camera_3d.gd
## Cámara de videovigilancia CCTV analógica de 1984.
## Realiza barridos de paneo motorizados, proyecta su imagen en un SubViewport
## y detecta al ladrón con su cono, línea de visión y solo si está iluminado (interaction.md M5).
## El barrido y la detección los simula el servidor; los clientes siguen el giro replicado.
## Mientras un guardia mira los monitores, enciende un piloto rojo de grabación (M4).
class_name SecurityCamera3D
extends Node3D

signal target_detected(target: Node3D)
signal target_lost

## Color y tamaño del piloto de grabación
const PILOT_COLOR: Color = Color(1.0, 0.05, 0.05)
const PILOT_RADIUS: float = 0.05
## Velocidad con la que un cliente sigue el giro replicado
const NET_ROT_FOLLOW: float = 10.0

## Identificador de la cámara (ej. "CAM-01: Galería")
@export var camera_id: String = "CAM-01"

## Rótulo de la imagen en el HUD (ej. "VESTÍBULO")
@export var camera_label: String = ""

## Control de barrido motorizado
@export var sweep_enabled: bool = true
@export var sweep_angle_deg: float = 65.0
@export var sweep_speed: float = 0.5

## Alcance y ángulo del cono de visión
@export var detection_range: float = 9.5
@export var detection_fov_deg: float = 52.0
@export var is_online: bool = true

var is_alert_active: bool = false
## Piloto rojo encendido: algún guardia mira los monitores
var is_recording: bool = false
var mount: Node3D = self
var _sweep_time: float = 0.0
var _base_rotation_y: float = 0.0
var _thief_ref: Node3D = null
var _net_rot_y: float = 0.0
var _has_net_rot: bool = false
var _pilot: MeshInstance3D = null
## Colisiones del propio modelo: el rayo de visión sale de dentro y no debe chocar con ellas
var _own_bodies: Array[RID] = []

@onready var internal_cam: Camera3D = get_node_or_null("SubViewport/InternalCamera3D")
@onready var cone_light: SpotLight3D = get_node_or_null("CameraMount/SpotLight3D")
@onready var sub_viewport: SubViewport = get_node_or_null("SubViewport")


func _ready() -> void:
	add_to_group(&"net_state")
	add_to_group(&"security_camera")
	if has_node("CameraMount"):
		mount = get_node("CameraMount") as Node3D
	_base_rotation_y = mount.rotation.y
	_setup_internal_camera_binding()
	if internal_cam != null:
		internal_cam.set_cull_mask_value(FogOfWar3D.FOG_LAYER, false)  # sin niebla en el CCTV
	_find_thief_reference()
	_build_pilot()
	for body: Node in find_children("*", "CollisionObject3D", true, false):
		_own_bodies.append((body as CollisionObject3D).get_rid())


func _physics_process(delta: float) -> void:
	if not is_online or not GameManager.is_simulating():
		return

	_process_sweep(delta)
	_process_detection()


## Réplica en un cliente: sigue el giro del servidor. Va en _process porque NetSessionClient
## apaga _physics_process en los nodos del grupo net_state
func _process(delta: float) -> void:
	if _has_net_rot:
		_follow_net_rotation(delta)


## true si alguna cámara del árbol de context detecta ahora al ladrón
static func any_detects(context: Node) -> bool:
	if context == null or not context.is_inside_tree():
		return false
	for node: Node in context.get_tree().get_nodes_in_group(&"security_camera"):
		if (node as SecurityCamera3D).is_alert_active:
			return true
	return false


## Enciende o apaga el piloto rojo de grabación
func set_recording(on: bool) -> void:
	is_recording = on
	if _pilot != null:
		_pilot.visible = on


## Devuelve el snapshot de estado de la cámara para red
func get_net_state() -> Dictionary:
	var cur_rot_y: float = mount.rotation.y if mount != null else rotation.y
	return {
		"alert": is_alert_active,
		"rot_y": snappedf(cur_rot_y, 0.001),
		"rec": is_recording,
	}


## Aplica el snapshot de estado recibido por red
func apply_net_state(state: Dictionary) -> void:
	if state.has("rot_y"):
		# Solo el barrido local: la raíz conserva la orientación que trae la escena
		_net_rot_y = float(state["rot_y"])
		if not _has_net_rot or not is_inside_tree():
			(mount if mount != null else self).rotation.y = _net_rot_y
		_has_net_rot = true
	if state.has("alert"):
		var was_alert: bool = is_alert_active
		is_alert_active = bool(state["alert"])
		_set_cone_alert(is_alert_active)
		if is_alert_active and not was_alert:
			target_detected.emit(_thief_ref)
		elif was_alert and not is_alert_active:
			target_lost.emit()
	if state.has("rec"):
		set_recording(bool(state["rec"]))


## Cliente: sigue con suavidad el giro que replica el servidor
func _follow_net_rotation(delta: float) -> void:
	var target: Node3D = mount if mount != null else self
	target.rotation.y = lerp_angle(
		target.rotation.y, _net_rot_y, clampf(NET_ROT_FOLLOW * delta, 0.0, 1.0)
	)


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


## true si la cámara ve un punto: en su cono y alcance, sin muros de por medio (los muebles no
## tapan). heist.md R6 la usa para los pedestales vacíos
func sees_point(point: Vector3) -> bool:
	var to_point: Vector3 = point - mount.global_position
	if to_point.length() > detection_range or to_point.length() < 0.2:
		return false
	var forward: Vector3 = -mount.global_transform.basis.z.normalized()
	if rad_to_deg(forward.angle_to(to_point.normalized())) > detection_fov_deg * 0.5:
		return false
	return VisionLogic.wall_free(get_world_3d().direct_space_state, mount.global_position, point)


func _check_line_of_sight(target: Node3D) -> bool:
	if target is ThiefController3D and (target as ThiefController3D).in_vent:
		return false  # FEAT-034: por la ventilación no se le ve
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
		cam_pos, target_center, 1, _own_bodies
	)
	var result: Dictionary = space_state.intersect_ray(q)
	return result.is_empty() and _is_target_lit(target)


## M5: un CCTV de 1984 no ve a oscuras; el ladrón tiene que estar bajo una lámpara o un haz
func _is_target_lit(target: Node3D) -> bool:
	var thief: ThiefController3D = target as ThiefController3D
	if thief == null:
		return true
	var lamps: Array[Lamp3D] = []
	for node: Node in get_tree().get_nodes_in_group(&"lamps"):
		if node is Lamp3D:
			lamps.append(node as Lamp3D)
	var guards: Array[GuardController3D] = []
	for node: Node in get_tree().get_nodes_in_group(&"guards"):
		if node is GuardController3D:
			guards.append(node as GuardController3D)
	return ThiefExposure.compute(thief, guards, lamps) != &"shadow"


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


func _build_pilot() -> void:
	_pilot = MeshInstance3D.new()
	_pilot.name = "RecordingPilot"
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = PILOT_RADIUS
	sphere.height = PILOT_RADIUS * 2.0
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = PILOT_COLOR
	material.emission_enabled = true
	material.emission = PILOT_COLOR
	material.emission_energy_multiplier = 3.0
	sphere.material = material
	_pilot.mesh = sphere
	_pilot.position = Vector3(0.0, 0.15, 0.0)
	_pilot.visible = is_recording
	mount.add_child(_pilot)
