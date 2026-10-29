## @file coin_flight_presenter.gd
## Dibuja las monedas que ve el jugador local (FEAT-038). Sin red escucha
## SignalBus.coin_thrown; con red, NetSessionClient le pasa las que el servidor le manda, ya
## filtradas con visible_to.
class_name CoinFlightPresenter
extends Node

const GROUP: StringName = &"coin_flight_presenter"


## true si actor debe ver la moneda: el ladrón siempre (es suya); un guardia, si la salida o
## la caída están en su zona visible (vision.md R1)
static func visible_to(actor: Node3D, from: Vector3, landing: Vector3) -> bool:
	if actor is ThiefController3D:
		return true
	return VisionLogic.sees_point(actor, from) or VisionLogic.sees_point(actor, landing)


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
	if actor != null and visible_to(actor, from, landing):
		show_coin(from, landing, flight_time)


func _local_actor() -> PlayerBase3D:
	for group: StringName in [&"thief", &"guards"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			var actor: PlayerBase3D = node as PlayerBase3D
			if actor != null and actor.is_locally_controlled:
				return actor
	return null
