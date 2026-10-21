## @file mansion_belmonte.gd
## Controlador de nivel para "Villa Belmonte - Planta Principal".
## Coordina la cámara isométrica con seguimiento suave, el HUD analógico,
## los eventos acústicos de ondas sonoras y la percepción del guardia.
extends Node3D

const SoundWave3DType = preload("res://src/vfx/sound_wave_3d.gd")

@onready var camera: Camera3D = $IsometricCamera3D
@onready var thief: CharacterBody3D = $ThiefPlayer
@onready var guard: CharacterBody3D = $GuardPlayer
@onready var hud: CanvasLayer = $HUD84 if has_node("HUD84") else null

## Posición objetivo de la cámara para interpolación suave
var _camera_target_pos: Vector3 = Vector3.ZERO
var _camera_offset: Vector3 = Vector3(10.0, 11.5, 10.0)

func _ready() -> void:
	_hide_collision_helpers(self)
	_subscribe_acoustic_events()
	_bind_player_cameras()
	_bind_hud()
	_start_match()
	if thief:
		_camera_target_pos = thief.global_position + _camera_offset
		if camera:
			camera.global_position = _camera_target_pos

## Oculta mallas auxiliares de colisión para evitar Z-fighting visual
func _hide_collision_helpers(node: Node) -> void:
	if node is MeshInstance3D:
		if node.name.ends_with("-col") or node.name.ends_with("-colonly") or node.name == "Car":
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
	if guard != null and "camera" in guard:
		guard.set("camera", camera)

func _bind_hud() -> void:
	if hud != null and thief != null:
		hud.set("target_player", thief)

func _start_match() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("start_match"):
		gm.call("start_match")

func _physics_process(delta: float) -> void:
	_process_camera_follow(delta)
	_process_guard_perception()
	_process_guard_melee_input()

## Seguimiento isométrico suave de la cámara
func _process_camera_follow(delta: float) -> void:
	if camera == null or thief == null:
		return
	var desired_pos: Vector3 = thief.global_position + _camera_offset
	camera.global_position = camera.global_position.lerp(desired_pos, 6.0 * delta)

## Evalúa la detección del guardia hacia el ladrón y notifica al SignalBus
func _process_guard_perception() -> void:
	if guard != null and thief != null and guard.has_method("check_detection_on_thief"):
		var is_spotted: bool = bool(guard.call("check_detection_on_thief", thief))
		if thief.has_method("set_stealth_visibility"):
			thief.call("set_stealth_visibility", is_spotted)
		if is_spotted:
			var bus: Node = get_node_or_null("/root/SignalBus")
			if bus != null and bus.has_signal("thief_spotted"):
				bus.emit_signal("thief_spotted", thief.global_position)

## Procesa el golpe de porra del guardia
func _process_guard_melee_input() -> void:
	var strike_pressed: bool = Input.is_action_just_pressed("strike") if InputMap.has_action("strike") else false
	if strike_pressed and guard != null and guard.has_method("swing_baton") and thief is ThiefController3D:
		guard.call("swing_baton", thief)

func _on_noise_emitted(pos: Vector3, radius: float, team: StringName) -> void:
	var wave: Node3D = SoundWave3DType.new()
	wave.set("max_radius", radius)
	wave.set("pulse_speed", 9.0)
	wave.set("wave_color", Color(0.3, 0.7, 1.0, 0.75) if team == &"thief" else Color(1.0, 0.4, 0.2, 0.75))
	add_child(wave)
	wave.global_position = pos + Vector3(0.0, 0.05, 0.0)
