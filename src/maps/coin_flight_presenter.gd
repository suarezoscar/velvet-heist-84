## @file coin_flight_presenter.gd
## Dibuja las monedas que ve el jugador local (FEAT-038). Sin red escucha
## SignalBus.coin_thrown; con red, NetSessionClient le pasa las que el servidor le manda, ya
## filtradas y recortadas con view_for.
class_name CoinFlightPresenter
extends Node

const GROUP: StringName = &"coin_flight_presenter"
## Tramos en los que se busca dónde entra la moneda en la zona visible de un guardia
const VIEW_STEPS: int = 16


## true si actor debe ver la moneda: el ladrón siempre (es suya); un guardia despierto, si la
## salida o la caída están en su zona visible (vision.md R1)
static func visible_to(actor: Node3D, from: Vector3, landing: Vector3) -> bool:
	if actor is ThiefController3D:
		return true
	if actor is GuardController3D and GuardSleep.sees_nothing(actor as GuardController3D):
		return false  # en la cabezada no ve nada
	return VisionLogic.sees_point(actor, from) or VisionLogic.sees_point(actor, landing)


## Qué ve actor de una moneda: {} si nada; si no, {"from", "flight"} con el tramo que ve y, si
## es solo un tramo, "delay": cuándo empieza a verlo. Quien ve la salida (el ladrón siempre) ve
## el arco entero; un guardia que solo ve la caída recibe el tramo desde donde entra en su zona
## visible, a la altura de la mano y cuando entra, así que cae a la vez que suena: sabe de qué
## lado viene, no desde dónde se lanzó
static func view_for(actor: Node3D, from: Vector3, landing: Vector3, flight: float) -> Dictionary:
	if not visible_to(actor, from, landing):
		return {}
	if actor is ThiefController3D or VisionLogic.sees_point(actor, from):
		return {"from": from, "flight": flight}
	for step: int in range(1, VIEW_STEPS + 1):
		var t: float = float(step) / VIEW_STEPS
		var point: Vector3 = CoinThrow.arc_point(from, landing, t)
		# A la altura de la mano: la del arco dejaría calcular la distancia del lanzamiento
		var entry: Vector3 = Vector3(point.x, landing.y + CoinThrow.HAND_HEIGHT, point.z)
		if VisionLogic.sees_point(actor, entry):
			return {"from": entry, "flight": flight * (1.0 - t), "delay": flight * t}
	return {"from": landing, "flight": 0.0, "delay": flight}


## El presentador del mapa actual (null si no hay)
static func of(tree: SceneTree) -> CoinFlightPresenter:
	return tree.get_first_node_in_group(GROUP) as CoinFlightPresenter


func _ready() -> void:
	name = "CoinFlightPresenter"
	add_to_group(GROUP)
	SignalBus.coin_thrown.connect(_on_coin_thrown)


## Dibuja una moneda en vuelo
func show_coin(from: Vector3, landing: Vector3, flight_time: float) -> void:
	var parent: Node = get_parent()
	if parent != null:
		CoinFlight3D.launch(parent, from, landing, flight_time)


func _on_coin_thrown(from: Vector3, landing: Vector3, flight_time: float) -> void:
	if NetManager.is_online():
		return  # con red, cada cliente recibe solo las que ve
	var actor: PlayerBase3D = _local_actor()
	var view: Dictionary = view_for(actor, from, landing, flight_time) if actor != null else {}
	if view.is_empty():
		return
	var delay: float = float(view.get("delay", 0.0))
	if delay > 0.0:
		await get_tree().create_timer(delay, false).timeout
	show_coin(view["from"], landing, view["flight"])


func _local_actor() -> PlayerBase3D:
	for group: StringName in [&"thief", &"guards"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			var actor: PlayerBase3D = node as PlayerBase3D
			if actor != null and actor.is_locally_controlled:
				return actor
	return null
