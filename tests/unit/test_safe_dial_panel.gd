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


## Cada marca suena según lo cerca que está del número: tic, clic, golpe en el exacto
func test_sound_and_pointer_follow_distance() -> void:
	_safe.interact(_thief)
	var target: int = _safe.combination[0]
	_safe.current_dial_val = (target + 99) % 100
	assert_eq(_safe.target_distance(), 1, "Uno antes")
	_safe.current_dial_val = (target + 2) % 100
	assert_eq(_safe.target_distance(), 2, "Dos después")
	_safe.combination = [1, 50, 99] as Array[int]
	_safe.current_dial_val = 98
	assert_eq(_safe.target_distance(), 3, "Por el camino corto, pasando por el 0")
	assert_eq(DialSounds.for_distance(0), DialSounds.exact(), "El número exacto suena distinto")
	assert_eq(DialSounds.for_distance(1), DialSounds.near(1))
	assert_ne(DialSounds.near(1), DialSounds.near(2), "Más cerca, otro clic")
	assert_eq(DialSounds.for_distance(3), DialSounds.tick(), "Lejos, un tic")
	assert_eq(SafeDial84.pointer_color(0), SafeDial84.OK_COLOR)
	assert_eq(SafeDial84.pointer_color(2), MenuTheme84.AMBER)
	assert_eq(SafeDial84.pointer_color(9), SafeDial84.FAR_POINTER)


## Fallar se nota aunque se esté en el primer número (el progreso no cambia)
func test_wrong_guess_counts_even_on_first_number() -> void:
	_safe.interact(_thief)
	_safe.current_dial_val = (_safe.combination[0] + 10) % 100
	_safe.interact(_thief)
	assert_eq(_safe.current_stage, 0)
	assert_eq(_safe.fails, 1, "Cuenta el fallo")
	assert_eq(_safe.get_net_state_private()["fails"], 1, "Y le llega al ladrón")
