## @file test_global_gameplay_loop.gd
## Suite global de integración de Velvet Heist '84 (1/2): captura por la porra en museum_v2.
## La segunda mitad está en test_gameplay_loop_late.gd.
extends GutTest

## Espejo tipado de GameManager.MatchState para verificaciones asertivas
enum GameState {LOBBY = 0, IN_PROGRESS = 1, THIEF_ESCAPED = 2, THIEF_CAPTURED = 3, TIME_EXPIRED = 4}

const MAP_SCENE_PATH: String = "res://scenes/maps/museum_v2.tscn"


func before_each() -> void:
	var net_mgr: NetManagerNode = NetManager
	if net_mgr != null and multiplayer.multiplayer_peer != null:
		net_mgr.disconnect_network()
	var gm: Node = GameManager
	if gm != null:
		gm.set("current_state", GameState.LOBBY)
		gm.set("current_loot_value", 0)
		gm.set("has_masterpiece", false)
		gm.set("match_timer", 600.0)


func after_each() -> void:
	var net_mgr: NetManagerNode = NetManager
	if net_mgr != null and multiplayer.multiplayer_peer != null:
		net_mgr.disconnect_network()
	var gm: Node = GameManager
	if gm != null:
		gm.set("current_state", GameState.LOBBY)
		gm.set("current_loot_value", 0)
		gm.set("has_masterpiece", false)
		gm.set("match_timer", 600.0)


# ------------------------------------------------------------------------------
# Test 3: Ciclo de Derrota por Neutralización (2 impactos de porra)
# ------------------------------------------------------------------------------


func test_03_defeat_cycle_by_guard_neutralization() -> void:
	var gm: Node = GameManager
	var map_scene: PackedScene = load(MAP_SCENE_PATH)
	var map: Node3D = autofree(map_scene.instantiate())
	add_child_autofree(map)
	await wait_physics_frames(2)

	gm.call("start_match")
	assert_eq(gm.get("current_state"), GameState.IN_PROGRESS)

	var thief: ThiefController3D = map.thief
	var guard: GuardController3D = map.guards[0]
	thief.reset_baton_hits()
	assert_eq(thief.baton_hits_taken, 0)

	# Posicionar al guardia adyacente al ladrón dentro del radio melee (1.0m < 1.6m)
	guard.global_position = thief.global_position + Vector3(1.0, 0.0, 0.0)
	guard.look_target_position = thief.global_position

	# Impacto 1
	guard.baton_cooldown = 0.0
	var hit1: bool = guard.swing_baton(thief)
	assert_true(hit1, "Primer impacto conecta con éxito")
	assert_eq(thief.baton_hits_taken, 1, "1 impacto registrado en el ladrón")
	assert_eq(gm.get("current_state"), GameState.IN_PROGRESS, "Partida sigue en curso")

	# Impacto 2
	guard.baton_cooldown = 0.0
	var hit2: bool = guard.swing_baton(thief)
	assert_true(hit2, "Segundo impacto conecta con éxito")
	assert_eq(thief.baton_hits_taken, 2, "2 impactos registrados: captura total")
	assert_eq(
		gm.get("current_state"),
		GameState.THIEF_CAPTURED,
		"Estado autoritativo cambia a THIEF_CAPTURED"
	)

	map.hud._process(0.016)
	assert_true(map.hud.game_over_panel.visible, "HUD muestra panel de derrota")
	assert_true(map.hud.game_over_title.text.contains("CAPTURADO"))
