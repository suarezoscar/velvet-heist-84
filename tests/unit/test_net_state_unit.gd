## @file test_net_state_unit.gd
## Pruebas unitarias de acciones de actores (perform_action) y estados de red (PKG-2).
extends GutTest


class DummyTarget:
	extends Node3D

	var was_interacted: bool = false

	func can_interact(_actor: Node3D = null) -> bool:
		return true

	func interact(_actor: Node3D) -> void:
		was_interacted = true


func test_perform_action_crouch_toggle() -> void:
	var player: PlayerBase3D = autofree(PlayerBase3D.new())
	add_child_autofree(player)
	assert_false(player.is_crouching, "Inicialmente no agachado")

	var executed: bool = player.perform_action(&"crouch_toggle")
	assert_true(executed, "perform_action crouch_toggle devuelve true")
	assert_true(player.is_crouching, "Pasa a estar agachado")

	executed = player.perform_action(&"crouch_toggle")
	assert_true(executed, "perform_action crouch_toggle de nuevo devuelve true")
	assert_false(player.is_crouching, "Vuelve a estar de pie")


func test_perform_action_interact_thief() -> void:
	var thief: ThiefController3D = autofree(ThiefController3D.new())
	add_child_autofree(thief)

	var executed_no_target: bool = thief.perform_action(&"interact")
	assert_false(executed_no_target, "Sin objetivo enfocado devuelve false")

	var dummy: DummyTarget = autofree(DummyTarget.new())
	add_child_autofree(dummy)
	thief.interactor.current_target = dummy

	var executed_with_target: bool = thief.perform_action(&"interact")
	assert_true(executed_with_target, "Con objetivo enfocado devuelve true")
	assert_true(dummy.was_interacted, "Ejecuta interact sobre el objetivo")


func test_perform_action_interact_guard() -> void:
	var guard: GuardController3D = autofree(GuardController3D.new())
	add_child_autofree(guard)

	var dummy: DummyTarget = autofree(DummyTarget.new())
	add_child_autofree(dummy)
	guard.interactor.current_target = dummy

	var executed: bool = guard.perform_action(&"interact")
	assert_true(executed, "Guardia interactúa con objetivo enfocado")
	assert_true(dummy.was_interacted, "Se ejecuta interacción")


func test_perform_action_toggle_flashlight() -> void:
	var guard: GuardController3D = autofree(GuardController3D.new())
	add_child_autofree(guard)
	assert_true(guard.flashlight_on, "Linterna encendida por defecto")

	var executed: bool = guard.perform_action(&"toggle_flashlight")
	assert_true(executed, "toggle_flashlight devuelve true")
	assert_false(guard.flashlight_on, "Linterna apagada tras acción")

	executed = guard.perform_action(&"toggle_flashlight")
	assert_true(executed, "toggle_flashlight devuelve true")
	assert_true(guard.flashlight_on, "Linterna encendida de nuevo")


func test_perform_action_strike() -> void:
	var guard: GuardController3D = autofree(GuardController3D.new())
	var thief: ThiefController3D = autofree(ThiefController3D.new())
	guard.position = Vector3.ZERO
	thief.position = Vector3(0.0, 0.0, 1.0)
	add_child_autofree(guard)
	add_child_autofree(thief)
	guard.baton_cooldown = 0.0

	var hit: bool = guard.perform_action(&"strike")
	assert_true(hit, "Golpe conecta con el ladrón dentro de rango")

	var spam_hit: bool = guard.perform_action(&"strike")
	assert_false(spam_hit, "Golpe inmediato durante cooldown es rechazado")


func test_perform_action_dial_actions() -> void:
	var thief: ThiefController3D = autofree(ThiefController3D.new())
	var safe: SafeBox3D = autofree(SafeBox3D.new())
	add_child_autofree(thief)
	add_child_autofree(safe)

	assert_false(thief.perform_action(&"dial_right"), "Sin caja activa devuelve false")

	safe.interact(thief)
	assert_eq(safe.current_state, SafeBox3D.SafeState.CRACKING, "Caja en estado CRACKING")

	var rotated_right: bool = thief.perform_action(&"dial_right")
	assert_true(rotated_right, "dial_right devuelve true")
	assert_eq(safe.current_dial_val, 1, "Dial avanza a 1")

	var rotated_left: bool = thief.perform_action(&"dial_left")
	assert_true(rotated_left, "dial_left devuelve true")
	assert_eq(safe.current_dial_val, 0, "Dial retrocede a 0")

	var cancelled: bool = thief.perform_action(&"dial_cancel")
	assert_true(cancelled, "dial_cancel devuelve true")
	assert_eq(safe.current_state, SafeBox3D.SafeState.LOCKED, "Caja vuelve a LOCKED")


func test_perform_action_invalid_action() -> void:
	var player: PlayerBase3D = autofree(PlayerBase3D.new())
	add_child_autofree(player)
	assert_false(player.perform_action(&"accion_inexistente"), "Acción desconocida rechazada")


func test_safe_box_step_dial_and_cancel() -> void:
	var safe: SafeBox3D = autofree(SafeBox3D.new())
	add_child_autofree(safe)

	safe.step_dial(1)
	assert_eq(safe.current_dial_val, 0, "step_dial no hace nada si está LOCKED")

	safe.current_state = SafeBox3D.SafeState.CRACKING
	safe.current_dial_val = 0
	safe.step_dial(1)
	assert_eq(safe.current_dial_val, 1, "step_dial(1) avanza dial")

	safe.current_dial_val = 0
	safe.step_dial(-1)
	assert_eq(safe.current_dial_val, 99, "step_dial(-1) envuelve a 99")

	safe.step_dial(1)
	assert_eq(safe.current_dial_val, 0, "step_dial(1) envuelve a 0")

	safe.cancel_cracking()
	assert_eq(safe.current_state, SafeBox3D.SafeState.LOCKED, "cancel_cracking bloquea la caja")


func test_roundtrip_loot_item() -> void:
	var item1: LootItem3D = autofree(LootItem3D.new())
	var item2: LootItem3D = autofree(LootItem3D.new())
	add_child_autofree(item1)
	add_child_autofree(item2)

	item1.is_collected = true
	item1.is_deposited = true
	var s: Dictionary = item1.get_net_state()

	item2.apply_net_state(s)
	assert_eq(item2.get_net_state(), s, "Roundtrip LootItem3D idéntico")
	assert_false(item2.visible, "Item depositado se oculta")


func test_roundtrip_loot_item_holder() -> void:
	# current_scene tiene que colgar directamente de la raíz del árbol
	var scene_root: Node3D = autofree(Node3D.new())
	get_tree().root.add_child(scene_root)
	var thief: ThiefController3D = ThiefController3D.new()
	thief.name = "Thief"
	scene_root.add_child(thief)
	var item: LootItem3D = LootItem3D.new()
	scene_root.add_child(item)

	var tree: SceneTree = get_tree()
	var previous_scene: Node = tree.current_scene
	tree.current_scene = scene_root
	watch_signals(SignalBus)

	var holder_path: String = String(scene_root.get_path_to(thief))
	item.apply_net_state({"collected": true, "holder": holder_path, "deposited": false})

	tree.current_scene = previous_scene
	assert_eq(item.get_parent(), thief.carry_anchor, "El botín cuelga del ancla del ladrón")
	assert_eq(thief.carried_loot, item, "El ladrón registra el botín cargado")
	assert_false(item.monitoring, "Sin detección mientras se carga")
	assert_false(item.monitorable, "Sin detección mientras se carga")
	assert_signal_not_emitted(SignalBus, "noise_event_3d", "Aplicar el estado no emite ruido")
	assert_signal_not_emitted(SignalBus, "loot_stolen", "Aplicar el estado no suma botín")


func test_roundtrip_lamp() -> void:
	var lamp1: Lamp3D = autofree(Lamp3D.new())
	var lamp2: Lamp3D = autofree(Lamp3D.new())
	add_child_autofree(lamp1)
	add_child_autofree(lamp2)

	lamp1.is_switched_on = false
	lamp1.is_unscrewed = true
	var s: Dictionary = lamp1.get_net_state()

	lamp2.apply_net_state(s)
	assert_eq(lamp2.get_net_state(), s, "Roundtrip Lamp3D idéntico")


func test_roundtrip_safe_box() -> void:
	var safe1: SafeBox3D = autofree(SafeBox3D.new())
	var safe2: SafeBox3D = autofree(SafeBox3D.new())
	add_child_autofree(safe1)
	add_child_autofree(safe2)

	safe1.current_state = SafeBox3D.SafeState.OPENED
	var s_pub: Dictionary = safe1.get_net_state()
	safe2.apply_net_state(s_pub)
	assert_eq(safe2.get_net_state(), s_pub, "Roundtrip SafeBox3D público idéntico")

	safe1.current_state = SafeBox3D.SafeState.CRACKING
	safe1.current_dial_val = 42
	safe1.current_stage = 2
	var s_priv: Dictionary = safe1.get_net_state_private()
	safe2.apply_net_state(s_priv)
	assert_eq(safe2.get_net_state_private(), s_priv, "Roundtrip SafeBox3D privado idéntico")


func test_roundtrip_escape_car() -> void:
	var car1: EscapeCar3D = autofree(EscapeCar3D.new())
	var car2: EscapeCar3D = autofree(EscapeCar3D.new())
	add_child_autofree(car1)
	add_child_autofree(car2)

	car1.is_escaped = true
	var s: Dictionary = car1.get_net_state()
	car2.apply_net_state(s)
	assert_eq(car2.get_net_state(), s, "Roundtrip EscapeCar3D idéntico")


func test_roundtrip_time_clock() -> void:
	var clock1: TimeClock3D = autofree(TimeClock3D.new())
	var clock2: TimeClock3D = autofree(TimeClock3D.new())
	add_child_autofree(clock1)
	add_child_autofree(clock2)

	clock1.time_left = 33.5
	clock1.is_expired = true
	var s: Dictionary = clock1.get_net_state()
	clock2.apply_net_state(s)
	assert_eq(clock2.get_net_state(), s, "Roundtrip TimeClock3D idéntico")


func test_roundtrip_security_camera() -> void:
	var scene: PackedScene = load("res://scenes/entities/security_camera.tscn") as PackedScene
	var cam1: SecurityCamera3D = scene.instantiate() as SecurityCamera3D
	var cam2: SecurityCamera3D = scene.instantiate() as SecurityCamera3D
	add_child_autofree(cam1)
	add_child_autofree(cam2)
	var root_rot: float = deg_to_rad(135.0)
	cam2.rotation.y = root_rot

	cam1.mount.rotation.y = 0.3
	cam1.is_alert_active = true
	var s: Dictionary = cam1.get_net_state()
	cam2.apply_net_state(s)
	assert_eq(cam2.get_net_state(), s, "Roundtrip SecurityCamera3D idéntico")
	assert_almost_eq(cam2.rotation.y, root_rot, 0.001, "La raíz conserva su orientación de escena")
	assert_almost_eq(cam2.mount.rotation.y, 0.3, 0.001, "El barrido local llega al CameraMount")


func test_roundtrip_actor_states() -> void:
	var p1: PlayerBase3D = autofree(PlayerBase3D.new())
	var p2: PlayerBase3D = autofree(PlayerBase3D.new())
	add_child_autofree(p1)
	add_child_autofree(p2)

	p1.global_position = Vector3(1.0, 2.0, 3.0)
	p1.velocity = Vector3(4.0, 0.0, 5.0)
	p1.rotation.y = 0.5
	p1.look_target_position = Vector3(6.0, 0.0, 7.0)
	p1.is_crouching = true
	var sp: Dictionary = p1.get_net_actor_state()
	p2.apply_net_actor_state(sp)
	assert_eq(p2.get_net_actor_state(), sp, "Roundtrip PlayerBase3D idéntico")

	var g1: GuardController3D = autofree(GuardController3D.new())
	var g2: GuardController3D = autofree(GuardController3D.new())
	add_child_autofree(g1)
	add_child_autofree(g2)

	g1.stamina = 55.0
	g1.flashlight_on = false
	g1.is_perceiving_thief = true
	g1.last_seen_position = Vector3(3.0, 0.0, 3.0)
	g1.last_seen_time_left = 2.0
	var sg: Dictionary = g1.get_net_actor_state()
	g2.apply_net_actor_state(sg)
	assert_eq(g2.get_net_actor_state(), sg, "Roundtrip GuardController3D idéntico")

	var t1: ThiefController3D = autofree(ThiefController3D.new())
	add_child_autofree(t1)
	assert_false(t1.get_net_actor_state().has("stamina"), "El ladrón no replica estamina")
