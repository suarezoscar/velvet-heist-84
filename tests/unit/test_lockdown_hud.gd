## @file test_lockdown_hud.gd
## #120: la cifra grande de las rejas (texto, visibilidad) y el golpe de campana sintetizado.
extends GutTest

var _saved_state: GameManager.MatchState
var _saved_timer: float = 0.0


func before_each() -> void:
	_saved_state = GameManager.current_state
	_saved_timer = GameManager.match_timer


func after_each() -> void:
	GameManager.current_state = _saved_state
	GameManager.match_timer = _saved_timer


func test_text_for_rounds_up() -> void:
	assert_eq(LockdownHud84.text_for(30.0), "REJAS 0:30")
	assert_eq(LockdownHud84.text_for(29.2), "REJAS 0:30")
	assert_eq(LockdownHud84.text_for(9.0), "REJAS 0:09")
	assert_eq(LockdownHud84.text_for(0.0), "REJAS 0:00")


func test_hidden_without_lockdown() -> void:
	var hud: LockdownHud84 = LockdownHud84.new()
	add_child_autofree(hud)
	await get_tree().process_frame
	assert_false(hud.visible)


func test_visible_with_lockdown_running() -> void:
	GameManager.current_state = GameManager.MatchState.IN_PROGRESS
	GameManager.match_timer = 100.0
	var lockdown: HeistLockdown = HeistLockdown.new()
	add_child_autofree(lockdown)
	lockdown.left = 12.0
	var hud: LockdownHud84 = LockdownHud84.new()
	add_child_autofree(hud)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(hud.visible)
	assert_eq(hud.get_child(0).text, "REJAS 0:12")


func test_bell_is_cached_wav() -> void:
	var bell: AudioStreamWAV = AlarmBellSounds.bell()
	assert_not_null(bell)
	assert_same(AlarmBellSounds.bell(), bell)
