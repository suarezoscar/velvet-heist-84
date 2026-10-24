## @file test_safe_dial_panel.gd
## Panel del dial de la caja fuerte (FEAT-019): giro seguido al mantener la tecla, entrada sin
## red con flechas, progreso de la combinación y aviso vacío mientras se gira el dial.
extends GutTest

const RULES: SafeDialRules = preload("res://data/balance/safe_dial.tres")
const THIEF_SCENE: PackedScene = preload("res://scenes/entities/thief_player.tscn")

var _safe: SafeBox3D = null
var _thief: ThiefController3D = null


func before_each() -> void:
	_safe = SafeBox3D.new()
	add_child_autofree(_safe)
	_thief = THIEF_SCENE.instantiate() as ThiefController3D
	add_child_autofree(_thief)


func after_each() -> void:
	Input.action_release(&"ui_right")


func test_repeat_steps_once_then_accelerates() -> void:
	var repeat: DialRepeat = DialRepeat.new()
	assert_eq(repeat.update(false, true, 0.016), 1, "Un paso al pulsar")
	var early: int = 0
	for _i: int in range(int(RULES.repeat_delay / 0.016) - 2):
		early += repeat.update(false, true, 0.016)
	assert_eq(early, 0, "Nada antes de repeat_delay")
	var first_second: int = 0
	for _i: int in range(60):
		first_second += repeat.update(false, true, 0.016)
	var second_second: int = 0
	for _i: int in range(60):
		second_second += repeat.update(false, true, 0.016)
	assert_gt(first_second, 5, "Gira seguido")
	assert_gt(second_second, first_second, "Y acelera")
	assert_eq(repeat.update(false, false, 0.016), 0, "Al soltar se para")
	assert_eq(repeat.update(true, false, 0.016), -1, "Hacia el otro lado, al momento")


func test_offline_arrows_turn_dial_while_held() -> void:
	_thief.is_locally_controlled = true
	_safe.interact(_thief)
	Input.action_press(&"ui_right")
	_safe._process(0.016)
	assert_eq(_safe.current_dial_val, 1, "Un paso al pulsar")
	for _i: int in range(120):
		_safe._process(0.016)
	assert_gt(_safe.current_dial_val, 20, "Mantener la flecha lo hace girar seguido")


func test_panel_shows_progress_and_hides() -> void:
	var panel: SafeDial84 = SafeDial84.new()
	add_child_autofree(panel)
	_safe.interact(_thief)
	panel.bind(_safe)
	assert_true(panel.visible, "Se abre al girar el dial")
	assert_eq(panel.stage_text(), "NÚMERO 1 DE 3")
	_safe.current_dial_val = _safe.combination[0]
	_safe.interact(_thief)
	panel._process(0.0)
	assert_eq(panel.stage_text(), "NÚMERO 2 DE 3", "Acertar avanza")
	assert_eq(panel.face.value, _safe.current_dial_val, "El dial enseña el número actual")
	panel.bind(null)
	assert_false(panel.visible, "Se cierra al salir")


func test_no_prompt_while_turning_dial() -> void:
	assert_ne(_safe.get_interaction_text(_thief), "", "Antes, «Abrir caja fuerte [E]»")
	_safe.interact(_thief)
	assert_eq(_safe.get_interaction_text(_thief), "", "Girando el dial, el aviso lo da el panel")
