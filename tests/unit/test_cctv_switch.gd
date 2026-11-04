## @file test_cctv_switch.gd
## Una cámara por pantalla en la mesa (interaction.md M2b, M4 y M5, #118): step en bucle, nieve
## al cambiar, un solo piloto, detección solo con un guardia despierto y réplica del índice.
extends GutTest

const RULES: CCTVRules = preload("res://data/balance/cctv_rules.tres")
const GUARD_SCENE: PackedScene = preload("res://scenes/entities/guard_player.tscn")
const THIEF_SCENE: PackedScene = preload("res://scenes/entities/thief_player.tscn")
const CAMERA_SCENE: PackedScene = preload("res://scenes/entities/security_camera.tscn")

var _saved_state: GameManager.MatchState


func before_each() -> void:
	_saved_state = GameManager.current_state
	GameManager.current_state = GameManager.MatchState.IN_PROGRESS


func after_each() -> void:
	GameManager.current_state = _saved_state


## Mesa con CAM-03, CAM-01 y CAM-02 (en ese orden de creación)
func _desk(ids: Array[String] = ["CAM-03", "CAM-01", "CAM-02"]) -> CCTVDesk3D:
	for id: String in ids:
		var camera: SecurityCamera3D = CAMERA_SCENE.instantiate() as SecurityCamera3D
		camera.camera_id = id
		camera.sweep_enabled = false
		add_child_autofree(camera)
	var desk: CCTVDesk3D = CCTVDesk3D.new()
	add_child_autofree(desk)
	return desk


func _guard() -> GuardController3D:
	var guard: GuardController3D = GUARD_SCENE.instantiate() as GuardController3D
	add_child_autofree(guard)
	return guard


func _sit(who: PlayerBase3D, desk: CCTVDesk3D) -> void:
	desk.interact(who)
	who.monitor_watch.tick(who, RULES.monitor_enter_time + 0.01)


func _live_count(desk: CCTVDesk3D, property: StringName) -> int:
	var count: int = 0
	for camera: SecurityCamera3D in desk.cameras():
		count += int(bool(camera.get(property)))
	return count


func test_cameras_are_in_natural_order() -> void:
	var desk: CCTVDesk3D = _desk(["CAM-10", "CAM-02", "CAM-01"])
	var ids: Array[String] = []
	for camera: SecurityCamera3D in desk.cameras():
		ids.append(camera.camera_id)
	assert_eq(ids, ["CAM-01", "CAM-02", "CAM-10"] as Array[String], "CAM-02 antes que CAM-10")


func test_step_loops_both_ways() -> void:
	var desk: CCTVDesk3D = _desk()
	_sit(_guard(), desk)
	assert_eq(desk.current, 0, "Empieza en CAM-01")
	assert_eq(desk.on_screen().camera_id, "CAM-01")
	desk.step(-1)
	assert_eq(desk.current, 2, "De la primera, a la última")
	assert_eq(desk.on_screen().camera_id, "CAM-03")
	desk.step(1)
	assert_eq(desk.current, 0, "De la última, a la primera")
	desk.step(1)
	assert_eq(desk.current, 1)


func test_step_without_watcher_does_nothing() -> void:
	var desk: CCTVDesk3D = _desk()
	desk.step(1)
	assert_eq(desk.current, 0, "Sin nadie sentado no pasa")
	var guard: GuardController3D = _guard()
	desk.interact(guard)
	guard.monitor_watch.stop(guard)
	desk.step(1)
	assert_eq(desk.current, 0, "Levantado tampoco")


func test_new_camera_waits_for_the_snow_to_clear() -> void:
	var desk: CCTVDesk3D = _desk()
	_sit(_guard(), desk)
	var first: SecurityCamera3D = desk.on_screen()
	assert_true(first.on_screen and first.is_live, "La primera ya detecta")
	desk.step(1)
	var second: SecurityCamera3D = desk.on_screen()
	assert_ne(second, first)
	assert_false(second.on_screen, "Con nieve no está en pantalla")
	assert_false(second.is_live, "Ni detecta")
	assert_false(first.on_screen or first.is_live, "La anterior ya no")
	desk._physics_process(RULES.switch_time * 0.5)
	assert_false(second.is_live, "Aún nieva")
	desk._physics_process(0.3)
	assert_true(second.on_screen, "Pasada la nieve, en pantalla")
	assert_true(second.is_live, "Y detecta")
	assert_false(first.on_screen or first.is_live)


func test_at_most_one_pilot_on() -> void:
	var desk: CCTVDesk3D = _desk()
	assert_eq(_live_count(desk, &"is_recording"), 0, "Sin nadie, ninguno")
	_sit(_guard(), desk)
	assert_eq(_live_count(desk, &"is_recording"), 1)
	desk.step(1)
	assert_eq(_live_count(desk, &"is_recording"), 1, "Al cambiar, sigue uno solo")
	assert_true(desk.on_screen().is_recording)
	desk._physics_process(0.3)
	assert_eq(_live_count(desk, &"is_recording"), 1)
	assert_eq(_live_count(desk, &"on_screen"), 1)
	assert_eq(_live_count(desk, &"is_live"), 1)


func test_thief_seated_sees_screen_but_no_camera_is_live() -> void:
	var desk: CCTVDesk3D = _desk()
	var thief: ThiefController3D = THIEF_SCENE.instantiate() as ThiefController3D
	add_child_autofree(thief)
	_sit(thief, desk)
	assert_true(thief.is_watching_monitors())
	assert_true(desk.on_screen().on_screen, "El ladrón ve la cámara en pantalla")
	assert_false(desk.on_screen().is_live, "Pero no da parte")
	assert_eq(_live_count(desk, &"is_live"), 0)


func test_nodding_guard_does_not_make_camera_live() -> void:
	var desk: CCTVDesk3D = _desk()
	var guard: GuardController3D = _guard()
	var sleep: GuardSleep = GuardSleep.attach(guard)
	_sit(guard, desk)
	assert_true(desk.on_screen().is_live, "Despierto, detecta")
	sleep.nodding = true
	desk._physics_process(0.016)
	assert_true(desk.on_screen().on_screen, "Sigue en pantalla")
	assert_false(desk.on_screen().is_live, "En la cabezada no ve: no detecta")
	sleep.nodding = false
	desk._physics_process(0.016)
	assert_true(desk.on_screen().is_live, "Al despertar, vuelve")


func test_net_state_replicates_the_current_camera() -> void:
	var desk: CCTVDesk3D = _desk()
	_sit(_guard(), desk)
	desk.step(1)
	var state: Dictionary = desk.get_net_state()
	assert_eq(state["cam"], 1)
	assert_true(state["occupied"])
	var client: CCTVDesk3D = CCTVDesk3D.new()
	add_child_autofree(client)
	client.apply_net_state(state)
	assert_eq(client.current, 1, "El cliente recibe el índice")
	assert_true(client.is_occupied())
