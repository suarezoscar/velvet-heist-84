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
	assert_eq(float(copy.alarm_marks[0]["t"]), 300.0, "el momento llega redondeado al segundo")
	copy.apply_net_state(alert.get_net_state())
	assert_eq(copy.alarm_marks.size(), 1, "aplicar el mismo estado dos veces no duplica")


func test_alarm_without_point_leaves_no_bell() -> void:
	alert.raise(AlertDirector.Level.ALARM)
	assert_eq(alert.alarm_triggers, 1, "la alarma salta igual")
	assert_eq(alert.alarm_marks.size(), 0, "sin punto no hay campana (ni se usa la del ladrón)")


func test_old_marks_are_forgotten() -> void:
	for i: int in range(AlertDirector.MAX_MARKS + 3):
		alert._last_alarm_call = -INF  # cada una, una situación nueva
		alert.raise(AlertDirector.Level.ALARM, Vector3(i, 0, 0))
	assert_eq(alert.alarm_marks.size(), AlertDirector.MAX_MARKS)
	assert_eq(alert.alarm_marks[0]["pos"], Vector3(3, 0, 0), "se olvidan las más antiguas")


## Revisión #117: la alarma por rastros no puede poner la campana donde está el ladrón
func test_trace_alarm_does_not_reveal_thief() -> void:
	var thief := Node3D.new()
	add_child_autofree(thief)
	thief.add_to_group(&"thief")
	thief.global_position = Vector3(40, 0, 40)
	for i: int in range(2):  # RULES.alarm_traces = 2 piezas ya descubiertas
		var piece: TargetPiece3D = TargetPiece3D.create(
			StringName("T%d" % i), "Pieza", &"sensor", null
		)
		add_child_autofree(piece)
		piece.discovered = true
	alert._last_trace_pos = Vector3(1, 0, 1)  # el último rastro descubierto
	alert.scan()
	assert_eq(alert.level, AlertDirector.Level.ALARM)
	assert_eq(alert.alarm_marks.size(), 1)
	assert_eq(alert.alarm_marks[0]["pos"], Vector3(1, 0, 1), "la campana va en el rastro")
