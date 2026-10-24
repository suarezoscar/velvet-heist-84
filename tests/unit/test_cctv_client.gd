## @file test_cctv_client.gd
## Tests de FEAT-017 en el lado del cliente y del nivel: la cámara sigue el giro replicado con
## la física apagada, señales desde el estado de red, botín en manos en modo CCTV, la luz no
## sirve al guardia sentado, el haz de linterna hace visible al ladrón para una cámara y la
## mesa del museo v2 se alcanza desde delante.
extends GutTest

const GUARD_SCENE: PackedScene = preload("res://scenes/entities/guard_player.tscn")
const THIEF_SCENE: PackedScene = preload("res://scenes/entities/thief_player.tscn")
const CAMERA_SCENE: PackedScene = preload("res://scenes/entities/security_camera.tscn")
const LAMP_SCENE: PackedScene = preload("res://scenes/entities/lamp.tscn")
const MUSEUM_V2_PATH: String = "res://data/levels/museum_v2.json"

var _saved_state: GameManager.MatchState


func before_each() -> void:
	_saved_state = GameManager.current_state
	GameManager.current_state = GameManager.MatchState.IN_PROGRESS


func after_each() -> void:
	GameManager.current_state = _saved_state


func _camera() -> SecurityCamera3D:
	var camera: SecurityCamera3D = CAMERA_SCENE.instantiate() as SecurityCamera3D
	camera.sweep_enabled = false
	add_child_autofree(camera)
	return camera


func _thief(pos: Vector3) -> ThiefController3D:
	var thief: ThiefController3D = THIEF_SCENE.instantiate() as ThiefController3D
	add_child_autofree(thief)
	thief.global_position = pos
	return thief


## NetSessionClient apaga _physics_process en el grupo net_state: el giro va en _process
func test_replica_follows_rotation_with_physics_off() -> void:
	var camera: SecurityCamera3D = _camera()
	camera.set_physics_process(false)
	camera.apply_net_state({"rot_y": 0.0})
	camera.apply_net_state({"rot_y": 0.5})
	await wait_frames(30)
	assert_almost_eq(camera.mount.rotation.y, 0.5, 0.05, "Sigue el barrido del servidor")


func test_replica_emits_detection_signals_from_net_state() -> void:
	var camera: SecurityCamera3D = _camera()
	watch_signals(camera)
	camera.apply_net_state({"alert": true})
	assert_signal_emitted(camera, "target_detected", "El monitor del mundo se pone rojo")
	camera.apply_net_state({"alert": false})
	assert_signal_emitted(camera, "target_lost")


func test_carried_loot_follows_cctv_view() -> void:
	var thief: ThiefController3D = _thief(Vector3.ZERO)
	thief.set_view_mode(ThiefController3D.ViewMode.CCTV)
	var loot: MeshInstance3D = MeshInstance3D.new()
	loot.mesh = BoxMesh.new()
	thief.carry_anchor.add_child(loot)
	assert_eq(loot.layers, 1 << (ThiefController3D.CCTV_ONLY_LAYER - 1), "Cogido: solo CCTV")
	thief.carry_anchor.remove_child(loot)
	assert_eq(loot.layers, 1, "Soltado: vuelve al mundo")
	loot.free()


func test_watching_guard_ignores_lamp_light() -> void:
	var guard: GuardController3D = GUARD_SCENE.instantiate() as GuardController3D
	add_child_autofree(guard)
	guard.apply_flashlight_state(false)
	var thief: ThiefController3D = _thief(Vector3(0.0, 0.0, -6.0))
	var lamp: Lamp3D = LAMP_SCENE.instantiate() as Lamp3D
	lamp.profile = load("res://data/balance/lamp_ceiling.tres") as LampProfile
	add_child_autofree(lamp)
	lamp.global_position = Vector3(0.0, 3.0, -6.0)
	await wait_physics_frames(2)
	var lamps: Array[Lamp3D] = [lamp]
	var senses: GuardSenses = GuardSenses.new()
	assert_eq(senses.detects(guard, thief, lamps), &"light", "De pie, la luz lo delata")
	guard.monitor_watch.state = GuardMonitorWatch.State.WATCHING
	assert_eq(senses.detects(guard, thief, lamps), &"", "Sentado, la luz no le sirve")


func test_camera_sees_thief_in_flashlight_beam() -> void:
	var camera: SecurityCamera3D = _camera()
	camera.global_position = Vector3(0.0, 2.0, 0.0)
	var thief: ThiefController3D = _thief(Vector3(0.0, 0.0, -4.0))
	var guard: GuardController3D = GUARD_SCENE.instantiate() as GuardController3D
	add_child_autofree(guard)
	guard.global_position = Vector3(0.0, 0.0, -8.0)
	guard.rotation.y = PI  # mira hacia +Z, al ladrón
	await wait_physics_frames(2)
	guard.apply_flashlight_state(false)
	assert_false(camera._check_line_of_sight(thief), "A oscuras no lo ve")
	guard.apply_flashlight_state(true)
	assert_true(camera._check_line_of_sight(thief), "Bajo el haz de una linterna sí")


func test_museum_desk_is_reached_from_the_front() -> void:
	var map: Node3D = Node3D.new()
	add_child_autofree(map)
	LevelEntitiesBuilder.build(LevelData.load_json(MUSEUM_V2_PATH), map)
	var desk: CCTVDesk3D = map.get_node("Props/CCTVDesk3D") as CCTVDesk3D
	var guard: GuardController3D = GUARD_SCENE.instantiate() as GuardController3D
	map.add_child(guard)
	guard.set_physics_process(false)  # sin suelo en este test: que no caiga
	var front: Vector3 = desk.global_position - desk.global_transform.basis.z
	guard.global_position = Vector3(front.x, 0.05, front.z)
	var to_desk: Vector3 = (desk.global_position - guard.global_position).slide(Vector3.UP)
	guard.rotation.y = atan2(-to_desk.x, -to_desk.z)
	guard.look_target_position = desk.global_position
	await wait_physics_frames(3)
	assert_eq(guard.interactor.current_target, desk, "Delante de la mesa, la enfoca")
	var monitor: Node3D = map.get_node("Props/Monitor_CAM_1") as Node3D
	var screen_dir: Vector3 = monitor.global_transform.basis.z
	assert_gt(screen_dir.dot(-desk.global_transform.basis.z), 0.9, "Pantallas hacia el guardia")
