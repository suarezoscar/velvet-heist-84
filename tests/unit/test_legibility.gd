## @file test_legibility.gd
## Legibilidad (FEAT-027): marcas de bando que siguen la visibilidad del cuerpo (nunca delatan
## al ladrón), «TÚ» en el jugador local, tarjeta de objetivo por bando y resumen de la partida.
extends GutTest

const MAP_SCENE: PackedScene = preload("res://scenes/maps/museum_v2.tscn")

var _saved_state: GameManager.MatchState


func before_each() -> void:
	_saved_state = GameManager.current_state


func after_each() -> void:
	GameManager.current_state = _saved_state


func _marker(actor: PlayerBase3D) -> TeamMarker3D:
	return actor.get_node("VisualRoot/TeamMarker") as TeamMarker3D


func test_every_actor_has_a_marker_and_local_is_highlighted() -> void:
	var map: HeistMap3D = MAP_SCENE.instantiate() as HeistMap3D
	add_child_autofree(map)
	await wait_physics_frames(2)
	assert_eq(_marker(map.thief).color, TeamMarker3D.THIEF_COLOR)
	assert_eq(_marker(map.thief).label.text, "TÚ", "Sin red eres el ladrón")
	assert_eq(_marker(map.guards[0]).color, TeamMarker3D.GUARD_COLOR)
	assert_eq(_marker(map.guards[1]).label.text, "2", "Número de guardia")
	map.set_local_player(map.guards[0])
	await wait_physics_frames(1)
	assert_eq(_marker(map.guards[0]).label.text, "TÚ")
	assert_false(_marker(map.thief).label.visible, "El ladrón ajeno no lleva etiqueta")


func test_marker_hides_and_goes_cctv_with_the_body() -> void:
	var map: HeistMap3D = MAP_SCENE.instantiate() as HeistMap3D
	add_child_autofree(map)
	await wait_physics_frames(1)
	var marker: TeamMarker3D = _marker(map.thief)
	map.thief.set_view_mode(ThiefController3D.ViewMode.HIDDEN)
	assert_false(marker.is_visible_in_tree(), "Ladrón oculto: marca oculta")
	map.thief.set_view_mode(ThiefController3D.ViewMode.CCTV)
	var ring: MeshInstance3D = marker.get_node("Ring") as MeshInstance3D
	var world_layers: int = int(ring.get_meta(&"world_layers"))
	assert_eq(ring.layers, 1 << (ThiefController3D.CCTV_ONLY_LAYER - 1), "Solo en las cámaras")
	assert_eq(marker.label.layers, ring.layers, "La etiqueta también")
	map.thief.set_view_mode(ThiefController3D.ViewMode.WORLD)
	assert_eq(ring.layers, world_layers, "Vuelve a la capa del mundo")
	map.guards[0].set_body_visible(false)
	assert_false(_marker(map.guards[0]).is_visible_in_tree(), "Guardia oculto: marca oculta")


func test_marker_arrow_points_where_the_actor_faces() -> void:
	var map: HeistMap3D = MAP_SCENE.instantiate() as HeistMap3D
	add_child_autofree(map)
	await wait_physics_frames(1)
	var marker: TeamMarker3D = _marker(map.thief)
	var forward: Vector3 = -map.thief.global_basis.z
	assert_almost_eq(
		(-marker.global_basis.z).dot(forward), 1.0, 0.01, "La flecha (-Z) es el frente"
	)


func test_briefing_lines_use_match_numbers() -> void:
	var thief: Array[String] = RoleBriefing84.objectives(true, 12000, 8, 4)
	assert_string_contains(thief[0], "$12000")
	assert_string_contains(thief[1], "8 minutos")
	var guard: Array[String] = RoleBriefing84.objectives(false, 12000, 8, 4)
	assert_string_contains(guard[1], "4 relojes")


func test_summary_verdict_per_side() -> void:
	var escaped: GameManager.MatchState = GameManager.MatchState.THIEF_ESCAPED
	assert_eq(MatchSummary.winner(escaped), &"thief")
	assert_eq(MatchSummary.verdict(escaped, &"thief"), "HAS GANADO")
	assert_eq(MatchSummary.verdict(escaped, &"guards"), "HAS PERDIDO")
	assert_eq(
		MatchSummary.verdict(GameManager.MatchState.THIEF_CAPTURED, &""), "GANAN LOS GUARDIAS"
	)
	assert_eq(MatchSummary.verdict(GameManager.MatchState.TIME_EXPIRED_DRAW, &"thief"), "EMPATE")
	var stats: String = MatchSummary.stats(6500, 10000, false, 252.0, 1, 2)
	assert_string_contains(stats, "$6500 de $10000")
	assert_string_contains(stats, "4:12")
	assert_string_contains(stats, "1 de 2")
