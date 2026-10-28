## @file target_piece_3d.gd
## Pieza candidata del encargo (heist.md R1 y R9): pedestal con su pieza y una protección.
## - Combinación: la guarda un candado (SafeBox3D: vitrina o caja fuerte). Abierto, E la coge en
##   silencio. Una vitrina se puede romper a lo bruto (Q); la caja fuerte, no.
## - Presión: con una pieza de pega del taller, E da el cambiazo en silencio (RULES.swap_time).
##   La copia se queda con un fallo sorteado (TargetPieceLook.Flaw) y no es un rastro hasta
##   que un guardia la examina (E, RULES.inspect_time). Sin copia, E es a lo bruto.
## - Sensor: con la corriente de su ala cortada (PowerBox3D), E la coge en silencio; si no,
##   a lo bruto.
## A lo bruto suena la campana (ruido de RULES.brute_radius) y salta la alarma. Solo el ladrón
## puede robarla, y solo si está en su encargo. El aspecto vive en TargetPieceLook.
class_name TargetPiece3D
extends Area3D

const RULES: HeistRules = preload("res://data/balance/heist_rules.tres")
const SILENT_RADIUS: float = 2.5

var piece_id: StringName = &""
var piece_name: String = ""
var room_name: String = ""
## &"combination", &"pressure" o &"sensor"
var protection: StringName = &"combination"
## Candado de las piezas de combinación (null en las demás)
var lock: SafeBox3D = null
## Cuadro eléctrico del ala de las piezas de sensor (null en las demás)
var power_box: PowerBox3D = null
var variant: StringName = &"pedestal"
var stolen: bool = false
## Fallo de la pieza de pega que quedó en su lugar (NONE: no hubo cambiazo)
var flaw: TargetPieceLook.Flaw = TargetPieceLook.Flaw.NONE
## Un guardia (o una cámara vigilada) sabe que falta (heist.md R6)
var discovered: bool = false
## Un guardia la examinó y era auténtica
var inspected: bool = false
var model: Node3D = null
var marker: Label3D = null
var _task: TimedTask = null
var _marker_timer: float = 0.0


## variant: &"pedestal" (sobre su pedestal), &"case" (sobre la vitrina, que es su candado) o
## &"safe" (dentro de la caja fuerte: no se ve hasta abrirla)
static func create(
	id: StringName,
	display_name: String,
	kind: StringName,
	model_scene: PackedScene,
	variant: StringName = &"pedestal"
) -> TargetPiece3D:
	var piece: TargetPiece3D = TargetPiece3D.new()
	piece.piece_id = id
	piece.piece_name = display_name
	piece.protection = kind
	piece.variant = variant
	piece.name = "Target_%s" % id
	TargetPieceLook.build(piece, model_scene)
	return piece


func _ready() -> void:
	add_to_group(&"net_state")
	add_to_group(&"heist_targets")
	collision_layer = 4  # Interactuable
	collision_mask = 2
	monitoring = true


func _physics_process(delta: float) -> void:
	if _task != null and _task.tick(delta):
		_task = null


func _process(delta: float) -> void:
	_marker_timer -= delta
	if _marker_timer > 0.0:
		return
	_marker_timer = 0.25
	if variant == &"safe" and model != null and lock != null:
		model.visible = not stolen and lock.current_state == SafeBox3D.SafeState.OPENED
	TargetPieceLook.update_marker(self)


## true si se ha llevado el original y dejado una copia
func is_faked() -> bool:
	return flaw != TargetPieceLook.Flaw.NONE


## El ladrón puede ir a por ella: sigue en su sitio y está en su encargo
func is_available(actor: Node3D) -> bool:
	return not stolen and actor is ThiefController3D and in_contract()


## Un guardia puede examinarla: está a la vista (no vacía) y aún no sabe nada de ella
func can_inspect(actor: Node3D) -> bool:
	return actor is GuardController3D and not discovered and not inspected and _looks_whole()


## Con el candado cerrado, la E pasa a él (su área queda tapada por la de la pieza)
func can_interact(actor: Node3D = null) -> bool:
	if can_inspect(actor):
		return _task == null
	if not is_available(actor) or _task != null:
		return false
	if _lock_closed():
		return lock.can_interact(actor)
	return true


func get_interaction_text(actor: Node3D = null) -> String:
	if actor is GuardController3D:
		return "Examinando…" if _task != null else "Examinar %s [E]" % piece_name
	if _task != null:
		return "Dando el cambiazo…"
	if _lock_closed():
		return lock.get_interaction_text(actor)
	if lock != null or _silent_steal_ready():
		return "Coger %s [E]" % piece_name
	if protection == &"pressure" and _has_fake():
		return "Dar el cambiazo con la pieza de pega [E]"
	return "Robar %s a lo bruto: salta la alarma [E]" % piece_name


## E: examinar (guardia), abrir el candado, dar el cambiazo, coger en silencio o a lo bruto
func interact(actor: Node3D) -> void:
	if not can_interact(actor):
		return
	if actor is GuardController3D:
		_task = TimedTask.start(actor, RULES.inspect_time, RULES.task_leash, _finish_inspect)
	elif _lock_closed():
		lock.interact(actor)
	elif protection == &"pressure" and _has_fake():
		_task = TimedTask.start(actor, RULES.swap_time, RULES.task_leash, _finish_swap)
	else:
		steal(lock == null and not _silent_steal_ready())


## Q: a lo bruto. Vale si no hay candado o es una vitrina (la caja fuerte no se rompe)
func can_force(actor: Node3D) -> bool:
	if not is_available(actor):
		return false
	return lock == null or lock.breakable or lock.current_state == SafeBox3D.SafeState.OPENED


func force(actor: Node3D) -> bool:
	if not can_force(actor):
		return false
	steal(lock == null or lock.current_state != SafeBox3D.SafeState.OPENED)
	return true


## Autoridad: la pieza sale del pedestal y cuenta para el encargo
func steal(brute: bool, fake: TargetPieceLook.Flaw = TargetPieceLook.Flaw.NONE) -> void:
	if stolen:
		return
	stolen = true
	flaw = fake
	inspected = false
	if lock != null and lock.current_state != SafeBox3D.SafeState.OPENED:
		lock.break_open()
	_apply_stolen()
	if GameManager.heist != null:
		GameManager.heist.mark_stolen(piece_id)
	var thief: Node3D = get_tree().get_first_node_in_group(&"thief") as Node3D
	var kind: StringName = NoiseEmit.MECHANISM if brute else NoiseEmit.IMPACT
	var radius: float = RULES.brute_radius if brute else SILENT_RADIUS
	NoiseEmit.emit(global_position, radius, &"thief", kind, thief)
	var alert: AlertDirector = AlertDirector.of(get_tree())
	if brute and alert != null:
		alert.raise(AlertDirector.Level.ALARM)  # R9: a lo bruto salta la alarma
		discovered = true
	print("[TargetPiece3D] %s robada%s" % [piece_name, " a lo bruto" if brute else ""])


## Público: si el pedestal está vacío, el fallo de la copia (se ve) y si un guardia la
## examinó y era auténtica. Lo que ya saben los guardias va solo a ellos (AlertDirector)
func get_net_state() -> Dictionary:
	return {"stolen": stolen, "flaw": int(flaw), "inspected": inspected}


func apply_net_state(state: Dictionary) -> void:
	inspected = bool(state.get("inspected", inspected))
	var new_flaw: TargetPieceLook.Flaw = int(state.get("flaw", 0)) as TargetPieceLook.Flaw
	if bool(state.get("stolen", false)) and not stolen:
		stolen = true
		flaw = new_flaw
		_apply_stolen()


func in_contract() -> bool:
	return GameManager.heist != null and GameManager.heist.is_in_contract(piece_id)


func _finish_swap(actor: Node3D) -> void:
	if stolen or GameManager.heist == null or not GameManager.heist.carrying_fake:
		return
	GameManager.heist.carrying_fake = false
	var flaws: Array = [
		TargetPieceLook.Flaw.TINT, TargetPieceLook.Flaw.SIZE, TargetPieceLook.Flaw.POSE
	]
	steal(false, flaws.pick_random() as TargetPieceLook.Flaw)
	print("[TargetPiece3D] Cambiazo en %s por %s" % [piece_name, actor.name])


func _finish_inspect(_actor: Node3D) -> void:
	if is_faked():
		discovered = true
		print("[TargetPiece3D] ¡%s es una falsificación!" % piece_name)
	else:
		inspected = true


func _apply_stolen() -> void:
	if model != null:
		model.visible = is_faked()
		TargetPieceLook.apply_flaw(model, flaw)
	TargetPieceLook.update_marker(self)


func _looks_whole() -> bool:
	return (not stolen or is_faked()) and model != null and model.visible


func _lock_closed() -> bool:
	return lock != null and lock.current_state != SafeBox3D.SafeState.OPENED


func _silent_steal_ready() -> bool:
	return protection == &"sensor" and power_box != null and power_box.is_cut


func _has_fake() -> bool:
	return GameManager.heist != null and GameManager.heist.carrying_fake
