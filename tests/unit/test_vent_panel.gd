## @file test_vent_panel.gd
## El plano de los conductos (VentPanel84, #167): filas, elegida, cierre y etiqueta del viaje.
extends GutTest

const MAP_SCENE: PackedScene = preload("res://scenes/maps/museum_v2.tscn")

var _saved_state: GameManager.MatchState
var _saved_timer: float


func before_each() -> void:
	_saved_state = GameManager.current_state
	_saved_timer = GameManager.match_timer
	GameManager.current_state = GameManager.MatchState.IN_PROGRESS
	GameManager.match_timer = 600.0


func after_each() -> void:
	GameManager.current_state = _saved_state
	GameManager.match_timer = _saved_timer


func _open() -> HeistMap3D:
	var map: HeistMap3D = MAP_SCENE.instantiate() as HeistMap3D
	add_child_autofree(map)
	for guard: GuardController3D in map.guards:
		guard.set_physics_process(false)
	await wait_physics_frames(2)
	var entry: Vent3D = null
	for node: Node in get_tree().get_nodes_in_group(&"vents"):
		if (node as Vent3D).vent_id == "V_TAL":
			entry = node as Vent3D
	map.thief.global_position = entry.exit_point()
	entry.interact(map.thief)
	await wait_frames(3)
	return map


func test_plano_filas_y_cierre() -> void:
	var map: HeistMap3D = await _open()
	var travel: VentTravel = VentTravel.of(get_tree())
	var panel: VentPanel84 = map.hud.vent_panel
	panel.refresh()
	assert_true(panel.visible, "El plano está abierto")
	assert_eq(panel.rows.get_child_count(), travel.choices.size())
	assert_true((panel.rows.get_child(travel.selected) as Label).text.contains("▶"))
	travel.handle(map.thief, &"dial_cancel")
	await wait_frames(2)
	panel.refresh()
	assert_false(panel.visible, "Cerrado el plano, se oculta")


func test_etiqueta_del_viaje() -> void:
	var map: HeistMap3D = await _open()
	var travel: VentTravel = VentTravel.of(get_tree())
	travel.phase = VentTravel.Phase.TRAVELING
	travel.left = 3.2
	await wait_frames(2)
	var panel: VentPanel84 = map.hud.vent_panel
	panel.refresh()
	assert_true(panel.travel_label.visible)
	assert_eq(panel.travel_label.text, "Por el conducto… 4 s")
