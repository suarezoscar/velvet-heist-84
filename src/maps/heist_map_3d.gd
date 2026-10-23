## @file heist_map_3d.gd
## Base común de los mapas jugables. Localiza al ladrón y a los guardias hijos directos,
## decide qué personaje controla esta máquina (como mucho uno), sigue a ese personaje con
## la cámara isométrica, vincula el HUD, evalúa la percepción de los guardias, ejecuta el
## golpe de porra del jugador local y dibuja las ondas de sonido.
## Dependencias: SignalBus, NetManager, GameManager. Nodos opcionales: IsometricCamera3D, HUD84.
class_name HeistMap3D
extends Node3D

## Desplazamiento de la cámara respecto al personaje seguido (ángulo isométrico)
const CAMERA_OFFSET: Vector3 = Vector3(10.0, 11.5, 10.0)
const CAMERA_FOLLOW_SPEED: float = 6.0

## Teclas de depuración (solo sin red y en builds de depuración) para cambiar de personaje:
## F1 = ladrón, F2.. = guardias en orden de escena.
const DEBUG_SWITCH_KEYS: Array[Key] = [KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5]

## Sufijos de mallas auxiliares de colisión importadas desde Blender que no deben verse
const COLLISION_HELPER_SUFFIXES: Array[String] = ["-col", "-colonly"]

const NOISE_RING_STYLE: NoiseRingStyle = preload("res://assets/ui/noise_ring_style.tres")

var camera: Camera3D = null
var hud: HUD84 = null
var thief: ThiefController3D = null
var guards: Array[GuardController3D] = []

## Personaje controlado por esta máquina (null en un servidor dedicado)
var local_player: PlayerBase3D = null

## IA de cada guardia según la escena, para devolvérsela al soltar el control de depuración
var _ai_defaults: Dictionary = {}


func _ready() -> void:
	camera = get_node_or_null("IsometricCamera3D") as Camera3D
	hud = get_node_or_null("HUD84") as HUD84
	_collect_actors()
	for guard: GuardController3D in guards:
		_ai_defaults[guard] = guard.is_ai_controlled
	_hide_collision_helpers(self)
	SignalBus.noise_emitted_3d.connect(_on_noise_emitted)
	for actor: PlayerBase3D in get_actors():
		actor.camera = camera
	_on_map_ready()
	if NetManager.is_online():
		_setup_online_control()
	else:
		_setup_offline_control()
	GameManager.start_match()


## Personajes en orden fijo: ladrón primero y después los guardias en orden de escena
func get_actors() -> Array[PlayerBase3D]:
	var actors: Array[PlayerBase3D] = []
	if thief != null:
		actors.append(thief)
	for guard: GuardController3D in guards:
		actors.append(guard)
	return actors


## Fija el personaje controlado por esta máquina y libera a los demás del teclado.
func set_local_player(player: PlayerBase3D) -> void:
	local_player = player
	for actor: PlayerBase3D in get_actors():
		actor.is_locally_controlled = actor == player
		if actor is GuardController3D and actor == player:
			(actor as GuardController3D).is_ai_controlled = false
	var followed: Node3D = get_followed_actor()
	if hud != null:
		hud.target_player = followed
		var overlay: Node = hud.get_node_or_null("BlueprintMapOverlay")
		if overlay != null:
			overlay.set("player_pawn", followed)
	if camera != null and followed != null:
		camera.global_position = followed.global_position + CAMERA_OFFSET
	_update_thief_local_visibility()


## Personaje que sigue la cámara: el local o, sin él (servidor dedicado), el ladrón
func get_followed_actor() -> PlayerBase3D:
	return local_player if local_player != null else thief


## Gancho para la configuración propia de cada mapa (CCTV, etc.), antes del control.
func _on_map_ready() -> void:
	pass


## Sin red: el jugador controla al ladrón; los guardias quedan quietos o con su IA.
func _setup_offline_control() -> void:
	set_local_player(thief)


## Con red: cada mapa decide según los roles de NetManager. Por defecto, el ladrón.
func _setup_online_control() -> void:
	set_local_player(thief)


## Nombres de mallas extra a ocultar en este mapa (además de las de colisión)
func _extra_hidden_mesh_names() -> Array[String]:
	return []


func _collect_actors() -> void:
	guards.clear()
	for child: Node in get_children():
		if child is ThiefController3D and thief == null:
			thief = child
		elif child is GuardController3D:
			guards.append(child)


func _hide_collision_helpers(node: Node) -> void:
	if node is MeshInstance3D:
		var node_name: String = node.name
		var hide: bool = _extra_hidden_mesh_names().has(node_name)
		for suffix: String in COLLISION_HELPER_SUFFIXES:
			hide = hide or node_name.ends_with(suffix)
		if hide:
			(node as MeshInstance3D).visible = false
	for child: Node in node.get_children():
		_hide_collision_helpers(child)


func _unhandled_input(event: InputEvent) -> void:
	if NetManager.is_online() or not OS.is_debug_build():
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	var index: int = DEBUG_SWITCH_KEYS.find(key_event.keycode)
	var actors: Array[PlayerBase3D] = get_actors()
	if index >= 0 and index < actors.size():
		var previous: GuardController3D = local_player as GuardController3D
		if previous != null:
			previous.is_ai_controlled = _ai_defaults.get(previous, false)
		set_local_player(actors[index])
		_update_thief_local_visibility()
		print("[HeistMap3D] Control de depuración -> %s" % actors[index].name)
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	_process_camera_follow(delta)
	if not NetManager.is_online() or multiplayer.is_server():
		_process_guards_perception(delta)
	_process_local_strike()


func _process_camera_follow(delta: float) -> void:
	var target: Node3D = get_followed_actor()
	if camera == null or target == null:
		return
	var desired_pos: Vector3 = target.global_position + CAMERA_OFFSET
	camera.global_position = camera.global_position.lerp(desired_pos, CAMERA_FOLLOW_SPEED * delta)


## Percepción autoritativa: actualiza la percepción de cada guardia y la visibilidad local
func _process_guards_perception(delta: float) -> void:
	if thief == null:
		return
	var lamps: Array[Lamp3D] = []
	for node: Node in get_tree().get_nodes_in_group(&"lamps"):
		if node is Lamp3D:
			lamps.append(node as Lamp3D)
	var any_spotted: bool = false
	for guard: GuardController3D in guards:
		guard.update_perception(thief, lamps, delta)
		if guard.is_perceiving_thief:
			any_spotted = true
	thief.set_stealth_visibility(any_spotted)
	_update_thief_local_visibility()


func _update_thief_local_visibility() -> void:
	if thief == null:
		return
	var is_visible: bool = (
		local_player == thief
		or (
			local_player is GuardController3D
			and (local_player as GuardController3D).is_perceiving_thief
		)
	)
	thief.set_visible_to_local_viewer(is_visible)


func _process_local_strike() -> void:
	var guard: GuardController3D = local_player as GuardController3D
	if guard == null or thief == null:
		return
	if InputMap.has_action(&"strike") and Input.is_action_just_pressed(&"strike"):
		_perform_strike(guard)


## Golpe del guardia local. Los mapas con red lo redirigen al servidor.
func _perform_strike(guard: GuardController3D) -> void:
	guard.swing_baton(thief)


func _on_noise_emitted(pos: Vector3, radius: float, _team: StringName) -> void:
	if radius <= 0.0:
		return
	if not PerceptionRules.ring_visible_to(local_player, pos, radius):
		return
	# Provisional hasta PKG-2: ring_lifetime_event (2.0) y ring_grow_time (0.4)
	# de data/balance/noise_rings.tres
	SoundWave3D.create_at(self, pos, radius, &"impact", &"other", 2.0, 0.4, NOISE_RING_STYLE)
