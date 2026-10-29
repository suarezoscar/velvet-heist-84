## @file safe_box_3d.gd
## Sistema de Caja Fuerte pesada de combinación mecánica analógica (Años 80).
## Requiere que el Ladrón gire el dial buscando los clics mecánicos audibles
## para desbloquear los 3 números de la combinación y acceder al botín interior.
class_name SafeBox3D
extends Area3D

## Emitida cuando el dial cambia de número. is_near indica si está a NEAR_STEPS de la combinación
signal dial_rotated(current_val: int, is_near: bool)

## Emitida cuando se abre la puerta de la caja fuerte con éxito
signal safe_opened

## Estados de la caja fuerte
enum SafeState {
	## Cerrada con pestillo
	LOCKED,
	## El ladrón está actualmente manipulando el dial
	CRACKING,
	## Desbloqueada y abierta
	OPENED,
}

## Pasos a cada lado del número en los que el dial «suena cerca»
const NEAR_STEPS: int = 2

## Combinación mecánica de 3 dígitos (entre 0 y 99)
@export var combination: Array[int] = [30, 65, 15]

## Escena del botín que se instanciará en su interior al abrirse
@export var loot_inside_scene: PackedScene = null

## Candado de una pieza del encargo (heist.md R9): nombre para el texto y si se puede romper
@export var lock_name: String = "caja fuerte"
@export var breakable: bool = false

## Pieza del encargo que protege (null: caja fuerte clásica con botín dentro)
var contained_target: TargetPiece3D = null

## Estado actual de la caja
var current_state: SafeState = SafeState.LOCKED

## Etapa de la combinación que se está intentando descifrar (0, 1 o 2)
var current_stage: int = 0

## Posición angular actual del dial (de 00 a 99)
var current_dial_val: int = 0
## Números fallados al probar (el panel lo usa para sonar al fallar, también en red)
var fails: int = 0
var active_thief: ThiefController3D = null
var door_pivot: Node3D = null
var _loot_spawned: bool = false
var _dial_repeat: DialRepeat = DialRepeat.new()


func _ready() -> void:
	add_to_group(&"net_state")
	collision_layer = 4
	collision_mask = 2
	monitoring = true
	door_pivot = get_node_or_null("DoorPivot") as Node3D


## Contrato de interacción: solo puede interactuarse si no está abierta
func can_interact(_actor: Node3D = null) -> bool:
	if contained_target != null and not contained_target.is_available(_actor):
		return false  # una pieza que no está en el encargo: el dial ni se activa
	return current_state != SafeState.OPENED


## Devuelve el texto del tooltip para el HUD; girando el dial no hay (lo enseña SafeDial84)
func get_interaction_text(_actor: Node3D = null) -> String:
	match current_state:
		SafeState.OPENED:
			return "Caja fuerte abierta"
		SafeState.CRACKING:
			return ""
		_:
			if breakable:
				return "Abrir la %s con la combinación [E] · Romper el cristal [Q]" % lock_name
			return "Abrir la %s [E]" % lock_name


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


## Sin red, el ladrón local gira el dial manteniendo flechas o A/D y sale con Esc. En red lo
## manda el cliente como acciones (NetSessionClient)
func _process(delta: float) -> void:
	if current_state != SafeState.CRACKING or NetManager.is_online():
		return
	if active_thief == null or not active_thief.is_locally_controlled:
		return
	var step: int = _dial_repeat.update(DialRepeat.left_held(), DialRepeat.right_held(), delta)
	if step != 0:
		step_dial(step)
	if InputMap.has_action(&"ui_cancel") and Input.is_action_just_pressed(&"ui_cancel"):
		cancel_cracking()


## Hace avanzar o retroceder el dial un paso (+1 o -1), solo en CRACKING
func step_dial(direction: int) -> void:
	if current_state != SafeState.CRACKING or direction == 0:
		return

	var delta_step: int = 1 if direction > 0 else -1
	current_dial_val = (current_dial_val + delta_step + 100) % 100

	var is_near: bool = target_distance() <= NEAR_STEPS
	dial_rotated.emit(current_dial_val, is_near)
	if is_near:
		_emit_acoustic_noise(1.8, &"dial")


## Pasos (por el camino corto) del dial al número que toca; 100 si no queda ninguno
func target_distance() -> int:
	if current_stage < 0 or current_stage >= combination.size():
		return 100
	var diff: int = absi(current_dial_val - combination[current_stage]) % 100
	return mini(diff, 100 - diff)


## Cancela la sesión de ganzúa y devuelve la caja fuerte al estado bloqueado
func cancel_cracking() -> void:
	current_state = SafeState.LOCKED
	active_thief = null
	print("[SafeBox3D] Sesión de ganzúa cancelada.")


## Confirma el número actual del dial contra la combinación requerida
func _confirm_current_number() -> void:
	var target_num: int = combination[current_stage]
	if current_dial_val == target_num:
		current_stage += 1
		print("[SafeBox3D] ¡Correcto! Acertados: %d/%d" % [current_stage, combination.size()])
		_emit_acoustic_noise(4.0, &"dial")

		if current_stage >= combination.size():
			_unlock_and_open()
	else:
		print("[SafeBox3D] Fallo de combinación. Reseteando pestillos.")
		_emit_acoustic_noise(7.5, &"dial")
		current_stage = 0
		fails += 1


func _unlock_and_open() -> void:
	current_state = SafeState.OPENED
	safe_opened.emit()
	print("[SafeBox3D] ¡Caja fuerte abierta con éxito!")
	_emit_acoustic_noise(6.0)
	active_thief = null

	if door_pivot != null:
		var tween: Tween = create_tween()
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(door_pivot, "rotation_degrees:y", -110.0, 1.2)

	_spawn_loot_contents()


func _spawn_loot_contents() -> void:
	if loot_inside_scene == null or _loot_spawned:
		return
	_loot_spawned = true
	var loot: Node3D = loot_inside_scene.instantiate() as Node3D
	# Nombre fijo para que el servidor y los clientes compartan la misma ruta (FEAT-014)
	loot.name = "SafeLoot_%d" % 0
	loot.position = global_position + Vector3(0.0, 0.6, 0.4)
	get_parent().add_child(loot)


## El dial (&"dial") lo oyen los demás como un mecanismo; el ladrón lo oye en su panel
func _emit_acoustic_noise(radius: float, category: StringName = NoiseEmit.MECHANISM) -> void:
	var emitter_node: Node = self
	if active_thief != null:
		emitter_node = active_thief
	NoiseEmit.emit(global_position, radius, &"thief", category, emitter_node)


## La rompen a lo bruto (vitrina): queda abierta sin combinación
func break_open() -> void:
	current_state = SafeState.OPENED
	active_thief = null


## Devuelve el estado público de red (abierta o no)
func get_net_state() -> Dictionary:
	return {
		"opened": current_state == SafeState.OPENED,
	}


## Devuelve el estado privado de ganzúa (solo para el ladrón)
func get_net_state_private() -> Dictionary:
	return {
		"cracking": current_state == SafeState.CRACKING,
		"dial": current_dial_val,
		"stage": current_stage,
		"fails": fails,
	}


## Audiencia del estado privado (NetPrivateStates)
func net_private_audience() -> StringName:
	return &"thief"


## Aplica el estado de red público o privado recibido
func apply_net_state(state: Dictionary) -> void:
	var was_opened: bool = current_state == SafeState.OPENED
	if state.has("opened"):
		if bool(state["opened"]):
			current_state = SafeState.OPENED
			if door_pivot != null:
				door_pivot.rotation_degrees.y = -110.0
		elif current_state == SafeState.OPENED:
			current_state = SafeState.LOCKED
			if door_pivot != null:
				door_pivot.rotation_degrees.y = 0.0
	if not was_opened and current_state == SafeState.OPENED:
		_spawn_loot_contents()

	if state.has("cracking"):
		if bool(state["cracking"]):
			current_state = SafeState.CRACKING
		elif current_state == SafeState.CRACKING:
			current_state = SafeState.LOCKED

	if state.has("stage"):
		current_stage = int(state["stage"])
	if state.has("fails"):
		fails = int(state["fails"])

	if state.has("dial"):
		var new_dial: int = int(state["dial"])
		var dial_changed: bool = new_dial != current_dial_val
		current_dial_val = new_dial
		if dial_changed:
			dial_rotated.emit(current_dial_val, target_distance() <= NEAR_STEPS)
