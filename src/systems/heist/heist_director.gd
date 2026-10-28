## @file heist_director.gd
## El encargo del coleccionista (heist.md R1-R4). Lo crea LevelEntitiesBuilder cuando el nivel
## tiene piezas candidatas (TargetPiece3D, grupo heist_targets) y se registra en GameManager.
## El servidor (o la partida sin red) sortea al empezar qué piezas tiene que robar el ladrón,
## según cuántos guardias hay. A todos les llega cuántas son y cuáles se han robado; cuáles
## son solo al ladrón (estado privado). Con todas robadas, cualquier salida exterior le da la
## victoria (ExitZone3D). Cuántas lleva robadas también es privado del ladrón: los guardias se
## enteran por los rastros (heist.md R6).
class_name HeistDirector
extends Node

const RULES: HeistRules = preload("res://data/balance/heist_rules.tres")

## Ids de las piezas del encargo (en los guardias, vacío)
var targets: Array[StringName] = []
## Cuántas piezas tiene el encargo (público)
var contract_size: int = 0
## Ids de las piezas del encargo ya robadas (privado del ladrón)
var stolen: Array[StringName] = []
## Monedas que le quedan al ladrón (heist.md R8; privado del ladrón)
var coins_left: int = RULES.coins
## Lleva una pieza de pega del taller (heist.md R9; privado del ladrón)
var carrying_fake: bool = false


func _ready() -> void:
	name = "HeistDirector"
	add_to_group(&"net_state")
	GameManager.heist = self
	if GameManager.is_simulating():
		# Tras el _ready del mapa, que ya ha quitado los guardias que sobran
		_draw_contract.call_deferred()


func _exit_tree() -> void:
	if GameManager.heist == self:
		GameManager.heist = null


## Piezas candidatas del nivel, por id
func candidates() -> Array[StringName]:
	var ids: Array[StringName] = []
	for node: Node in get_tree().get_nodes_in_group(&"heist_targets"):
		ids.append((node as TargetPiece3D).piece_id)
	return ids


## Pieza por id (null si no existe)
func piece(piece_id: StringName) -> TargetPiece3D:
	for node: Node in get_tree().get_nodes_in_group(&"heist_targets"):
		if (node as TargetPiece3D).piece_id == piece_id:
			return node as TargetPiece3D
	return null


## Sortea el encargo: count piezas distintas de entre candidates
static func draw(
	candidate_ids: Array[StringName], count: int, rng: RandomNumberGenerator
) -> Array[StringName]:
	var pool: Array[StringName] = candidate_ids.duplicate()
	var picked: Array[StringName] = []
	while picked.size() < count and not pool.is_empty():
		picked.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return picked


func is_in_contract(piece_id: StringName) -> bool:
	return targets.has(piece_id)


## true con todas las piezas del encargo robadas
func is_complete() -> bool:
	return contract_size > 0 and stolen.size() >= contract_size


## Lo llama la pieza en el servidor al robarse
func mark_stolen(piece_id: StringName) -> void:
	if is_in_contract(piece_id) and not stolen.has(piece_id):
		stolen.append(piece_id)
		print("[HeistDirector] Robada %s (%d/%d)" % [piece_id, stolen.size(), contract_size])


## Al acabar la partida se revela a todos el encargo y lo robado (para el resumen)
func get_net_state() -> Dictionary:
	if GameManager.is_match_over():
		return {"size": contract_size, "targets": targets.duplicate(), "stolen": stolen.duplicate()}
	return {"size": contract_size}


func get_net_state_private() -> Dictionary:
	return {
		"targets": targets.duplicate(),
		"stolen": stolen.duplicate(),
		"coins": coins_left,
		"fake": carrying_fake,
	}


## true si en esta máquina se juega con el ladrón
static func local_is_thief(tree: SceneTree) -> bool:
	var thief: ThiefController3D = tree.get_first_node_in_group(&"thief") as ThiefController3D
	return thief != null and thief.is_locally_controlled


func net_private_audience() -> StringName:
	return &"thief"


func apply_net_state(state: Dictionary) -> void:
	if state.has("size"):
		contract_size = int(state["size"])
	if state.has("stolen"):
		stolen.assign(state["stolen"])
	if state.has("targets"):
		targets.assign(state["targets"])
	if state.has("coins"):
		coins_left = int(state["coins"])
	if state.has("fake"):
		carrying_fake = bool(state["fake"])


func _draw_contract() -> void:
	var ids: Array[StringName] = candidates()
	var guards: int = get_tree().get_nodes_in_group(&"guards").size()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	targets = draw(ids, RULES.pieces_for(guards, ids.size()), rng)
	contract_size = targets.size()
	stolen.clear()
	print("[HeistDirector] Encargo de %d piezas para %d guardias" % [contract_size, guards])
