## @file test_isometric_gym.gd
## Controlador de nivel para el gimnasio de pruebas isométrico 3D.
## Conecta el bus de eventos acústicos, asigna la cámara a los personajes,
## vincula el HUD y coordina las reglas de percepción y combate cuerpo a cuerpo.
extends Node3D

const SoundWave3DType = preload("res://src/vfx/sound_wave_3d.gd")

@onready var camera: Camera3D = $IsometricCamera3D
@onready var thief: CharacterBody3D = $Thief
@onready var guard: CharacterBody3D = $Guard
@onready var hud: CanvasLayer = $HUD84 if has_node("HUD84") else null

func _ready() -> void:
	_subscribe_acoustic_events()
	_bind_player_cameras()
	_bind_hud()
	_start_match()

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

func _physics_process(_delta: float) -> void:
	_process_guard_perception()
	_process_guard_melee_input()

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

## Procesa el golpe de porra del guardia al presionar la acción de ataque
func _process_guard_melee_input() -> void:
	var strike_pressed: bool = Input.is_action_just_pressed("strike") if InputMap.has_action("strike") else false
	if strike_pressed and guard != null and guard.has_method("swing_baton") and thief is ThiefController3D:
		guard.call("swing_baton", thief)

func _on_noise_emitted(pos: Vector3, radius: float, team: StringName) -> void:
	SoundWave3DType.create_at(self, pos, radius, team)
