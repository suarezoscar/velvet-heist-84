extends GutTest
## Puntuación en vivo en el HUD (#123): colores de los avisos, total, avisos y línea de equipo.


func test_color_for() -> void:
	assert_eq(ScoreHud84.color_for("+25 VISTO"), ScoreHud84.GOOD_COLOR)
	assert_eq(ScoreHud84.color_for("−15 ALARMA"), ScoreHud84.BAD_COLOR)


func test_total_y_avisos_sin_duplicar() -> void:
	var hud: ScoreHud84 = ScoreHud84.new()
	add_child_autofree(hud)
	var live: LiveScore = LiveScore.create(&"thief")
	add_child_autofree(live)
	hud.role = &"thief"
	live.total = 40
	live.notes = [[1, "+25 VISTO"]]
	await wait_process_frames(2)
	assert_eq(hud.total_label.text, "PUNTOS 40")
	assert_eq(hud._notes_box.get_child_count(), 1)
	await wait_process_frames(2)
	assert_eq(hud._notes_box.get_child_count(), 1)


func test_team_line() -> void:
	var guards: Array = []
	for index: int in 2:
		var guard: Dictionary = {"protected": 2, "k": 3, "guards": 2}
		if index == 0:
			guard["alarm"] = true
		guards.append(guard)
	var report: Dictionary = {
		"quota": 3,
		"thief": {"guards": 2, "pieces": [{"stolen": true}, {"stolen": false}, {"stolen": false}]},
		"guards": guards,
	}
	assert_eq(MatchSummary.team_line(report), "Equipo: 200 de las piezas + 35 de lo que hicisteis")
