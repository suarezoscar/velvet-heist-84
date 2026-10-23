## @file test_local_view.gd
## Tests de aceptación para la vista local del jugador (FEAT-012 Criterios 10 y 11).
## Comprueba el indicador de exposición del ladrón (O1) y la silueta O2 del guardia local.
extends GutTest

const HUD_SCENE_PATH: String = "res://scenes/ui/hud_84.tscn"


func after_each() -> void:
	GameManager.current_state = GameManager.MatchState.LOBBY


## Criterio 10: O1: Exposición del ladrón (beam > lit > shadow) y &"" para otros
func test_thief_exposure() -> void:
	var map: HeistMap3D = autofree(HeistMap3D.new())

	var hud_scene: PackedScene = load(HUD_SCENE_PATH) as PackedScene
	var hud: HUD84 = hud_scene.instantiate() as HUD84
	hud.name = "HUD84"
	map.add_child(hud)

	var camera: Camera3D = Camera3D.new()
	camera.name = "IsometricCamera3D"
	map.add_child(camera)

	var thief: ThiefController3D = autofree(ThiefController3D.new())
	thief.name = "Thief"
	thief.position = Vector3.ZERO
	map.add_child(thief)

	var guard: GuardController3D = autofree(GuardController3D.new())
	guard.name = "Guard"
	guard.position = Vector3(0.0, 0.0, 4.0)
	map.add_child(guard)

	var lamp: Lamp3D = autofree(Lamp3D.new())
	var lamp_prof: LampProfile = LampProfile.new()
	lamp_prof.lit_radius = 5.0
	lamp.profile = lamp_prof
	lamp.start_on = false
	lamp.is_switched_on = false
	lamp.is_unscrewed = false
	lamp.position = Vector3(0.0, 2.0, 0.0)
	map.add_child(lamp)

	add_child_autofree(map)
	map.set_physics_process(false)
	thief.set_physics_process(false)
	guard.set_physics_process(false)
	guard.set_flashlight(false)

	map.set_local_player(thief)
	await wait_physics_frames(2)

	# 1. Sin linterna y sin lámpara: shadow
	map.local_view_presenter._physics_process(0.0)
	assert_eq(hud.get_exposure(), &"shadow", "Sin iluminación debe ser 'shadow'")

	# 2. Con lámpara encendida: lit
	lamp.set_switched(true)
	await wait_physics_frames(1)
	map.local_view_presenter._physics_process(0.0)
	assert_eq(hud.get_exposure(), &"lit", "Iluminado por lámpara debe ser 'lit'")

	# 3. Con linterna de guardia hacia el ladrón: beam (prioridad sobre lit)
	guard.set_flashlight(true)
	await wait_physics_frames(1)
	map.local_view_presenter._physics_process(0.0)
	assert_eq(
		hud.get_exposure(),
		&"beam",
		"Linterna en cono directo tiene prioridad sobre lámpara: 'beam'"
	)

	# 4. Apagar lámpara manteniendo linterna: sigue siendo beam
	lamp.set_switched(false)
	await wait_physics_frames(1)
	map.local_view_presenter._physics_process(0.0)
	assert_eq(hud.get_exposure(), &"beam", "Solo linterna debe ser 'beam'")

	# 5. Con guardia como jugador local: exposición es &""
	map.set_local_player(guard)
	map.local_view_presenter._physics_process(0.0)
	assert_eq(hud.get_exposure(), &"", "Con jugador local guardia, exposición debe ser &''")


## Criterio 11: O2: Silueta de última posición vista del ladrón para el guardia local
func test_last_seen_marker() -> void:
	var map: HeistMap3D = autofree(HeistMap3D.new())

	var hud_scene: PackedScene = load(HUD_SCENE_PATH) as PackedScene
	var hud: HUD84 = hud_scene.instantiate() as HUD84
	hud.name = "HUD84"
	map.add_child(hud)

	var camera: Camera3D = Camera3D.new()
	camera.name = "IsometricCamera3D"
	map.add_child(camera)

	var thief: ThiefController3D = autofree(ThiefController3D.new())
	thief.name = "Thief"
	thief.position = Vector3(10.0, 0.0, 10.0)
	map.add_child(thief)

	var guard: GuardController3D = autofree(GuardController3D.new())
	guard.name = "Guard"
	guard.position = Vector3.ZERO
	map.add_child(guard)

	add_child_autofree(map)
	map.set_physics_process(false)
	thief.set_physics_process(false)
	guard.set_physics_process(false)

	map.set_local_player(guard)
	var presenter: LocalViewPresenter = map.local_view_presenter
	var marker: LastSeenMarker3D = presenter._last_seen_marker
	assert_not_null(marker, "LastSeenMarker3D debe estar instanciado en el presentador")

	var perception: PerceptionProfile = (
		load("res://data/balance/perception_guard.tres") as PerceptionProfile
	)
	assert_not_null(perception, "perception_guard.tres debe cargarse")
	guard.perception = perception
	var dt: float = 0.016

	# 1. Coloca al ladrón dentro de proximity_radius del guardia sin solapar cápsulas
	thief.global_position = Vector3(0.0, 0.0, -1.0)
	guard.update_perception(thief, [], dt)
	presenter._physics_process(dt)
	assert_true(guard.is_perceiving_thief, "Guardia debe percibir al ladrón")
	assert_false(marker.visible, "Mientras percibe al ladrón, el marcador no es visible")

	# 2. Aleja al ladrón fuera de radio, cono y luz -> silueta visible en última posición
	var last_pos: Vector3 = thief.global_position
	thief.global_position = Vector3(50.0, 0.0, 50.0)
	guard.update_perception(thief, [], dt)
	presenter._physics_process(dt)
	assert_false(guard.is_perceiving_thief, "Guardia deja de percibir al ladrón")
	assert_true(marker.visible, "Al perder visibilidad debe aparecer la silueta")
	assert_almost_eq(marker.global_position.x, last_pos.x, 0.01, "Posición X de silueta correcta")
	assert_almost_eq(marker.global_position.z, last_pos.z, 0.01, "Posición Z de silueta correcta")

	# 3. Tras last_seen_linger + 0.01 s, la silueta desaparece
	guard.update_perception(thief, [], perception.last_seen_linger + 0.01)
	presenter._physics_process(dt)
	assert_false(marker.visible, "Cuando el tiempo de última posición expira, desaparece")

	# 4. Cambiar el jugador local oculta el marcador inmediatamente
	thief.global_position = Vector3(0.0, 0.0, -1.0)
	guard.update_perception(thief, [], dt)
	presenter._physics_process(dt)
	thief.global_position = Vector3(50.0, 0.0, 50.0)
	guard.update_perception(thief, [], dt)
	presenter._physics_process(dt)
	assert_true(marker.visible, "Marcador visible de nuevo")

	map.set_local_player(thief)
	presenter._physics_process(dt)
	assert_false(marker.visible, "Cambiar de jugador local oculta la silueta")
