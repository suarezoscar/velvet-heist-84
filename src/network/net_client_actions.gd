## @file net_client_actions.gd
## Acciones discretas del jugador local que NetSessionClient manda al servidor (FEAT-014).
class_name NetClientActions
extends RefCounted


static func polled(
	session: NetSession, dial_repeat: DialRepeat, world_states: Dictionary, delta: float
) -> Array[StringName]:
	var actions: Array[StringName] = []
	if session.actor_for_role(NetManager.get_local_role()) is GuardController3D:
		var flashlight: StringName = GuardFlashlight.poll()  # mantener = encendida (#112)
		if flashlight != &"":
			actions.append(flashlight)  # con la pausa abierta, poll la apaga
	if LocalInput3D.blocked:  # menú de pausa abierto
		CoinTrigger.reset()
		return actions
	if just_pressed(&"interact"):
		actions.append(&"interact")
	if just_pressed(&"strike"):
		actions.append(&"strike")
	if just_pressed(&"crouch"):
		actions.append(&"crouch_toggle")
	for heist_action: StringName in [&"force"] + HeistActions.ACTIONS:
		if heist_action == CoinTrigger.ACTION:
			if CoinTrigger.poll():  # se apunta manteniendo y se lanza al soltar (FEAT-038)
				actions.append(heist_action)
		elif HeistActions.ON_RELEASE.has(heist_action):
			if InputMap.has_action(heist_action) and Input.is_action_just_released(heist_action):
				actions.append(heist_action)  # el walkie sale al soltar, al punto del ratón
		elif just_pressed(heist_action):
			actions.append(heist_action)
	var cracking: bool = any_safe_cracking(world_states)
	var step: int = dial_repeat.update(
		cracking and DialRepeat.left_held(), cracking and DialRepeat.right_held(), delta
	)
	if step != 0:
		actions.append(&"dial_left" if step < 0 else &"dial_right")
		SafeBox3D.predict_local(session.map.get_tree(), step)  # #164: el dial sin esperar
	var thief: bool = session.map.local_player is ThiefController3D  # #119: soltar E pausa
	if thief and Input.is_action_just_released(&"interact"):  # aunque no llegara aún el estado
		actions.append(&"interact_release")
	var playing: bool = thief and StealMinigame.piece_of(session.map.local_player) != null
	if (cracking or playing) and just_pressed(&"ui_cancel"):
		actions.append(&"dial_cancel")
	return actions + VentInput.poll(session.map.get_tree())  # #167: el plano de los conductos


static func just_pressed(action: StringName) -> bool:
	return InputMap.has_action(action) and Input.is_action_just_pressed(action)


static func any_safe_cracking(world_states: Dictionary) -> bool:
	for path: String in world_states:
		var state: Dictionary = world_states[path]
		if bool(state.get("cracking", false)):
			return true
	return false
