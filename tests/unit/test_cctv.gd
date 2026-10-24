## @file test_cctv.gd
## Tests de los monitores CCTV (FEAT-017, interaction.md parte M): sentarse y levantarse,
## una sola silla, pilotos, visión apagada mirando, cámaras que necesitan luz, vista
## "solo CCTV" del ladrón, filtro de red por guardia e IA.
extends GutTest

const RULES: CCTVRules = preload("res://data/balance/cctv_rules.tres")
const GUARD_SCENE: PackedScene = preload("res://scenes/entities/guard_player.tscn")
const THIEF_SCENE: PackedScene = preload("res://scenes/entities/thief_player.tscn")
const CAMERA_SCENE: PackedScene = preload("res://scenes/entities/security_camera.tscn")
const LAMP_SCENE: PackedScene = preload("res://scenes/entities/lamp.tscn")
const GUARD_AI_SCRIPT: Script = preload("res://src/entities/guard/guard_ai_3d.gd")

var _saved_state: GameManager.MatchState


func before_each() -> void:
	_saved_state = GameManager.current_state
	GameManager.current_state = GameManager.MatchState.IN_PROGRESS


func after_each() -> void:
	GameManager.current_state = _saved_state


func _desk() -> CCTVDesk3D:
	var desk: CCTVDesk3D = CCTVDesk3D.new()
	add_child_autofree(desk)
	return desk


func _guard(pos: Vector3 = Vector3.ZERO) -> GuardController3D:
	var guard: GuardController3D = GUARD_SCENE.instantiate() as GuardController3D
	add_child_autofree(guard)
	guard.global_position = pos
	return guard


func _camera() -> SecurityCamera3D:
	var camera: SecurityCamera3D = CAMERA_SCENE.instantiate() as SecurityCamera3D
	camera.sweep_enabled = false
	add_child_autofree(camera)
	return camera


func _sit(guard: GuardController3D, desk: CCTVDesk3D) -> void:
	desk.interact(guard)
	guard.monitor_watch.tick(guard, RULES.monitor_enter_time + 0.01)


func test_sit_after_enter_time_and_look_at_desk() -> void:
	var desk: CCTVDesk3D = _desk()
	var guard: GuardController3D = _guard(Vector3(0.0, 0.0, 1.0))
	desk.interact(guard)
	assert_true(desk.is_occupied(), "La mesa queda ocupada al sentarse")
	assert_false(guard.is_watching_monitors(), "Sentarse tarda monitor_enter_time")
	guard.monitor_watch.tick(guard, RULES.monitor_enter_time + 0.01)
	assert_true(guard.is_watching_monitors(), "Ya mira")
	guard.apply_input({"movement_vector": Vector2.ZERO, "look_target": Vector3(9.0, 0.0, 9.0)})
	assert_eq(guard.look_target_position, desk.look_point(), "Mira fijo a la mesa")
	assert_string_contains(desk.get_interaction_text(guard), "Dejar")


func test_first_move_input_exits_without_moving() -> void:
	var desk: CCTVDesk3D = _desk()
	var guard: GuardController3D = _guard(Vector3(0.0, 0.0, 1.0))
	_sit(guard, desk)
	guard.apply_input({"movement_vector": Vector2(1.0, 0.0)})
	assert_eq(guard.current_input_dir, Vector2.ZERO, "Ese primer input no lo mueve")
	assert_false(guard.monitor_watch.is_active(), "El movimiento lo levanta")
	assert_false(desk.is_occupied(), "Libera la mesa")
	guard.apply_input({"movement_vector": Vector2(1.0, 0.0)})
	assert_eq(guard.current_input_dir, Vector2(1.0, 0.0), "Ya de pie, se mueve")


func test_interact_and_match_end_exit() -> void:
	var desk: CCTVDesk3D = _desk()
	var guard: GuardController3D = _guard(Vector3(0.0, 0.0, 1.0))
	_sit(guard, desk)
	guard.perform_action(&"interact")
	assert_false(guard.monitor_watch.is_active(), "interact lo levanta")
	_sit(guard, desk)
	GameManager.current_state = GameManager.MatchState.THIEF_CAPTURED
	guard.monitor_watch.tick(guard, 0.016)
	assert_false(guard.monitor_watch.is_active(), "El fin de partida lo levanta")
	assert_false(desk.is_occupied())


func test_single_chair() -> void:
	var desk: CCTVDesk3D = _desk()
	var first: GuardController3D = _guard(Vector3(0.0, 0.0, 1.0))
	var second: GuardController3D = _guard(Vector3(1.0, 0.0, 1.0))
	_sit(first, desk)
	desk.interact(second)
	assert_false(second.monitor_watch.is_active(), "Solo cabe uno")
	assert_eq(desk.get_interaction_text(second), "Monitores ocupados")
	assert_eq(desk.watcher, first)


func test_pilots_on_only_while_someone_watches() -> void:
	var desk: CCTVDesk3D = _desk()
	var cameras: Array[SecurityCamera3D] = [_camera(), _camera()]
	var guard: GuardController3D = _guard(Vector3(0.0, 0.0, 1.0))
	for camera: SecurityCamera3D in cameras:
		assert_false(camera.get_node("CameraMount/RecordingPilot").visible, "Piloto apagado")
	desk.interact(guard)
	for camera: SecurityCamera3D in cameras:
		assert_false(camera.is_recording, "Sentándose todavía no mira: piloto apagado")
	guard.monitor_watch.tick(guard, RULES.monitor_enter_time + 0.01)
	for camera: SecurityCamera3D in cameras:
		assert_true(camera.is_recording, "Piloto encendido con alguien mirando")
		assert_true(camera.get_node("CameraMount/RecordingPilot").visible)
		assert_true(bool(camera.get_net_state()["rec"]), "Se replica a todos")
	guard.stop_watching()
	for camera: SecurityCamera3D in cameras:
		assert_false(camera.is_recording, "Se apaga al levantarse")


func test_watching_turns_off_sight_but_not_proximity() -> void:
	var guard: GuardController3D = _guard()
	var thief: ThiefController3D = THIEF_SCENE.instantiate() as ThiefController3D
	add_child_autofree(thief)
	thief.global_position = Vector3(0.0, 0.0, -4.0)
	guard.apply_flashlight_state(true)
	await wait_physics_frames(2)
	var senses: GuardSenses = GuardSenses.new()
	var lamps: Array[Lamp3D] = []
	assert_eq(senses.detects(guard, thief, lamps), &"cone", "De pie, la linterna lo ve")
	guard.monitor_watch.state = GuardMonitorWatch.State.WATCHING
	assert_eq(senses.detects(guard, thief, lamps), &"", "Mirando, la linterna no detecta")
	thief.global_position = Vector3(0.0, 0.0, -1.2)
	await wait_physics_frames(1)
	assert_eq(senses.detects(guard, thief, lamps), &"proximity", "La proximidad sigue")


func test_camera_only_sees_lit_thief() -> void:
	var camera: SecurityCamera3D = _camera()
	camera.global_position = Vector3(0.0, 2.0, 0.0)
	var thief: ThiefController3D = THIEF_SCENE.instantiate() as ThiefController3D
	add_child_autofree(thief)
	thief.global_position = Vector3(0.0, 0.0, -4.0)
	await wait_physics_frames(2)
	assert_false(camera._check_line_of_sight(thief), "En sombra dentro del cono: no lo ve")
	var lamp: Lamp3D = LAMP_SCENE.instantiate() as Lamp3D
	lamp.profile = load("res://data/balance/lamp_ceiling.tres") as LampProfile
	add_child_autofree(lamp)
	lamp.global_position = Vector3(0.0, 3.0, -4.0)
	await wait_physics_frames(2)
	assert_true(camera._check_line_of_sight(thief), "Iluminado: lo ve")


func test_guard_views_only_cctv_for_watching_guard() -> void:
	var watcher: GuardController3D = _guard()
	var other: GuardController3D = _guard(Vector3(5.0, 0.0, 0.0))
	watcher.monitor_watch.state = GuardMonitorWatch.State.WATCHING
	var guards: Array[GuardController3D] = [watcher, other]
	var views: Dictionary = NetVisibility.guard_views(guards, true)
	assert_eq(views[&"guard_1"], &"cctv", "El que mira lo recibe solo por CCTV")
	assert_eq(views[&"guard_2"], &"", "El que no mira no recibe nada por las cámaras")
	assert_eq(NetVisibility.guard_views(guards, false)[&"guard_1"], &"", "Sin detección")
	other.is_perceiving_thief = true
	assert_eq(NetVisibility.guard_views(guards, true)[&"guard_2"], &"world", "Percepción propia")


func test_cctv_view_mode_hides_thief_from_world_camera() -> void:
	var thief: ThiefController3D = THIEF_SCENE.instantiate() as ThiefController3D
	add_child_autofree(thief)
	var meshes: Array[Node] = thief.visual_root.find_children(
		"*", "GeometryInstance3D", true, false
	)
	assert_gt(meshes.size(), 0, "El ladrón tiene mallas")
	var original: int = (meshes[0] as GeometryInstance3D).layers
	thief.set_view_mode(ThiefController3D.ViewMode.CCTV)
	assert_true(thief.visual_root.visible, "Visible para las cámaras")
	for node: Node in meshes:
		var geometry: GeometryInstance3D = node as GeometryInstance3D
		assert_eq(geometry.layers, 1 << (ThiefController3D.CCTV_ONLY_LAYER - 1), "Solo capa CCTV")
		assert_eq(geometry.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Sin sombra")
	thief.set_view_mode(ThiefController3D.ViewMode.WORLD)
	assert_eq((meshes[0] as GeometryInstance3D).layers, original, "Vuelve a su capa")
	thief.set_view_mode(ThiefController3D.ViewMode.HIDDEN)
	assert_false(thief.visual_root.visible, "Oculto")
	var map: HeistMap3D = HeistMap3D.new()
	var world_camera: Camera3D = Camera3D.new()
	world_camera.name = "IsometricCamera3D"
	map.add_child(world_camera)
	add_child_autofree(map)
	assert_false(
		world_camera.get_cull_mask_value(ThiefController3D.CCTV_ONLY_LAYER),
		"La cámara del mapa no dibuja la capa CCTV"
	)
	var feed_camera: Camera3D = _camera().get_node("SubViewport/InternalCamera3D") as Camera3D
	assert_true(feed_camera.get_cull_mask_value(ThiefController3D.CCTV_ONLY_LAYER))


func test_ai_ignores_camera_alert_unless_watching() -> void:
	var guard: GuardController3D = _guard()
	guard.is_ai_controlled = true
	var ai: GuardAI3D = GUARD_AI_SCRIPT.new() as GuardAI3D
	ai.name = "GuardAI"
	guard.add_child(ai)
	SignalBus.thief_spotted.emit(Vector3(3.0, 0.0, 3.0))
	assert_ne(ai.current_state, GuardAI3D.AIState.INVESTIGATE, "De ronda, la cámara no le avisa")
	guard.monitor_watch.state = GuardMonitorWatch.State.WATCHING
	SignalBus.thief_spotted.emit(Vector3(3.0, 0.0, 3.0))
	assert_eq(ai.current_state, GuardAI3D.AIState.INVESTIGATE, "Mirando, sí")
