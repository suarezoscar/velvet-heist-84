## @file game_manager.gd
## Autoload responsable de administrar el estado de la partida, el reloj de ronda,
## la cuota económica del botín y la evaluación de victoria/derrota.
extends Node

## Posibles estados del ciclo de vida de una partida en 'Velvet Heist 84'
enum MatchState {
	LOBBY,           ## Sala de preparación y selección de equipo analógico
	IN_PROGRESS,     ## Infiltración en curso dentro de la mansión
	THIEF_ESCAPED,   ## Victoria del Ladrón: Huida en coche con la cuota y la obra de arte
	THIEF_CAPTURED,  ## Victoria de los Guardias: El ladrón ha sido neutralizado con porra
	TIME_EXPIRED     ## Victoria de los Guardias: La policía rodeó el recinto al vencer el reloj
}

## Cuota económica objetivo requerida para que el ladrón pueda escapar (en $)
@export var quota_target: int = 10000

## Duración máxima de la ronda en segundos (10 minutos por defecto)
@export var match_duration_seconds: float = 600.0

## Valor acumulado del botín asegurado en la partida actual
var current_loot_value: int = 0

## Bandera que confirma si la Pieza Maestra ha sido robada
var has_masterpiece: bool = false

## Temporizador regresivo en segundos
var match_timer: float = 0.0

## Estado activo de la partida
var current_state: MatchState = MatchState.LOBBY

func _ready() -> void:
	_connect_signal_bus()

func _connect_signal_bus() -> void:
	var bus: Node = get_node_or_null("/root/SignalBus")
	if bus != null:
		bus.connect("loot_stolen", _on_loot_stolen)
		bus.connect("thief_captured", _on_thief_captured)

func _physics_process(delta: float) -> void:
	if current_state == MatchState.IN_PROGRESS:
		match_timer -= delta
		if match_timer <= 0.0:
			match_timer = 0.0
			end_match(MatchState.TIME_EXPIRED)

## Inicializa una nueva ronda reiniciando contadores y objetivos
func start_match() -> void:
	current_loot_value = 0
	has_masterpiece = false
	match_timer = match_duration_seconds
	current_state = MatchState.IN_PROGRESS
	print("[GameManager] Partida iniciada. Objetivo: $%d + Pieza Maestra. Tiempo: %.0fs" % [quota_target, match_duration_seconds])

## Finaliza la partida con el estado correspondiente
func end_match(final_state: MatchState) -> void:
	current_state = final_state
	print("[GameManager] Fin de la partida. Estado final: %s" % MatchState.keys()[final_state])

func _on_loot_stolen(value: int, is_masterpiece_item: bool) -> void:
	current_loot_value += value
	if is_masterpiece_item:
		has_masterpiece = true
	print("[GameManager] Botín sumado: +$%d (Total: $%d). ¿Pieza Maestra?: %s" % [value, current_loot_value, str(has_masterpiece)])

func _on_thief_captured(guard_peer_id: int) -> void:
	print("[GameManager] Ladrón capturado por el guardia (peer: %d)" % guard_peer_id)
	end_match(MatchState.THIEF_CAPTURED)

## Comprueba si el ladrón cumple todos los requisitos para poder escapar en el coche
func can_thief_escape() -> bool:
	return current_loot_value >= quota_target and has_masterpiece
