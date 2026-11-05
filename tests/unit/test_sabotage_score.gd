## @file test_sabotage_score.gd
## Puntos del sabotaje de la caja de la reja (#121, heist.md R7c y R11).
extends GutTest


func _line(score: Dictionary, label: String) -> Dictionary:
	for line: Dictionary in score["lines"]:
		if line["label"] == label:
			return line
	return {}


func test_thief_lines() -> void:
	var score: Dictionary = MatchScore.thief({"sabotaged": 2, "sabotage_escape": true})
	assert_eq(
		_line(score, "Cajas de reja saboteadas"),
		{"label": "Cajas de reja saboteadas", "count": 2, "points": 60}
	)
	assert_eq(_line(score, "Huida por una reja saboteada")["points"], 60)
	assert_eq(score["total"], 120)


func test_thief_without_sabotage_has_no_lines() -> void:
	var score: Dictionary = MatchScore.thief({})
	assert_true(_line(score, "Cajas de reja saboteadas").is_empty())
	assert_true(_line(score, "Huida por una reja saboteada").is_empty())


func test_guard_repair_line() -> void:
	var score: Dictionary = MatchScore.guard({"repairs": 2})
	assert_eq(_line(score, "Cajas reparadas")["points"], 80)
	assert_eq(score["total"], 80)


func test_resolved_example_with_sabotage() -> void:
	# heist.md R11: 1 pieza, una alarma, visto una vez, sabotea P02 y huye por ella
	var report: Dictionary = {
		"thief":
		{
			"pieces": [{"stolen": true}, {"stolen": false}, {"stolen": false}],
			"partial": true,
			"alarms": 1,
			"seen": 1,
			"sabotaged": 1,
			"sabotage_escape": true,
		},
		"guards": [{"seen": 1, "protected": 2}, {"protected": 2}],
	}
	var result: Dictionary = MatchScore.partial_result(report)
	assert_eq(result["thief"], 205)
	assert_eq(result["guards"], 133)
	assert_eq(result["winner"], &"thief")


func test_gate_box_is_a_blueprint_prop() -> void:
	var box: GateBox3D = autofree(GateBox3D.create("P02"))
	assert_eq(BlueprintMapProps.kind_of(box), &"gate_box")
