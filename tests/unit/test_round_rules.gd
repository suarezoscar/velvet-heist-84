## @file test_round_rules.gd
## Tests de la hoja de ronda (FEAT-016): faltas, final por tiempo R4, números del .tres,
## filtro de red de los relojes, fichaje de la IA y tablilla del HUD.
extends GutTest

const RULES: TimeClockRules = preload("res://data/balance/time_clock_rules.tres")
const GUARD_SCENE: PackedScene = preload("res://scenes/entities/guard_player.tscn")
const GUARD_AI_SCRIPT: Script = preload("res://src/entities/guard/guard_ai_3d.gd")

var _saved_state: GameManager.MatchState
var _saved_masterpiece: bool


func before_each() -> void:
	_saved_state = GameManager.current_state
	_saved_masterpiece = GameManager.has_masterpiece


func after_each() -> void:
	GameManager.current_state = _saved_state
	GameManager.has_masterpiece = _saved_masterpiece


func _clock(id: int = 1) -> TimeClock3D:
	var clock: TimeClock3D = TimeClock3D.new()
	clock.clock_id = id
	add_child_autofree(clock)
	return clock


func _guard() -> GuardController3D:
	var guard: GuardController3D = GUARD_SCENE.instantiate() as GuardController3D
	add_child_autofree(guard)
	return guard


## Deja el reloj vencido v segundos, en pasos de 1 s como haría la simulación
func _expire_for(clock: TimeClock3D, seconds: float) -> void:
	clock._update_countdown(clock.time_left)
	for _i: int in range(int(seconds)):
		clock._update_countdown(1.0)


func test_faults_follow_formula_and_never_drop() -> void:
	var clock: TimeClock3D = _clock()
	var guard: GuardController3D = _guard()
	_expire_for(clock, 40.0)
	assert_eq(clock.faults, 1, "v = 40 s → 1 falta")
	clock.interact(guard)
	assert_eq(clock.faults, 1, "Fichar no borra faltas")
	_expire_for(clock, 180.0)
	assert_eq(clock.faults, 4, "Segundo episodio de v = 180 s → 1 + 2 más")
	clock.reset_round()
	assert_eq(clock.faults, 0, "Solo una partida nueva limpia la hoja")


func test_round_duration_comes_from_tres() -> void:
	var clock: TimeClock3D = _clock()
	assert_almost_eq(clock.round_duration, RULES.round_duration, 0.001)
	for prop: Dictionary in clock.get_property_list():
		if prop["name"] == "round_duration":
			assert_eq(int(prop["usage"]) & PROPERTY_USAGE_EDITOR, 0, "Sin export por reloj")


func test_time_outcome_table() -> void:
	var clock_a: TimeClock3D = _clock(1)
	var clock_b: TimeClock3D = _clock(2)
	var cases: Array = [
		[0, false, true, GameManager.MatchState.TIME_EXPIRED],
		[0, false, false, GameManager.MatchState.TIME_EXPIRED],
		[RULES.allowed_misses + 1, false, true, GameManager.MatchState.TIME_EXPIRED_BREACH],
		[RULES.allowed_misses + 1, false, false, GameManager.MatchState.TIME_EXPIRED_DRAW],
		[1, true, true, GameManager.MatchState.TIME_EXPIRED_BREACH],
		[1, true, false, GameManager.MatchState.TIME_EXPIRED_DRAW],
	]
	for case: Array in cases:
		clock_a.reset_round()
		clock_b.reset_round()
		clock_a.faults = int(case[0])
		if bool(case[1]):
			clock_b.time_left = 0.0
		GameManager.has_masterpiece = bool(case[2])
		assert_eq(GameManager.time_expired_state(), case[3], "Casilla %s" % str(case))


func test_thief_never_receives_clock_time_or_faults() -> void:
	var clock: TimeClock3D = _clock()
	clock.faults = 2
	assert_eq(clock.get_net_state().keys(), ["expired"], "Estado público: solo expired")
	var private_states: NetPrivateStates = NetPrivateStates.new()
	var collected: Dictionary = private_states.collect({"Props/TimeClock_01": clock}, true)
	var to_thief: Dictionary = NetPrivateStates.for_role(collected, &"thief")
	var to_guard: Dictionary = NetPrivateStates.for_role(collected, &"guard_2")
	assert_true(to_thief.is_empty(), "El ladrón no recibe el estado privado del reloj")
	assert_eq(to_guard["Props/TimeClock_01#private"]["faults"], 2, "El guardia sí")
	GameManager.current_state = GameManager.MatchState.IN_PROGRESS
	assert_false(GameManager.get_net_state().has("faults"), "Sin faltas durante la partida")
	GameManager.current_state = GameManager.MatchState.TIME_EXPIRED_DRAW
	assert_true(GameManager.get_net_state().has("faults"), "Faltas en la pantalla final")


func test_ai_guard_punches_clock_it_passes() -> void:
	var guard: GuardController3D = _guard()
	guard.is_ai_controlled = true
	guard.is_locally_controlled = false
	var ai: Node = Node.new()
	ai.name = "GuardAI"
	ai.set_script(GUARD_AI_SCRIPT)
	guard.add_child(ai)
	var clock: TimeClock3D = _clock()
	clock.global_position = guard.global_position + Vector3(1.0, 0.0, 0.0)
	clock.time_left = 50.0
	await wait_physics_frames(3)
	assert_almost_eq(clock.time_left, RULES.round_duration, 0.001, "La IA ficha al pasar")


func test_round_sheet_rows_and_warnings() -> void:
	var sheet: RoundSheet84 = RoundSheet84.new()
	add_child_autofree(sheet)
	var clock_a: TimeClock3D = _clock(1)
	var clock_b: TimeClock3D = _clock(2)
	clock_a.time_left = RULES.warning_time - 1.0
	_expire_for(clock_b, 1.0)
	clock_b.faults = RULES.allowed_misses
	sheet.refresh([clock_b, clock_a])
	assert_string_contains(sheet.row_text(1), "%d s" % int(RULES.warning_time - 1.0))
	assert_string_contains(sheet.row_text(2), "VENCIDO")
	assert_string_contains(sheet._warning_label.text, "Una falta más")
	clock_b.faults += 1
	sheet.refresh([clock_a, clock_b])
	assert_string_contains(sheet._warning_label.text, "Ronda rota")
