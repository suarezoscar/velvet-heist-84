## @file time_clock_3d.gd
## Reloj de fichar de la ronda de los guardias (interaction.md, parte R; FEAT-034). Cada guardia
## tiene su ruta de relojes (GuardRound): aquí solo ficha quien lo tiene como siguiente. Cuando
## a un guardia se le pasa el tiempo para llegar a este reloj, baja la banderola roja (la ve
## todo el mundo) y suena su campana. Solo el servidor (o la partida sin red) simula.
class_name TimeClock3D
extends Area3D

## Emitida cuando un guardia gira su llave en la ranura
signal clock_punched(clock_id: int, guard_peer_id: int)

const RULES: TimeClockRules = preload("res://data/balance/time_clock_rules.tres")
const FLAG_COLOR: Color = Color(0.85, 0.08, 0.06)
const FLAG_SIZE: Vector3 = Vector3(0.35, 0.5, 0.04)
const FLAG_HEIGHT: float = 2.15

## Identificador del reloj en el mapa
@export var clock_id: int = 1

## Zona del museo (las rutas alternan zonas) y sala, para el HUD
var zone: String = ""
var room_name: String = ""

## Algún guardia llega tarde a este reloj (banderola bajada)
var is_expired: bool = false

var _flag: MeshInstance3D = null


func _ready() -> void:
	add_to_group(&"net_state")
	add_to_group(&"time_clock")
	collision_layer = 4  # Interactuable
	collision_mask = 1  # Guardias y entorno
	monitoring = true
	_build_flag()


func _physics_process(_delta: float) -> void:
	if not GameManager.is_simulating():
		return
	var late: bool = false
	for node: Node in get_tree().get_nodes_in_group(&"guard_round"):
		var round_node: GuardRound = node as GuardRound
		if round_node.late and round_node.next_clock() == clock_id:
			late = true
	if late != is_expired:
		is_expired = late
		_update_flag()


## Vuelve al estado de inicio de partida (las rutas las reparte RoundPlanner)
func reset_round() -> void:
	is_expired = false
	_update_flag()


## Contrato de interacción: solo los guardias pueden fichar en los relojes de ronda
func can_interact(actor: Node3D = null) -> bool:
	return actor is GuardController3D


## Texto del aviso: si es el siguiente de su ruta, fichar; si no, cuál le toca
func get_interaction_text(actor: Node3D = null) -> String:
	var round_node: GuardRound = GuardRound.of(actor)
	if round_node == null or round_node.next_clock() == clock_id:
		return "Fichar en el reloj %d [E]" % clock_id
	return "No es tu reloj: te toca el %d" % round_node.next_clock()


## Ficha si es el siguiente reloj de la ronda del guardia
func interact(actor: Node3D) -> void:
	var round_node: GuardRound = GuardRound.of(actor)
	if not actor is GuardController3D or round_node == null or not round_node.punch(clock_id):
		return
	var peer_id: int = 1
	if multiplayer != null and multiplayer.has_multiplayer_peer():
		peer_id = multiplayer.get_unique_id()
	clock_punched.emit(clock_id, peer_id)
	print("[TimeClock3D #%d] Fichado por %s" % [clock_id, actor.name])
	SignalBus.time_clock_punched.emit(clock_id, peer_id)
	NoiseEmit.emit(global_position, RULES.punch_noise_radius, &"guard", NoiseEmit.MECHANISM, actor)


## Estado público para red: si la banderola está bajada (lo ve todo el mundo)
func get_net_state() -> Dictionary:
	return {"expired": is_expired}


## Aplica el snapshot de estado recibido por red
func apply_net_state(state: Dictionary) -> void:
	if state.has("expired"):
		is_expired = bool(state["expired"])
		_update_flag()


func _build_flag() -> void:
	_flag = MeshInstance3D.new()
	_flag.name = "ExpiredFlag"
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = FLAG_SIZE
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = FLAG_COLOR
	material.emission_enabled = true
	material.emission = FLAG_COLOR
	material.emission_energy_multiplier = 0.6
	mesh.material = material
	_flag.mesh = mesh
	_flag.position = Vector3(0.0, FLAG_HEIGHT, -0.25)
	add_child(_flag)
	_update_flag()


func _update_flag() -> void:
	if _flag != null:
		_flag.visible = is_expired
