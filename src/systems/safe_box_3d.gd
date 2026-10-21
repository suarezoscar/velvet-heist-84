## @file safe_box_3d.gd
## Sistema de Caja Fuerte pesada de combinación mecánica analógica (Años 80).
## Requiere que el Ladrón gire el dial buscando los clics mecánicos audibles
## para desbloquear los 3 números de la combinación y acceder al botín interior.
class_name SafeBox3D
extends Area3D

## Emitida cuando el dial cambia de número. is_near indica si está a +-2 pasos de la combinación
signal dial_rotated(current_val: int, is_near: bool)

## Emitida cuando se abre la puerta de la caja fuerte con éxito
signal safe_opened()

## Estados de la caja fuerte
enum SafeState {
	LOCKED,    ## Cerrada con pestillo
	CRACKING,  ## El ladrón está actualmente manipulando el dial
	OPENED     ## Desbloqueada y abierta
}

## Combinación mecánica de 3 dígitos (entre 0 y 99)
@export var combination: Array[int] = [30, 65, 15]

## Escena del botín que se instanciará en su interior al abrirse
@export var loot_inside_scene: PackedScene = null

## Estado actual de la caja
var current_state: SafeState = SafeState.LOCKED

## Etapa de la combinación que se está intentando descifrar (0, 1 o 2)
var current_stage: int = 0

## Posición angular actual del dial (de 00 a 99)
var current_dial_val: int = 0

var active_thief: ThiefController3D = null

@onready var door_pivot: Node3D = $DoorPivot if has_node("DoorPivot") else null

func _ready() -> void:
	collision_layer = 4 # Interactuable
	collision_mask = 2  # Ladrón
	monitoring = true

## Contrato de interacción: solo puede interactuarse si no está abierta
func can_interact(_actor: Node3D) -> bool:
	return current_state != SafeState.OPENED

## Devuelve el texto del tooltip para el HUD según el estado del dial
func get_interaction_text(_actor: Node3D = null) -> String:
	match current_state:
		SafeState.OPENED:
			return "Caja Fuerte (Abierta)"
		SafeState.CRACKING:
			return "Dial: [%02d] (Girar: A/D o Flechas | Confirmar: E | Salir: Esc)" % current_dial_val
		_:
			return "Ganzuar Caja Fuerte [E]"

## Ejecuta la interacción iniciada por el jugador
func interact(actor: Node3D) -> void:
	if current_state == SafeState.OPENED or not (actor is ThiefController3D):
		return

	var thief: ThiefController3D = actor as ThiefController3D
	if current_state == SafeState.LOCKED:
		_start_cracking_session(thief)
	elif current_state == SafeState.CRACKING:
		_confirm_current_number()

func _start_cracking_session(thief: ThiefController3D) -> void:
	current_state = SafeState.CRACKING
	active_thief = thief
	current_stage = 0
	current_dial_val = 0
	print("[SafeBox3D] Sesión de ganzúa iniciada. Buscando número 1...")

func _unhandled_input(event: InputEvent) -> void:
	if current_state != SafeState.CRACKING:
		return

	if event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		_step_dial(1)
	elif event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		_step_dial(-1)
	elif event.is_action_pressed("ui_cancel"):
		_cancel_cracking_session()

## Hace avanzar o retroceder el dial un paso (0 a 99)
func _step_dial(delta_steps: int) -> void:
	current_dial_val = (current_dial_val + delta_steps + 100) % 100

	var target_num: int = combination[current_stage]
	var diff: int = abs(current_dial_val - target_num)
	var is_near: bool = (diff <= 2 or diff >= 98)

	dial_rotated.emit(current_dial_val, is_near)

	# Si pasa cerca del número exacto, emite una onda de clic suave
	if is_near:
		_emit_acoustic_noise(1.8)

## Confirma el número actual del dial contra la combinación requerida
func _confirm_current_number() -> void:
	var target_num: int = combination[current_stage]
	if current_dial_val == target_num:
		current_stage += 1
		print("[SafeBox3D] ¡Número correcto! Acertados: %d/%d" % [current_stage, combination.size()])
		_emit_acoustic_noise(4.0)

		if current_stage >= combination.size():
			_unlock_and_open()
	else:
		print("[SafeBox3D] Fallo de combinación. Reseteando pestillos.")
		_emit_acoustic_noise(7.5) # Ruido mecánico de fallo
		current_stage = 0

func _unlock_and_open() -> void:
	current_state = SafeState.OPENED
	active_thief = null
	safe_opened.emit()
	print("[SafeBox3D] ¡Caja fuerte abierta con éxito!")
	_emit_acoustic_noise(6.0)

	if door_pivot != null:
		var tween: Tween = create_tween()
		tween.tween_property(door_pivot, "rotation_degrees:y", -110.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_spawn_loot_contents()

func _spawn_loot_contents() -> void:
	if loot_inside_scene != null:
		var loot: Node3D = loot_inside_scene.instantiate() as Node3D
		loot.position = global_position + Vector3(0.0, 0.6, 0.4)
		get_parent().add_child(loot)

func _cancel_cracking_session() -> void:
	current_state = SafeState.LOCKED
	active_thief = null
	print("[SafeBox3D] Sesión de ganzúa cancelada por el usuario.")

func _emit_acoustic_noise(radius: float) -> void:
	var bus: Node = get_node_or_null("/root/SignalBus")
	if bus != null:
		bus.emit_signal("noise_emitted_3d", global_position, radius, &"thief")
