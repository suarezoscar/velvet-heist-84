## @file museum_velvet_84.gd
## Controlador del mapa principal "Museo Metropolitano 1984" (Velvet Heist 84).
## Coordina la cámara isométrica suave, la vinculación en tiempo real del sistema CCTV,
## la gestión de percepción de los 2 guardias y las ondas acústicas analógicas.
extends Node3D

const SoundWave3DType = preload("res://src/vfx/sound_wave_3d.gd")

@onready var camera: Camera3D = $IsometricCamera3D
@onready var thief: CharacterBody3D = $ThiefPlayer
@onready var guard_1: CharacterBody3D = $GuardPlayer1
@onready var guard_2: CharacterBody3D = $GuardPlayer2
@onready var hud: CanvasLayer = $HUD84 if has_node("HUD84") else null

var _camera_target_pos: Vector3 = Vector3.ZERO
var _camera_offset: Vector3 = Vector3(10.0, 11.5, 10.0)

func _ready() -> void:
	_hide_collision_helpers(self)
	_subscribe_acoustic_events()
	_bind_player_cameras()
	_bind_cctv_monitors()
	_bind_hud()
	_start_match()
	if thief != null:
		_camera_target_pos = thief.global_position + _camera_offset
		if camera != null:
			camera.global_position = _camera_target_pos

func _hide_collision_helpers(node: Node) -> void:
	if node is MeshInstance3D:
		if node.name.ends_with("-col") or node.name.ends_with("-colonly") or node.name == "Car" or node.name == "marble_bust":
			node.visible = false
	for child in node.get_children():
		_hide_collision_helpers(child)

func _subscribe_acoustic_events() -> void:
	var bus: Node = get_node_or_null("/root/SignalBus")
	if bus != null and bus.has_signal("noise_emitted_3d"):
		bus.connect("noise_emitted_3d", _on_noise_emitted)

func _bind_player_cameras() -> void:
	if thief != null and "camera" in thief:
		thief.set("camera", camera)
	if guard_1 != null and "camera" in guard_1:
		guard_1.set("camera", camera)
	if guard_2 != null and "camera" in guard_2:
		guard_2.set("camera", camera)

func _bind_cctv_monitors() -> void:
	var cam_1 = get_node_or_null("Props/SecurityCamera_01")
	var cam_2 = get_node_or_null("Props/SecurityCamera_02")
	var mon_1 = get_node_or_null("Props/CCTVMonitor_01")
	var mon_2 = get_node_or_null("Props/CCTVMonitor_02")
	if mon_1 != null and cam_1 != null and mon_1.has_method("bind_camera"):
		mon_1.call("bind_camera", cam_1)
	if mon_2 != null and cam_2 != null and mon_2.has_method("bind_camera"):
		mon_2.call("bind_camera", cam_2)

func _bind_hud() -> void:
	if hud != null and thief != null:
		hud.set("target_player", thief)
		var bp_overlay = hud.get_node_or_null("BlueprintMapOverlay")
		if bp_overlay != null:
			bp_overlay.set("player_pawn", thief)

func _start_match() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("start_match"):
		gm.call("start_match")

func _physics_process(delta: float) -> void:
	_process_camera_follow(delta)
	_process_guards_perception()
	_process_guard_melee_input()

func _process_camera_follow(delta: float) -> void:
	if camera == null or thief == null:
		return
	var desired_pos: Vector3 = thief.global_position + _camera_offset
	camera.global_position = camera.global_position.lerp(desired_pos, 6.0 * delta)

## Evalúa detección de ambos guardias hacia el ladrón
func _process_guards_perception() -> void:
	if thief == null:
		return
	
	var is_spotted: bool = false
	if guard_1 != null and guard_1.has_method("check_detection_on_thief"):
		is_spotted = is_spotted or bool(guard_1.call("check_detection_on_thief", thief))
	if guard_2 != null and guard_2.has_method("check_detection_on_thief"):
		is_spotted = is_spotted or bool(guard_2.call("check_detection_on_thief", thief))
	
	if thief.has_method("set_stealth_visibility"):
		thief.call("set_stealth_visibility", is_spotted)
	
	if is_spotted:
		var bus: Node = get_node_or_null("/root/SignalBus")
		if bus != null and bus.has_signal("thief_spotted"):
			bus.emit_signal("thief_spotted", thief.global_position)

func _process_guard_melee_input() -> void:
	var strike_pressed: bool = Input.is_action_just_pressed("strike") if InputMap.has_action("strike") else false
	if strike_pressed and guard_1 != null and guard_1.has_method("swing_baton") and thief is CharacterBody3D:
		guard_1.call("swing_baton", thief)

func _on_noise_emitted(pos: Vector3, radius: float, team: StringName) -> void:
	var wave: Node3D = SoundWave3DType.new()
	wave.set("max_radius", radius)
	wave.set("pulse_speed", 9.0)
	wave.set("wave_color", Color(0.3, 0.7, 1.0, 0.75) if team == &"thief" else Color(1.0, 0.4, 0.2, 0.75))
	add_child(wave)
	wave.global_position = pos + Vector3(0.0, 0.05, 0.0)
