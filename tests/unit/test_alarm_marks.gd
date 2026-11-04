## @file test_alarm_marks.gd
## #117: AlertDirector recuerda dónde y cuándo saltó cada alarma y lo reparte en su estado público.
extends GutTest

var alert: AlertDirector
var _saved_timer: float = 0.0


func before_each() -> void:
	_saved_timer = GameManager.match_timer
	GameManager.match_timer = 300.0
	alert = AlertDirector.new()
	add_child_autofree(alert)


func after_each() -> void:
	GameManager.match_timer = _saved_timer


func test_alarm_records_mark_with_position_and_time() -> void:
	alert.raise(AlertDirector.Level.ALARM, Vector3(1, 0, 2))
	assert_eq(alert.alarm_marks.size(), 1)
	assert_eq(alert.alarm_marks[0]["pos"], Vector3(1, 0, 2))
	assert_eq(float(alert.alarm_marks[0]["t"]), 300.0)


func test_same_situation_counts_once() -> void:
	alert.raise(AlertDirector.Level.ALARM, Vector3(1, 0, 2))
	alert.raise(AlertDirector.Level.ALARM, Vector3(5, 0, 5))
	assert_eq(alert.alarm_marks.size(), 1)


func test_suspicion_leaves_no_mark() -> void:
	alert.raise(AlertDirector.Level.SUSPICION)
	assert_eq(alert.alarm_marks.size(), 0)


func test_marks_travel_in_public_state() -> void:
	alert.raise(AlertDirector.Level.ALARM, Vector3(1, 0, 2))
	var copy := AlertDirector.new()
	add_child_autofree(copy)
	copy.apply_net_state(alert.get_net_state())
	assert_eq(copy.alarm_marks.size(), 1)
	assert_eq(copy.alarm_marks[0]["pos"], Vector3(1, 0, 2))
