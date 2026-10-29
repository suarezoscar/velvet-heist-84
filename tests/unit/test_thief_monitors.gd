## @file test_thief_monitors.gd
## El ladrón también mira los monitores (FEAT-042): se sienta en la mesa de la garita si está
## libre, y con él sentado los guardias que ve alguna cámara (con luz) le salen solo en las
## pantallas, nunca en la vista del mundo. Con red, llegan marcados «cctv_only».
extends GutTest

const RULES: CCTVRules = preload("res://data/balance/cctv_rules.tres")
const MAP_SCENE: PackedScene = preload("res://scenes/maps/museum_v2.tscn")

var _saved_state: GameManager.MatchState


func before_each() -> void:
	_saved_state = GameManager.current_state


func after_each() -> void:
	GameManager.current_state = _saved_state


func _map() -> HeistMap3D:
	var map: HeistMap3D = MAP_SCENE.instantiate() as HeistMap3D
	add_child_autofree(map)
	return map


func test_thief_sits_at_the_desk_when_free() -> void:
	var map: HeistMap3D = _map()
	await wait_physics_frames(3)
	var desk: CCTVDesk3D = map.find_children("*", "CCTVDesk3D", true, false)[0] as CCTVDesk3D
	var thief: ThiefController3D = map.thief
	thief.is_locally_controlled = false
	assert_true(desk.can_interact(thief), "El ladrón también puede")
	assert_eq(desk.get_interaction_text(thief), "Mirar los monitores [E]")
	desk.interact(thief)
	await wait_seconds(RULES.monitor_enter_time + 0.2)
	assert_true(thief.is_watching_monitors(), "Sentado mirando")
	assert_eq(desk.get_interaction_text(thief), "Dejar los monitores [E]")
	assert_eq(desk.get_interaction_text(map.guards[0]), "Monitores ocupados")
	desk.interact(map.guards[0])
	assert_false(map.guards[0].is_watching_monitors(), "Una sola silla")
	thief.perform_action(&"interact")
	assert_false(thief.is_watching_monitors(), "E lo levanta")


func test_thief_marks_cctv_guards() -> void:
	var views: Dictionary = {"guards": {}, "thief": {&"guard_1": &"cctv"}}
	assert_eq(NetSnapshots.mark_for(&"thief", &"guard_1", views), &"cctv_only")


func test_guard_on_camera_shows_only_on_the_screens() -> void:
	var map: HeistMap3D = _map()
	await wait_physics_frames(3)
	var thief: ThiefController3D = map.thief
	var guard: GuardController3D = map.guards[0]
	guard.is_ai_controlled = false
	var camera: SecurityCamera3D = get_tree().get_nodes_in_group(&"security_camera")[0]
	# Un punto del suelo que la cámara ve
	var forward: Vector3 = -camera.mount.global_transform.basis.z
	var spot: Vector3 = Vector3.INF
	for step: int in range(2, 40):
		var point: Vector3 = camera.mount.global_position + forward * (step * 0.25)
		point.y = 0.0
		if camera.sees_point(point + Vector3(0.0, 1.0, 0.0)):
			spot = point
			break
	assert_ne(spot, Vector3.INF, "La cámara ve algún punto del suelo")
	guard.global_position = spot
	guard.apply_flashlight_state(true)
	thief.is_locally_controlled = false
	await wait_physics_frames(2)
	var lamps: Array[Lamp3D] = VisionLogic.lamps_in(map)
	var before: StringName = VisionLogic.thief_view_of(thief, guard, lamps)
	thief.monitor_watch.state = GuardMonitorWatch.State.WATCHING
	var view: StringName = VisionLogic.thief_view_of(thief, guard, lamps)
	if before == &"full":
		pass_test("El ladrón ya lo veía en persona desde su sitio")
		return
	assert_eq(view, &"cctv", "Ante los monitores lo ve por la cámara")
	await wait_physics_frames(3)
	var body: Node3D = guard.get_node("VisualRoot") as Node3D
	assert_true(body.visible, "Se dibuja…")
	var mesh: GeometryInstance3D = body.find_children("*", "GeometryInstance3D", true, false)[0]
	assert_eq(mesh.layers, 1 << (CctvLayer.LAYER - 1), "…solo en la capa de las cámaras")
	thief.monitor_watch.state = GuardMonitorWatch.State.NONE
	await wait_physics_frames(3)
	assert_ne(mesh.layers, 1 << (CctvLayer.LAYER - 1), "Al levantarse, fuera de las pantallas")
