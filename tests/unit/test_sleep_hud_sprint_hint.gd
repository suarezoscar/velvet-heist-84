## @file test_sleep_hud_sprint_hint.gd
## #116 (heist.md R5d): el aviso «Correr: solo con la alarma» sale al pedir correr en calma y
## se oculta con la alarma sonando.
extends GutTest

const MAP_SCENE: PackedScene = preload("res://scenes/maps/museum_v2.tscn")


func after_each() -> void:
	Input.action_release(&"sprint")


func _hud() -> SleepHud84:
	var map: HeistMap3D = MAP_SCENE.instantiate() as HeistMap3D
	add_child_autofree(map)
	map.set_local_player(map.guards[0])
	var hud: SleepHud84 = SleepHud84.new()
	hud.map = map
	add_child_autofree(hud)
	return hud


func test_hint_text_and_hidden_by_default() -> void:
	var hud: SleepHud84 = _hud()
	await wait_physics_frames(2)
	assert_not_null(hud.sprint_hint)
	assert_eq(hud.sprint_hint.text, SleepHud84.SPRINT_HINT)
	assert_false(hud.sprint_hint.visible, "Sin pedir correr, oculto")


func test_hint_shows_when_calm_and_hides_on_alarm() -> void:
	var hud: SleepHud84 = _hud()
	await wait_physics_frames(2)
	Input.action_press(&"sprint")
	hud._process(0.016)
	assert_true(hud.sprint_hint.visible, "En calma y pidiendo correr, se avisa")
	AlertDirector.of(get_tree()).level = AlertDirector.Level.ALARM
	hud._process(0.016)
	assert_false(hud.sprint_hint.visible, "Con la alarma ya se puede correr")
