## @file target_piece_3d.gd
## Pieza candidata del encargo (heist.md R1 y R9): pedestal con su pieza y una protección.
## Todo pasa en la pieza (#119): E abre el minijuego de su protección; Q es lo único a lo bruto.
## - Combinación: la guarda un candado (SafeBox3D: vitrina o caja fuerte) con su dial. Abierto, E
##   la coge en silencio. Una vitrina se puede romper a lo bruto (Q); la caja fuerte, no.
## - Presión: E da el cambiazo con la balanza (StealMinigame SWAP). Queda una falsificación con
##   un fallo sorteado (TargetPieceLook.Flaw) que no es rastro hasta que un guardia la examina
##   (E, RULES.inspect_time).
## - Sensor: E lo puentea con el piloto (StealMinigame BRIDGE) y la pieza sale en silencio.
## A lo bruto suena la campana (ruido de RULES.brute_radius) y salta la alarma. Solo el ladrón
## puede robarla, y solo si está en su encargo. El aspecto vive en TargetPieceLook.
class_name TargetPiece3D
extends Area3D

const RULES: HeistRules = preload("res://data/balance/heist_rules.tres")
const SILENT_RADIUS: float = 2.5
const BRUTE_TEXT: String = "A lo bruto [Q]: salta la alarma"

var piece_id: StringName = &""
var piece_name: String = ""
var room_name: String = ""
## &"combination", &"pressure" o &"sensor"
var protection: StringName = &"combination"
## Candado de las piezas de combinación (null en las demás)
var lock: SafeBox3D = null
var variant: StringName = &"pedestal"
var stolen: bool = false
## Fallo de la pieza de pega que quedó en su lugar (NONE: no hubo cambiazo)
var flaw: TargetPieceLook.Flaw = TargetPieceLook.Flaw.NONE
## Un guardia (o una cámara vigilada) sabe que falta (heist.md R6)
var discovered: bool = false
## Un guardia la examinó y era auténtica
var inspected: bool = false
## Se la llevaron puenteando el sensor: el guardia lo ve al descubrirla (#119)
var bridged: bool = false
var shown_stolen: bool = false  # lo que ve el jugador local (#163)
var model: Node3D = null
var marker: Label3D = null
## Minijuego del ladrón en curso (en la autoridad) y lo que llega de él por la red (cliente)
var game: StealMinigame = null
var _view: Dictionary = {}
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
	if game != null:
		match game.tick(delta):
			StealMinigame.Result.DONE:
				_finish_game()
			StealMinigame.Result.CANCELLED:
				game = null


func _process(delta: float) -> void:
	_marker_timer -= delta
	if _marker_timer > 0.0:
		return
	_marker_timer = 0.25
	if variant == &"safe" and model != null and lock != null:
		model.visible = not shown_stolen and lock.shown_open()
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
	if game != null:
		return game.actor == actor
	if not is_available(actor) or _task != null:
		return false
	if _lock_closed():
		return lock.can_interact(actor)
	return true


func get_interaction_text(actor: Node3D = null) -> String:
	if actor is GuardController3D:
		return "Examinando…" if _task != null else "Examinar %s [E]" % piece_name
	if is_playing():
		return ""  # lo enseña el panel del minijuego
	if _lock_closed():
		return lock.get_interaction_text(actor)
	if lock != null:
		return "Coger %s [E]" % piece_name
	var verb: String = "Dar el cambiazo" if protection == &"pressure" else "Puentear el sensor"
	return "%s [E]\n%s" % [verb, BRUTE_TEXT]


## E: examinar (guardia), abrir el candado, coger lo abierto o el minijuego de la protección
func interact(actor: Node3D) -> void:
	if not can_interact(actor):
		return
	if game != null:
		game.press()
	elif actor is GuardController3D:
		_task = TimedTask.start(actor, RULES.inspect_time, RULES.task_leash, _finish_inspect)
	elif _lock_closed():
		lock.interact(actor)
	elif lock != null:
		steal(false)
	else:
		var kind: StealMinigame.Kind = (
			StealMinigame.Kind.SWAP if protection == &"pressure" else StealMinigame.Kind.BRIDGE
		)
		game = StealMinigame.start(kind, actor)


## true mientras el ladrón juega su minijuego (también en el cliente, por la red)
func is_playing() -> bool:
	return TargetPieceGame.is_playing(self)


## Lo que enseña el panel del minijuego ({} sin minijuego)
func minigame_view() -> Dictionary:
	return TargetPieceGame.view(self)


## E (un intento o volver a sujetar), soltar E (la balanza se pausa) o Esc (sale)
func minigame_action(actor: Node3D, action: StringName) -> void:
	TargetPieceGame.action(self, actor, action)


## Teclas de movimiento del ladrón durante el minijuego
func steer(actor: Node3D, move: Vector2) -> void:
	TargetPieceGame.steer(self, actor, move)


## Q: a lo bruto. Vale si no hay candado o es una vitrina (la caja fuerte no se rompe)
func can_force(actor: Node3D) -> bool:
	if not is_available(actor):
		return false
	return lock == null or lock.breakable or lock.current_state == SafeBox3D.SafeState.OPENED


func force(actor: Node3D) -> bool:
	if not can_force(actor):
		return false
	game = null  # Q en mitad del minijuego lo abandona
	steal(lock == null or lock.current_state != SafeBox3D.SafeState.OPENED)
	return true


## Cómo se ha robado (informe, FEAT-041): a lo bruto, cambiazo, sensor puenteado o dial
static func steal_method(brute: bool, fake: TargetPieceLook.Flaw, kind: StringName) -> StringName:
	if brute:
		return &"brute"
	if fake != TargetPieceLook.Flaw.NONE:
		return &"swap"
	return &"bridge" if kind == &"sensor" else &"dial"


## Autoridad: la pieza sale del pedestal y cuenta para el encargo
func steal(brute: bool, fake: TargetPieceLook.Flaw = TargetPieceLook.Flaw.NONE) -> void:
	if stolen:
		return
	stolen = true
	flaw = fake
	bridged = not brute and protection == &"sensor"
	inspected = false
	game = null
	if lock != null and lock.current_state != SafeBox3D.SafeState.OPENED:
		lock.break_open()
	refresh_look()
	if GameManager.heist != null:
		GameManager.heist.mark_stolen(piece_id, steal_method(brute, fake, protection))
	var thief: Node3D = get_tree().get_first_node_in_group(&"thief") as Node3D
	var kind: StringName = NoiseEmit.MECHANISM if brute else NoiseEmit.IMPACT
	var radius: float = RULES.brute_radius if brute else SILENT_RADIUS
	NoiseEmit.emit(global_position, radius, &"thief", kind, thief)
	var alert: AlertDirector = AlertDirector.of(get_tree())
	if brute and alert != null:
		alert.raise(AlertDirector.Level.ALARM, global_position)  # R9: a lo bruto salta la alarma
		discovered = true


func get_net_state_private() -> Dictionary:  # solo para el ladrón: su minijuego
	return game.to_view() if game != null else {"game": 0}


func net_private_audience() -> StringName:
	return &"thief"


## Público: si el pedestal está vacío, el fallo de la copia (se ve) y si un guardia la
## examinó y era auténtica. Lo que ya saben los guardias va solo a ellos (AlertDirector)
func get_net_state() -> Dictionary:
	return {"stolen": stolen, "flaw": int(flaw), "inspected": inspected, "bridged": bridged}


func apply_net_state(state: Dictionary) -> void:
	if state.has("game"):
		_view = state.duplicate()
		return
	inspected = bool(state.get("inspected", inspected))
	var new_flaw: TargetPieceLook.Flaw = int(state.get("flaw", 0)) as TargetPieceLook.Flaw
	bridged = bool(state.get("bridged", bridged))
	if bool(state.get("stolen", false)) and not stolen:
		stolen = true
		flaw = new_flaw
		refresh_look()


func in_contract() -> bool:
	return GameManager.heist != null and GameManager.heist.is_in_contract(piece_id)


## Minijuego completado: el cambiazo deja la falsificación; el puente se lleva la pieza
func _finish_game() -> void:
	var swapped: bool = game.kind == StealMinigame.Kind.SWAP
	game = null
	if not swapped:
		steal(false)
		return
	var flaws: Array = [
		TargetPieceLook.Flaw.TINT, TargetPieceLook.Flaw.SIZE, TargetPieceLook.Flaw.POSE
	]
	steal(false, flaws.pick_random() as TargetPieceLook.Flaw)


func _finish_inspect(actor: Node3D) -> void:
	if stolen and not is_faked():
		return  # se la llevaron a lo bruto mientras la examinaba: ya está descubierta
	inspected = not is_faked()
	if is_faked():
		discovered = true
		MatchRecorder.note_examined(get_tree(), actor, self)  # #123: sus puntos


func refresh_look() -> void:  # robada como la ve el jugador local (#163, D4)
	if not shown_stolen and model != null and bool(FogMemory.shown(self, stolen)):
		shown_stolen = true
		model.visible = is_faked()
		TargetPieceLook.apply_flaw(model, flaw)
		TargetPieceLook.update_marker(self)  # si no, la pone al día _process


func _looks_whole() -> bool:  # estado real, no el recordado (#163): es simulación
	var hidden: bool = variant == &"safe" and _lock_closed()
	return (not stolen or is_faked()) and model != null and not hidden


func _lock_closed() -> bool:
	return lock != null and lock.current_state != SafeBox3D.SafeState.OPENED
